import CoreFoundation
import Foundation
import IOKit.hid

struct ConnectedHIDDevice: Equatable, Sendable {
  enum Access: Equatable, Sendable {
    case writableUSB
    case bluetoothReadOnly
  }

  let profile: DeviceProfile
  let productName: String
  let reportID: UInt8
  let access: Access
  let transport: String
  let batteryLevel: Int?

  var isConfigurable: Bool {
    switch access {
    case .writableUSB:
      true
    case .bluetoothReadOnly:
      false
    }
  }

  var isBluetoothReadOnly: Bool {
    access == .bluetoothReadOnly
  }

  static func normalizedBatteryLevel(_ value: Int?) -> Int? {
    guard let value, (0...100).contains(value) else { return nil }
    return value
  }
}

enum HIDServiceError: LocalizedError {
  case notConnected
  case deviceOpenFailed(IOReturn)
  case reportWriteFailed(IOReturn)
  case reportReadFailed(IOReturn)
  case readTimedOut(expected: Int, actual: Int)
  case writeTimedOut
  case unsupportedRead

  var errorDescription: String? {
    switch self {
    case .notConnected: "No supported macro pad is connected."
    case .deviceOpenFailed(let result): "The macro pad could not be opened (IOKit \(result))."
    case .reportWriteFailed(let result):
      "A configuration report could not be written to the macro pad (IOKit \(result))."
    case .reportReadFailed(let result):
      "A configuration report could not be read from the macro pad (IOKit \(result))."
    case .readTimedOut(let expected, let actual):
      "The macro pad returned \(actual) of \(expected) configuration records before timing out."
    case .writeTimedOut: "The macro pad did not accept the configuration report before timing out."
    case .unsupportedRead: "Configuration reading is not enabled for this device profile."
    }
  }
}

@MainActor
final class HIDDeviceService {
  var onConnectionChanged: ((ConnectedHIDDevice?) -> Void)?

  private var manager: IOHIDManager?
  private var device: IOHIDDevice?
  private var bluetoothDevice: IOHIDDevice?
  private(set) var connectedDevice: ConnectedHIDDevice?
  private let discoveryEnabled: Bool

  init(discoveryEnabled: Bool = true) {
    self.discoveryEnabled = discoveryEnabled
  }

