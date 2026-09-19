# Metal planetarium

Enter with the 3D icon and text next to Full screen on a pass. The selected pass,
observer and time source are shared with the 2D chart. Preview starts at mid-pass;
playback runs at 10×, the slider scrubs, and Live uses the supplied current clock.
The icon-only Find satellite control in the top-right glass capsule returns the camera
to its propagated position and turns motion off. Pinch controls zoom; there are
no separate zoom buttons.
Motion is enabled on entry; unavailable devices retain touch controls.

The sky is an MTKView with four native Metal pipelines: full-screen atmosphere /
landscape / Milky Way, instanced star billboards, anti-aliased screen-space line quads, and textured
billboards. SwiftUI supplies only the glass controls and selected-object card.
The star shader ports StarryNight's Gaussian Airy approximation, flux/exposure,
spectral wavelengths, and sensor calibration, with subdued scintillation and
altitude extinction. No SceneKit renderer or synthetic star field is used.

Disjoint tiers: magnitude ≤3.5 always resident; stars to 6.5 at wide angles, 7.5
below 45°, and 9 below 25°. The deeper catalog loads once on the StarCatalog actor.
15° spatial cells conservatively cull off-screen faint stars, including poles and
the RA seam. Instance buffers change only after a 3° movement, zoom, resize, or
sky-time update. Three in-flight commands are allowed; a busy GPU drops frames
instead of blocking the UI. Resources are immutable while submitted.

The local scene uses east +X, zenith +Y, north −Z. The catalog and Milky Way share
the observer's sidereal transform. Ephemerides refresh every ten seconds of sky
time; the satellite propagates at display updates. Moon phase, albedo, libration,
and earthshine use the existing lunar model. Atmospheric scattering, extinction,
and lens artifacts are artistic approximations, not radiometric predictions.

The planetarium uses NASA SVS's native 16384 × 8192 galactic Milky Way map,
without the 2D chart's blur. Two 8192 × 8192 ASTC 6×6 sRGB tiles (14 mip levels
apiece) retain its detail on 8K-limited GPUs, including the simulator. Combined
GPU texture storage is approximately 76 MiB; loading uploads compressed blocks
without decoding a 512 MiB RGBA image. Explicit LOD and edge blending handle the
tile boundaries and 360° seam. The separate 2D chart resource is unchanged.

Only the constellation whose visible center is angularly nearest the camera
shows its lines. Each complete star-to-star edge fades and tapers toward both
ends, with a five-point clearance around each star (capped on very short
edges). Line opacity is 0.36 so stars remain the visual focus. On a focus change the old edges contract to their midpoints over 0.24 s,
then the new figure expands over 0.36 s. Reduce Motion switches immediately.
The maximum stroke width is 1.4 points; satellite tracks stay at 2 points.
Segments crossing the camera's near plane are clipped before expansion.

The landscape is procedural Metal: a periodic low mountain ridge, gentle lake
ripples and sky reflection at grazing angles. Looking down reduces reflection
and reveals the shallow mineral bed. The same ridge profile masks celestial
objects and selection hit testing. This illustrative landscape is not site-specific.
Bright stars retain StarryNight's calibrated core and spectral color, with an
importance-weighted brightness boost, soft halo and fine diffraction spikes.
Faint-star tiers remain unchanged. No landscape bitmap is loaded.

Source URLs, checksums, and MIT notices are in bundled PlanetariumCredits.txt;
`scripts/prepare-planetarium-textures.py` reproduces the Milky Way assets.

Validation requires a Metal-capable simulator and the Xcode Metal Toolchain.
Physical-device checks are still required for true-north calibration, portrait /
landscape motion, thermal performance, and permission-denied motion fallback.

## Validation (2026-09-17)

- iPhone 17 Pro Max / iOS 26.5, dark mode: final combined run **11 passed,
  0 failed, 0 skipped**, including the opt-in live MTKView review and dark
  pass-entry snapshots. iOS device build also passed with signing disabled.
