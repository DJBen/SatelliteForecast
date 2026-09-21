# Daytime star selection verification — 2026-09-20

The star shader faded catalog stars gradually, but labels were disabled whenever the Sun was above the horizon and hit testing stopped at 85% daylight. Bright stars could therefore remain visible without names or selection.

Labels and hit testing now use the shader's steady intensity threshold, including magnitude, altitude extinction, daylight and zoom exposure. Scintillation changes brightness without repeatedly enabling/disabling labels or tap targets. Existing label budgets, overlap avoidance and the labels setting still apply. Fully faded stars leave neither labels nor tap targets.

Validation on iPhone 17 Pro Max, iOS 26.5 simulator, dark mode:

- App built and ran successfully.
- Six targeted tests passed: daytime labels/selection, GPU daylight/zoom visibility, star name visibility, twinkle stability, catalog star/Moon selection, and preview tracking/sky rotation.
- GPU checks cover visible bright daytime stars, faded faint daytime stars, faint stars becoming visible when zoomed, fully faded stars, and night visibility.
- Daytime regression also verifies selection with labels disabled and removal of invisible tap targets. Reran successfully after allowing the screenshot's label entrance animation to finish.
- Full hosted screen reviewed; a simulator tap on Arcturus opened its named selection card.

`camera.json` records the regression fixture's sky date and camera direction. The fixture observer is 37.486743° N, 122.226560° W. `daytime-star-selected-dark.png` is a Metal render; `daytime-star-card-dark.jpg` is the simulator screen after tapping. The interactive fixture overrides the sky date independently of the preview clock displayed in the controls.

No analytics events, screen names, or measurement boundaries changed.