  func start() {
    guard discoveryEnabled, manager == nil else { return }
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    self.manager = manager

    var matches: [[String: Any]] = DeviceProfile.supported.map {
      [
        kIOHIDVendorIDKey as String: Int($0.vendorID),
        kIOHIDProductIDKey as String: Int($0.productID),
      ]
    }
    matches.append([kIOHIDProductKey as String: "MINI_KEYBOARD"])
    IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)

    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerRegisterDeviceMatchingCallback(
      manager,
      { context, _, _, device in
        guard let context else { return }
        let service = Unmanaged<HIDDeviceService>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in service.didMatch(device) }
      }, context)
    IOHIDManagerRegisterDeviceRemovalCallback(
      manager,
      { context, _, _, device in
        guard let context else { return }
        let service = Unmanaged<HIDDeviceService>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in service.didRemove(device) }
      }, context)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
  }

  func stop() {
    guard let manager else { return }
    if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
    IOHIDManagerUnscheduleFromRunLoop(
      manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    self.manager = nil
    device = nil
    bluetoothDevice = nil
    connectedDevice = nil
  }

  func write(_ report: HIDReport) throws {
    guard let device else { throw HIDServiceError.notConnected }
    let service = IOHIDDeviceGetService(device)
    guard service != 0 else { throw HIDServiceError.notConnected }
    try ConfigurationHIDWriter.write(service: service, report: report)
  }

  func readConfigurationReports() async throws -> [HIDInputReport] {
    guard let device, let connectedDevice else { throw HIDServiceError.notConnected }
    guard connectedDevice.profile == .miniKeyboardExtended, connectedDevice.reportID == 3 else {
      throw HIDServiceError.unsupportedRead
    }
    let requests = try MacroPadProtocolDecoder.configurationReadRequests(
      profile: connectedDevice.profile,
      reportID: connectedDevice.reportID
    )
    let service = IOHIDDeviceGetService(device)
    guard service != 0 else { throw HIDServiceError.notConnected }

    IOObjectRetain(service)
    return try await Task.detached {
      defer { IOObjectRelease(service) }
      return try ConfigurationHIDReader.read(service: service, requests: requests)
    }.value
  }

  private func didMatch(_ candidate: IOHIDDevice) {
    let name = stringProperty(kIOHIDProductKey, on: candidate) ?? ""
    let transport = stringProperty(kIOHIDTransportKey, on: candidate) ?? "Unknown"

    if name == "MINI_KEYBOARD", transport.localizedCaseInsensitiveContains("Bluetooth") {
      guard device == nil, bluetoothDevice == nil else { return }
      bluetoothDevice = candidate
      device = candidate
      let connection = ConnectedHIDDevice(
        profile: .miniKeyboardExtended,
        productName: name,
        reportID: 3,
        access: .bluetoothReadOnly,
        transport: transport,
        batteryLevel: batteryLevel(on: candidate)
      )
      connectedDevice = connection
      onConnectionChanged?(connection)
      return
    }

    guard let vendor = integerProperty(kIOHIDVendorIDKey, on: candidate),
      let product = integerProperty(kIOHIDProductIDKey, on: candidate),
      let profile = DeviceProfile.supported.first(where: {
        $0.vendorID == UInt16(vendor) && $0.productID == UInt16(product)
      })
    else { return }

    let maxOutput = integerProperty(kIOHIDMaxOutputReportSizeKey, on: candidate) ?? 0
    let usagePage = integerProperty(kIOHIDPrimaryUsagePageKey, on: candidate) ?? 0
    guard maxOutput == 65, usagePage == 0xFF00 else { return }

    let result = IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
    guard result == kIOReturnSuccess else { return }

    device = candidate
    let connection = ConnectedHIDDevice(
      profile: profile,
      productName: name.isEmpty ? profile.name : name,
      reportID: outputReportID(on: candidate),
      access: .writableUSB,
      transport: transport,
      batteryLevel: batteryLevel(on: candidate)
    )
    connectedDevice = connection
    onConnectionChanged?(connection)
  }

  private func didRemove(_ removed: IOHIDDevice) {
    if let bluetoothDevice, bluetoothDevice === removed {
      self.bluetoothDevice = nil
      if let device, device === removed {
        self.device = nil
        connectedDevice = nil
        onConnectionChanged?(nil)
      }
    } else if let device, device === removed {
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
      self.device = nil
      if let bluetoothDevice {
        self.device = bluetoothDevice
        let connection = ConnectedHIDDevice(
          profile: .miniKeyboardExtended,
          productName: "MINI_KEYBOARD",
          reportID: 3,
          access: .bluetoothReadOnly,
          transport: "Bluetooth Low Energy",
          batteryLevel: batteryLevel(on: bluetoothDevice)
        )
        connectedDevice = connection
        onConnectionChanged?(connection)
      } else {
        connectedDevice = nil
        onConnectionChanged?(nil)
      }
    }
  }

  private func integerProperty(_ key: String, on device: IOHIDDevice) -> Int? {
    (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
  }

  private func stringProperty(_ key: String, on device: IOHIDDevice) -> String? {
    IOHIDDeviceGetProperty(device, key as CFString) as? String
  }

  private func batteryLevel(on device: IOHIDDevice) -> Int? {
    let matching = [
      kIOHIDElementUsagePageKey as String: Int(kHIDPage_GenericDesktop),
      kIOHIDElementUsageKey as String: Int(kHIDUsage_GenDevControls_BatteryStrength),
    ] as CFDictionary
    guard
      let element = (IOHIDDeviceCopyMatchingElements(
        device, matching, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement])?.first
    else { return nil }

    var value: Unmanaged<IOHIDValue>!
    guard IOHIDDeviceGetValue(device, element, &value) == kIOReturnSuccess else { return nil }
    let logicalMinimum = IOHIDElementGetLogicalMin(element)
    let logicalMaximum = IOHIDElementGetLogicalMax(element)
    guard logicalMaximum > logicalMinimum else { return nil }

    let rawValue = IOHIDValueGetIntegerValue(value.takeRetainedValue())
    let percentage = (rawValue - logicalMinimum) * 100 / (logicalMaximum - logicalMinimum)
    return ConnectedHIDDevice.normalizedBatteryLevel(percentage)
  }

  private func outputReportID(on device: IOHIDDevice) -> UInt8 {
    outputElements(on: device)
      .map { UInt8(clamping: IOHIDElementGetReportID($0)) }
      .first ?? 0
  }

  private func outputElements(on device: IOHIDDevice) -> [IOHIDElement] {
    let elements =
      IOHIDDeviceCopyMatchingElements(
        device,
        [kIOHIDElementTypeKey as String: kIOHIDElementTypeOutput.rawValue] as CFDictionary,
        IOOptionBits(kIOHIDOptionsTypeNone)
      ) as? [IOHIDElement] ?? []
    return elements
  }
}

private enum ConfigurationHIDWriter {
  static func write(service: io_service_t, report: HIDReport) throws {
    let completion = DispatchSemaphore(value: 0)
    let result = HIDWriteResult()
    IOObjectRetain(service)
    Thread.detachNewThread {
      defer {
        IOObjectRelease(service)
        completion.signal()
      }
      do {
        try writeOnCurrentThread(service: service, report: report)
      } catch {
        result.error = error
      }
    }
    guard completion.wait(timeout: .now() + 3) == .success else {
      throw HIDServiceError.writeTimedOut
    }
    if let error = result.error { throw error }
  }

  private static func writeOnCurrentThread(service: io_service_t, report: HIDReport) throws {
    guard let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
      throw HIDServiceError.notConnected
    }
    let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    guard openResult == kIOReturnSuccess else {
      throw HIDServiceError.deviceOpenFailed(openResult)
    }
    guard let runLoop = CFRunLoopGetCurrent() else {
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
      throw HIDServiceError.notConnected
    }

    let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65)
    inputBuffer.initialize(repeating: 0, count: 65)
    let runLoopMode = CFRunLoopMode(
      rawValue: "MacroPadStudio.ConfigurationWrite.\(UUID().uuidString)" as CFString
    )
    IOHIDDeviceRegisterInputReportCallback(
      device,
      inputBuffer,
      65,
      { _, _, _, _, _, _, _ in },
      nil
    )
    IOHIDDeviceScheduleWithRunLoop(device, runLoop, runLoopMode.rawValue)
    defer {
      IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, 65, nil, nil)
      IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, runLoopMode.rawValue)
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
      inputBuffer.deallocate()
    }

    CFRunLoopRunInMode(runLoopMode, 0.001, false)
    // This firmware expects HIDAPI-style framing even through IOKit: the
    // report ID is both the API argument and the first byte of the buffer.
    var bytes = [report.reportID] + report.payload
    let byteCount = bytes.count
    let result = bytes.withUnsafeMutableBytes { buffer in
      IOHIDDeviceSetReport(
        device,
        kIOHIDReportTypeOutput,
        CFIndex(report.reportID),
        buffer.bindMemory(to: UInt8.self).baseAddress!,
        byteCount
      )
    }
    guard result == kIOReturnSuccess else { throw HIDServiceError.reportWriteFailed(result) }
    CFRunLoopRunInMode(runLoopMode, 0.005, false)
  }
}