- GPU checks cover actual pipeline/ASTC texture loading, 1.4-point stroke
  thickness, behind-camera and near-plane clipping, 360° wrap continuity,
  satellite propagation, overlay rendering, zoom limits, and pause/resume.
  Geometry, disjoint magnitude tiers, polar/seam culling, and star/Moon selection
  are covered separately. A loading test caught the simulator's 8K texture limit;
  the two-tile implementation resolves it while retaining native resolution.
- Simulator interaction checks exercised the 3D entrance, close/reopen, all
  toolbar toggles, unavailable-motion fallback, zoom buttons, drag panning,
  playback/pause, scrubbing, Live, satellite recentering, and Enif/Jupiter glass
  cards with dismissal. Reopening restores the default enabled motion control.
- Visually reviewed dark-mode GPU captures of the galactic core at 65° and 22.75°,
  the horizon facing north/east/south/west, the phase-lit Moon and halo, and the
  solar atmosphere/flare. Daytime sky was inspected inside the dark-mode UI.
- New review captures are in `DesignReview/Planetarium/Feedback/`:
  [Milky Way detail](DesignReview/Planetarium/Feedback/02-milky-way-zoom-dark.png),
  [open horizon](DesignReview/Planetarium/Feedback/03-horizon-90-dark.png),
  [controls and satellite](DesignReview/Planetarium/Feedback/06-controls-and-satellite-dark.png),
  [Jupiter card](DesignReview/Planetarium/Feedback/09-jupiter-selection-dark.png),
  [star card](DesignReview/Planetarium/Feedback/12-star-selection-dark.png).
- True-north motion accuracy, physical pinch gestures, permission-denied motion,
  and sustained GPU/thermal/battery performance still need physical-device
  validation; simulator checks do not establish those properties.

## Header control revision (2026-09-17)

Moved satellite centering to an icon-only button beside the satellite name,
retaining its accessibility label. Removed the lower control row and zoom
buttons; the existing pinch recognizer is unchanged. Dark-mode interactive
review with the full satellite name verified header layout, recentering, and
the selection card immediately above the toolbar.

[Updated header and selection card](DesignReview/Planetarium/Feedback/13-header-controls-star-card-dark.png)

## Options menu revision (2026-09-17)

Satellite centering, the ellipsis menu, and Close share one glass capsule at
the top right, each with a 44-point target. The ellipsis opens a native menu
containing constellation-label, constellation-line, and gyroscope toggles;
the lower panel now contains only playback, scrubbing, and Live. Rebuilt and
reran in the dark-mode simulator, exercised all three menu toggles, reviewed
the resulting sky, and verified Close returns to the pass screen. The interactive
test passed. [Dropdown review](DesignReview/Planetarium/Feedback/15-options-dropdown-dark.png).

Combined capsule reviewed in dark mode; centering, dropdown, and dismissal
verified after rebuilding and rerunning. [Updated header](DesignReview/Planetarium/Feedback/18-combined-header-oval-dark.png).

## Compact title revision (2026-09-17)

The station header uses ISS (identified by NORAD ID, including when opened
from a broader satellite category). Other satellite names are unchanged.
Removed the preview/live status and field-of-view row; the date/time and
bottom playback controls remain.

Dark-mode simulator review confirmed the compact header and removed row;
centering, playback/pause, and dismissal passed.
[Compact header review](DesignReview/Planetarium/Feedback/20-compact-iss-header-dark.png).

## Art direction revision (2026-09-18)

Replaced the ground panorama with original procedural mountains and water;
added spindle-shaped constellation edges, serial contraction/expansion of the
nearest constellation, and brighter principal stars with diffraction accents.
The old landscape bitmap is no longer bundled.

After rebuilding and rerunning, all **11 PlanetariumTests passed, 0 failed,
0 skipped** on iPhone 17 Pro Max / iOS 26.5. Coverage includes the focus handoff,
low ridge masking and seam continuity, Metal ABI and texture loading, actual
GPU line width/clipping, zoom bounds, 360-degree camera wrap, satellite time,
overlays, selection and pause/resume. The opt-in live review exercised all three
menu toggles, playback/pause, scrubbing, Live, drag panning, recentering, and
Deneb's selection card/dismissal. Its longer duration includes manual review.

