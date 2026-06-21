**Comparison Target**
- Source visual truth: `Design/focused-key-editor-reference.png`
- Implementation screenshot: `work/implementation.png`
- Full-view comparison: `work/design-comparison.png`
- Viewport: 1360 x 820 points for the production content panes; light appearance; demo profile.
- State: Layer 1/Base, Key 2 selected, macro action editor visible, inspector expanded.
- Intentional state difference: the approved concept illustrated six keys and one knob. The connected physical `MINI_KEYBOARD` was verified by the user as three keys and one knob, so the implementation uses the correct 3+1 geometry.

**Findings**
- No actionable P0, P1, or P2 visual mismatches remain.
- [P3] Native-control placeholders in the deterministic screenshot
  Location: Picker, Toggle, Menu, and Stepper controls in `work/implementation.png`.
  Evidence: SwiftUI's offscreen `ImageRenderer` displays yellow unavailable-control markers for some AppKit-backed controls. The launched native app renders these controls normally.
  Impact: This affects only the automated evidence image, not the built application.
  Fix: Re-capture with macOS Screen Recording enabled for the test host if pixel-level native-control evidence is required.

**Required Fidelity Surfaces**
- Fonts and typography: system typography, weights, hierarchy, and compact labels follow the reference's native macOS character.
- Spacing and layout rhythm: the three-pane structure, selected-key emphasis, editor hierarchy, and inspector grouping match the reference. The compact device card was tightened after the first QA pass so neither rounded edge clips.
- Colors and visual tokens: neutral window surfaces, blue selection/accent color, semantic green/orange states, subtle dividers, and restrained shadows are consistent with the reference.
- Image quality and asset fidelity: no supplied logo or product imagery was replaced. The hardware editor is an interactive production control surface adapted to the verified 3+1 device geometry.
- Copy and content: labels are task-focused and native; Bluetooth discovery and USB write requirements are explicit.

**Focused Region Comparison**
- A separate crop was not needed. The combined board keeps the device canvas, selected key, macro editor, inspector grouping, typography, and spacing legible at the comparison resolution.

**Patches Made Since Previous QA Pass**
- Changed `0x1189:0x8840` physical geometry from the community table's 6+2 layout to the user's verified 3+1 layout while retaining the extended protocol.
- Added Bluetooth `MINI_KEYBOARD` discovery with read-only status until USB configuration is available.
- Removed invalid delay defaults for the legacy 3+1 profile and migrated loaded legacy drafts to zero delay.
- Removed unnecessary pane scroll containers at the enforced minimum window height.
- Reduced compact key widths and padding to eliminate device-card clipping.

**Implementation Checklist**
- [x] Correct 3-key, 1-knob hardware geometry.
- [x] Focused key editor and inspector hierarchy.
- [x] Explicit safe write review and USB gating.
- [x] Deterministic production-pane snapshot test.
- [x] Full unit test suite passing.

**Follow-up Polish**
- Capture an unrestricted native window screenshot for archival evidence when Screen Recording permission is available.

final result: passed
