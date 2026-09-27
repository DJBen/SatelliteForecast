# Widget marketing compositions

Three editable design concepts, generated at 1320 × 2868 pixels from actual native widget review renders. These are marketing compositions, not installed Home Screen captures or upload-approved release screenshots.

- **01 — Sky hero:** a large feature image with benefit-led copy. Recommended primary widget marketing slot.
- **02 — Layout choices:** compares the two small configurations and the medium two-station layout. Recommended companion image to demonstrate customization.
- **03 — Chart explained:** external callouts explain the time, flight path, and surrounding sky. An alternative to 01 when education matters most.

The native UI assets are unchanged apart from proportional scaling. Backdrops, orbit-inspired rings, typography, shadows, and callouts are programmatically generated. No third-party stock artwork or device mockup asset is required. Arial is loaded from the local macOS system fonts and is not redistributed.

Run `python3 Documentation/AppStore/WidgetConcepts/build.py` with Pillow installed to regenerate. Copy, palette, layout, and source selection live in `build.py`. Open `index.html` to compare full-resolution exports.

Before release: choose the compositions, review localized headlines at full size, and replace review fixtures with the selected release's verified observer/time/TLE inputs. The current fixtures demonstrate functionality; the two-station examples are review data, not a claim about current real-world passes. Preserve sky fidelity: only show celestial objects actually present in the selected scene. Follow the publishing guide for release assets. No store metadata or screenshots were uploaded by this task.