Dark-mode captures in `DesignReview/Planetarium/ArtDirection/` include:
- [Bright stars and tapered Cygnus](DesignReview/Planetarium/ArtDirection/06-cygnus-spindles-dark.png)
- [Mountains, lake and selection card](DesignReview/Planetarium/ArtDirection/08-lake-horizon-dark.png)
- [Clearer downward view](DesignReview/Planetarium/ArtDirection/09-clear-water-down-dark.png)
- [Recorded contraction/expansion](DesignReview/Planetarium/ArtDirection/focus-transition-dark.mp4)

Reviewed the transition recording frame by frame, four horizon directions,
three downward angles, Milky Way detail, Moon and solar atmosphere captures.
Simulator rendering does not establish physical-device thermal performance
or gyroscope accuracy.

## Water sampling refinement (2026-09-18)

The former fixed reflected-ray height created vertical sky leaks between low
ridges. The direct and reflected mountains now share a continuous shoreline
material, and reflected rays below the skyline remain mountain-colored.

Water uses ten directional gravity-wave components with varied wavelengths,
phases and directions. Angular speed follows omega = sqrt(g k); the slopes
are the analytic gradient of a height field. Pixel-footprint filtering removes
unresolvable waves before the Nyquist limit, including anisotropic grazing
views. Their missing slope variance broadens the reflected skyline instead
of creating flickering micro-silhouettes. A small temporal filter targets the
renderer’s 30 Hz update rate. Bed detail is also filtered by its pixel footprint.

Removed the repeating sine-product caustics and independent ripple-brightness
term. Water color now comes from view-dependent Fresnel sky/terrain reflection
(F0 = 0.0204) and subdued bed transmission/absorption. This is a physically
informed calm-water approximation with artist-tuned wave amplitudes, not a
full fluid solver or a measured wind spectrum. It retains the existing Metal
pass and allocates no simulation textures or additional per-frame CPU buffers.