private final class HIDWriteResult: @unchecked Sendable {
  var error: Error?
}

private final class ConfigurationHIDReader: @unchecked Sendable {
  private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65)
  private var reports: [HIDInputReport] = []
  private var callbackError: IOReturn?

  deinit {
    inputBuffer.deallocate()
  }

  static func read(service: io_service_t, requests: [HIDReport]) throws -> [HIDInputReport] {
    try ConfigurationHIDReader().read(service: service, requests: requests)
  }

  private func read(service: io_service_t, requests: [HIDReport]) throws -> [HIDInputReport] {
    guard let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
      throw HIDServiceError.notConnected
    }
    let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    guard openResult == kIOReturnSuccess else {
      throw HIDServiceError.deviceOpenFailed(openResult)
    }

    guard let runLoop = CFRunLoopGetCurrent() else {
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
      throw HIDServiceError.notConnected
    }
    let runLoopMode = CFRunLoopMode(
      rawValue: "MacroPadStudio.ConfigurationRead.\(UUID().uuidString)" as CFString
    )
    inputBuffer.initialize(repeating: 0, count: 65)
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDDeviceRegisterInputReportCallback(
      device,
      inputBuffer,
      65,
      { context, result, _, _, reportID, report, reportLength in
        guard let context else { return }
        let reader = Unmanaged<ConfigurationHIDReader>.fromOpaque(context).takeUnretainedValue()
        if result != kIOReturnSuccess {
          reader.callbackError = result
          return
        }
        let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
        let normalized =
          bytes.first == UInt8(clamping: reportID)
          ? Array(bytes.dropFirst())
          : bytes
        reader.reports.append(
          HIDInputReport(reportID: UInt8(clamping: reportID), payload: normalized))
      },
      context
    )
    IOHIDDeviceScheduleWithRunLoop(device, runLoop, runLoopMode.rawValue)
    defer {
      IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, 65, nil, nil)
      IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, runLoopMode.rawValue)
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    CFRunLoopRunInMode(runLoopMode, 0.001, false)

    for request in requests {
      let expectedCount = reports.count + MacroPadProtocolDecoder.recordsPerLayer
      var bytes = [request.reportID] + request.payload
      let byteCount = bytes.count
      let writeResult = bytes.withUnsafeMutableBytes { buffer in
        IOHIDDeviceSetReport(
          device,
          kIOHIDReportTypeOutput,
          CFIndex(request.reportID),
          buffer.bindMemory(to: UInt8.self).baseAddress!,
          byteCount
        )
      }
      guard writeResult == kIOReturnSuccess else {
        throw HIDServiceError.reportWriteFailed(writeResult)
      }

      let deadline = Date().addingTimeInterval(2)
      while reports.count < expectedCount, callbackError == nil, Date() < deadline {
        CFRunLoopRunInMode(runLoopMode, 0.05, false)
      }
      if let callbackError { throw HIDServiceError.reportReadFailed(callbackError) }
      guard reports.count == expectedCount else {
        throw HIDServiceError.readTimedOut(expected: expectedCount, actual: reports.count)
      }
    }
    return reports
  }
}
