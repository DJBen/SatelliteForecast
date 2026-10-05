Orientation transition refinement — October 4, 2026

Reviewed the user’s 17:01 screen recording before making this change. The compact cue now anchors at the chart bottom right. Both positions stay fixed; the native GlassEffectContainer/ID transition handles the glass surface, with opacity transitions for the content. Whole-view matched geometry stretching was removed. The transition uses a 0.35-second smooth animation and honors Reduce Motion. The three-dot cue, X close action, two-close threshold and persisted suppression are retained.

Dark simulator review includes opening and closing captured in transition.mp4, full chart screenshots, and localized/large-text fixtures. Both focused review tests passed, including the actual two-close and saved suppression interactions. The final Debug app built, installed and launched on Sihao’s iPhone; evidence is in device-build.log, device-install.log and device-launch.log. No telemetry or screen semantics changed. This is not a new TestFlight upload.

Native simctl screenshots and video are the appearance evidence. UIKit drawHierarchy localized fixtures render the native glass overlay close icon as blurred even after settling; this capture artifact is absent from the native full-chart screenshots. Localized text and accessibility layout remain readable.