References informing the original implementation:
- [GPU Gems: Effective Water Simulation from Physical Models](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
- [Bruneton, Neyret and Holzschuch: Real-time Realistic Ocean Lighting](https://morpho.inrialpes.fr/Publications/2010/BNH10/)

Validation: **11 automated tests passed** (the opt-in review skipped in that
run); **the separate live review passed**, covering all 12 test methods.
The new GPU regression compares the first 35 water rows at native resolution
against a 3x supersampled reference (mean RGB error threshold 2/255), checks
30 Hz temporal stability, and verifies the waves continue to animate.
Reviewed dark-mode live shoreline panning, 65-degree and 25-degree fields of
view, downward water, and a frame sequence from the animation recording.
Rebuilt and reran after the shader change. Physical-device thermal and frame
budget measurements are still outstanding.

- [Updated shoreline](DesignReview/Planetarium/WaterRefinement/12-live-shoreline-dark.png)
- [Zoomed shoreline](DesignReview/Planetarium/WaterRefinement/14-zoomed-shoreline-dark.png)
- [Water animation and pan](DesignReview/Planetarium/WaterRefinement/water-motion-dark.mp4)

## Constellation spacing (2026-09-18)

Added five-point screen-space clearance at each star and reduced line opacity
from 0.64 to 0.36. The spindle taper restarts at the inset endpoints; the gap
is capped at 20% per end on short or contracting edges. Satellite tracks are
unchanged. The focused GPU clipping/width test and interactive review both
passed. Dark-mode captures at 65 and 35 degrees confirm spacing across zoom.

[Star gaps](DesignReview/Planetarium/LineSpacing/01-star-gaps-dark.png) ·
[Zoomed gaps](DesignReview/Planetarium/LineSpacing/02-star-gaps-zoom-dark.png)

## Stable selection cards and planet miniatures (2026-09-18)

Star cards now publish only after the catalog name lookup completes. The
previous finished card remains in place during a replacement lookup, and
cancelled requests cannot replace a newer selection or reopen a dismissed card.
Lookup failure still produces a complete catalog-ID fallback card. A 48-point
icon slot is shared by star glyphs and planet globes to keep text alignment stable.

Planet cards use a separate tiny Metal view with an analytically intersected
3D sphere, rotating equirectangular material coordinates and fixed view lighting.
There are maps for all eight planets; Earth is supported as the rotation reference
and in rendering tests, though it is not a selectable object in this Earth-based sky.
Venus uses opaque cloud-top imagery and a warm atmospheric limb; Earth adds
clouds and blue scattering, Mars has a faint dusty limb, and Saturn has inclined
rings with correct front/back globe occlusion. These are illustrative miniatures,
not the observed angular size, instantaneous phase, or an atmospheric simulation.
Venus’s clouds follow its body rotation here; atmospheric superrotation is not modeled.

Rotation periods use NASA’s signed tabulated hours, at 10 seconds per 24 hours:
Earth exactly 10 s, Jupiter 4.125 s, Saturn about 4.46 s, Mars 10.25 s,
Venus about 40.5 minutes retrograde, and Uranus about 7.17 s retrograde.
The spherical UV lookup applies the inverse body rotation and wraps longitude
sampling derivatives to prevent a moving mip stripe at the texture seam.

512-pixel maps and the render pipeline are shared across card changes. The
miniature renders at 30 fps only while displayed and active, with two in-flight
commands; Reduce Motion displays a still globe. A native window lifecycle hook
ensures the first frame renders even in an inactive auxiliary review window.

Maps: [Solar System Scope / INOVE](https://www.solarsystemscope.com/textures/),
CC BY 4.0, resized from 2K; full attribution is in PlanetariumCredits.txt.
Periods: [NASA Planetary Fact Sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/).

The full Planetarium suite passed 14/14 after the selection/lifecycle changes.
The final UV direction/filter refinement passed the three automated globe,
rotation and selection checks, plus the live review. Uranus’s nearly uniform
cloud map is excluded from the image-difference rotation threshold; its signed
rotation period is checked numerically.
Dark-mode live review verified Jupiter’s animated globe and four successive
star selections without movement of the card’s dismissal control. Automated
checks cover no provisional star card, cancellation/dismissal, rotation scaling
and retrograde direction, all eight material/pipeline loads and rotating GPU output.

- [All eight globe materials](DesignReview/Planetarium/SelectionGlobes/globe-materials-dark.png)
- [Jupiter card](DesignReview/Planetarium/SelectionGlobes/01-jupiter-card-dark.png)
- [Stable star selection recording](DesignReview/Planetarium/SelectionGlobes/stable-star-cards-dark.mp4)
- [Rotating Jupiter recording](DesignReview/Planetarium/SelectionGlobes/jupiter-card-rotation-dark.mp4)

### Offscreen station navigation — September 18

An above-horizon station during the selected pass gets a 62%-opaque white,
notched direction arrow when outside the camera frustum. The 48-point touch target
stays in the free sky area between the header and bottom cards. Camera-relative
bearings include device roll and do not reverse when the station is behind the
viewer; directly behind consistently points right. No arrow is shown for an
unavailable snapshot or a station outside the selected pass/above-horizon interval.

Tapping the arrow or the existing recenter control disables gyroscope control
and pans to the station over 0.7 seconds, taking the shorter azimuth turn. The
pan follows the current satellite position, supports manual interruption, and
centers immediately with Reduce Motion. Navigation advances with Metal frames;
SwiftUI arrow state is published after layout.

Validation: three focused simulator tests passed (direction/frustum/behind-camera
math, deterministic animated centering and cancellation, interactive fixture).
Dark-mode UI checks confirmed the arrow appears from four camera directions,
remains clear of controls, and disappears after tapping to center the ISS.
Evidence: `DesignReview/Planetarium/OffscreenStation/`, including the tap recording.
The same navigation uses the selected satellite context for ISS and Tiangong.

### Daytime constellation visibility — September 18

Constellation labels and lines are suppressed whenever the Sun's elevation is
zero or higher. Existing line geometry clears immediately at sunrise; user toggle
preferences are retained and apply again after sunset. The focused GPU overlay
regression passed: daytime pixels match with both toggles enabled or disabled,
and constellation focus returns at night. Dark-mode simulator render reviewed in
`DesignReview/Planetarium/Daytime/daytime-overlays-hidden-dark-ui.png`.
