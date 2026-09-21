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

### Forward-moving satellite path pulse — September 18

A soft highlight travels along the pass from earlier to later snapshots. Vertices
carry cumulative angular distance, keeping the highlight continuous across sample
boundaries and independent of snapshot spacing. The Metal fragment shader draws
repeating tapered pulses at 0.45 cycles per second, spaced 0.35 radians apart.
The base path stays visible and retains its illuminated/shadowed color distinction.
This is a direction cue, not a representation of orbital speed; it continues while
preview playback is paused. Reduce Motion preserves the original static path.

Rebuilt and reran in the dark-mode simulator. All three focused tests passed
(line clipping/stroke regression, GPU overlay/time regression, interactive review).
Reviewed successive frames of `DesignReview/Planetarium/PathPulse/forward-pulse-dark.mp4`.

The future portion of the path is now round-dotted; the elapsed portion stays
solid. Per-vertex seconds relative to rise are interpolated and compared with the
selected preview/live time in Metal, so the boundary follows the station without
rebuilding path geometry. Dots remain anchored to angular distance and retain the
forward pulse; Reduce Motion disables only the pulse. Two focused simulator tests
passed (GPU overlay/time regression and interactive review). Reviewed
`DesignReview/Planetarium/PathPulse/future-path-dotted-dark.png` in dark mode.

### Telescope zoom and lunar exposure — September 18

The field-of-view range is now 2–100 degrees (previous minimum: 12 degrees).
Planetarium lunar textures use a 512-pixel disk at half exposure before the 8-bit
conversion, preserving bright terrain that was previously clipped. Wide views
restore the original brightness in Metal; from 18 down to 2 degrees the disk
smoothly dims and atmospheric glow drops by up to 95%. Disk opacity and phase
remain unchanged. The lunar label stays outside the enlarged disk. Other chart
Moon imagery retains its default exposure and resolution.

Three focused tests passed: zoom/overlay GPU regression, star/Moon selection,
and interactive simulator review. Reviewed 12° and 2° lunar screenshots in dark
mode under `DesignReview/Planetarium/MoonZoom/`.

### Higher-detail lunar surface — September 18

The previous 512x256 source map was the remaining resolution bottleneck. The
planetarium now uses a dedicated NASA SVS/LROC 4096x2048 map and a 1024-pixel disk.
A monotonic 1.35-power albedo curve increases maria/highland contrast without
clipping highlights. Detailed disk generation runs off the main actor and is
cached for 60 seconds of simulated time, while position updates remain live.
The existing small chart Moon continues using its original resource and shading.
The source and attribution are in PlanetariumCredits.txt. Reviewed the same
2-degree lunar view in `DesignReview/Planetarium/MoonZoom/moon-4k-detail-dark.png`.

### Compact Now / Preview time control — September 18

A native segmented picker sits at the bottom right. Now replaces the playback
controls with a larger localized numeric date and hours/minutes/seconds clock on
the left. The clock updates once per second with SwiftUI numeric-text transitions
and respects Reduce Motion. Preview shows a compact play button and scrubber in a
56-point bar. Mode changes pause playback and preserve the selected pass position.
Opening a pass still starts in Preview. The redundant header date is hidden in Now.

Dark-mode UI checks verified play/pause, hiding the slider in Now, and restoring
Preview paused. Captures: `DesignReview/Planetarium/TimeModes/`. All 272 implementation
keys passed the eight-language localization audit. No analytics events were added.

### Moon and planet motion trails — September 18

The Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, and Neptune now have
apparent-motion trails sampled every 0.5 day across ±7 days around the displayed
time (29 sample points including both endpoints). Each dot is an ephemeris sample,
not a repeated dash along interpolated geometry. Samples are stored in the stellar
frame and transformed using the current observer frame, avoiding daily sky-rotation
loops. Lunar parallax uses the observing site's fixed inertial position at the
current epoch; the dots illustrate orbital motion, not future horizon positions.
Past samples are fainter; body-color families distinguish the trails. The samples
refresh every simulated minute and render in one instanced Metal draw call. Ground
occlusion and daylight fade apply. At wide zoom, slow outer-planet samples can
overlap; zoom resolves their true angular spacing.

Three focused simulator tests passed (pipeline/textures, GPU time/overlay regression,
and interactive review). Moon at 40° and Neptune at 2° were reviewed in dark mode:
`DesignReview/Planetarium/MotionTrails/`.

Planetary trails now use 365 daily samples centered on the displayed UTC date
(offsets −182 through +182 days). The Moon retains its ±7-day, 12-hour sampling.
Planet samples are cached per UTC day while the observer projection remains live;
minute refreshes only recalculate the lunar samples. Two focused simulator tests
passed (GPU time/overlays and interactive review). Reviewed the annual Neptune
retrograde arc in `DesignReview/Planetarium/MotionTrails/planet-year-daily-dark.png`.

### Constellation line visibility at close zoom — September 18

Each edge now fades according to its original stars' projected separation. The
close-zoom behavior blends in from 30° to 18° field of view. At close zoom an edge
starts fading at 55% of the shorter viewport dimension and disappears at 95%.
Shorter edges remain visible; zooming back out restores the figure. Visibility
updates with camera, viewport, and observer-frame changes, independently of the
existing shrink/expand constellation handoff.

Three focused simulator tests passed (stroke/clipping, GPU zoom/time/overlays,
and interactive review). Dark-mode captures at 40°, 12°, and 2° are in
`DesignReview/Planetarium/LineZoom/`; the 40° capture also verifies restoration
after zooming back out.

The bottom time card now shares its date/time row between Now and Preview, using
the displayed simulation time in both modes. Preview places play/pause and the
slider on a second row spanning the card width. The duplicate header timestamp
was removed. Dark-mode interactive review verified clock updates while scrubbing,
play/pause, hiding the slider in Now, and restoring Preview's time and progress.
Screenshots: `TimeModes/preview-full-width-dark.png` and
`TimeModes/now-shared-clock-dark.png` within the review directory. No analytics
semantics changed.

### Major planetary moons — September 18

Added Phobos/Deimos, Io/Europa/Ganymede/Callisto, Mimas/Enceladus/Tethys/Dione/
Rhea/Titan/Hyperion/Iapetus, Miranda/Ariel/Umbriel/Titania/Oberon, and Triton/Proteus.
Pinch zoom now reaches 0.005° field of view. Moons appear below 2° only when at
least eight screen points from their parent; the same rule governs hit testing.
Daylight and ground visibility still apply. Selecting a moon shows its own orbit;
selecting its parent shows the system's orbits. Each displayed orbit covers
**exactly one orbital period**, sampled at 129 points. These local orbits are
separate from the existing annual planetary proper-motion trails.

Positions use NASA/JPL Horizons geocentric ICRF vectors with light-time correction,
UT timestamps, and kilometre/second units. The observer's inertial position is
subtracted locally. Moon/parent pairs are sampled over 1.2 periods with 192
intervals and interpolated with cubic Hermite position/velocity interpolation.
The extra interval is interpolation padding, not extra visible revolutions.
Subtracting the parent's sampled motion and anchoring on its current position
produces the local orbit overlay. Spherical parent occultations hide moons behind
the planet; mutual moon eclipses and planetary shadow illumination are not modeled.

Only the system being enlarged is requested. Requests are serialized, identify
the app, and back off for two minutes on failure. One bounded window per moon is
cached on disk (21 files maximum), reused offline while valid. New dates/systems
need internet access; unavailable/out-of-window ephemerides are hidden rather than
extrapolated. Horizons response versions 1.2 (observed live) and 1.3 (documented)
are supported. Observing coordinates are never sent to Horizons.

Moon materials are original 128px procedural ice/rock/sulfur studies, with hazy
amber Titan, fractured Europa, cratered icy moons and darker irregular moons.
They are illustrative fixed-lighting thumbnails, not spacecraft surface maps or
physical rotational/phase models. Resolved parent disks reuse the existing Metal
planet materials at 256px. Moon orbit dots use a smaller radius than annual trails.

Sources: https://ssd-api.jpl.nasa.gov/doc/horizons.html,
https://ssd-api.jpl.nasa.gov/doc/,
https://ssd.jpl.nasa.gov/sats/phys_par/ and https://ssd.jpl.nasa.gov/sats/elem/.
Mean periods determine sampling span only, never positional ephemerides.

Validation: four focused simulator tests passed, including live Horizons windows
for all 21 moons, exact one-period orbit spans, malformed/out-of-range rejection,
and GPU zoom/time/overlay regression. An independent Horizons Io midpoint differed
from Hermite interpolation by 0.0054 km. Dark-mode interaction review verified
Io/Titan selection, parent-system orbits, zoom visibility/restoration, dismissal,
and label collision suppression. Captures: `DesignReview/Planetarium/NaturalMoons/`.

### Milky Way temporal stability — September 18

Two sources were isolated: negative mip bias (−0.35) exposed unresolved panorama
grain during camera movement, and the catalog applied animated scintillation even
to faint stars. Its phase also depended on instance order, so culling could reset
it. The panorama alone is pixel-identical at fixed camera position across time.

The sky shader now selects an unbiased trilinear mip from the largest singular
value of the projected pixel footprint. This footprint measure is invariant to
screen-axis rotation; the former maximum derivative-column length was not. Tile
and longitude seam handling is retained. Magnification still samples level zero;
the native 16K ASTC assets, color, brightness, and resolution are unchanged. Faint
stars at magnitude 3.5 or dimmer are steady. Brighter stars retain gentler,
altitude-dependent scintillation with a coordinate-derived, stable phase.

Compared the original, 2×2 pixel-area sampling, and footprint-matched mip filtering
using eight small camera steps and 4×-resolution reference renders. Mean absolute
spatial error and frame-to-frame sampling-error change are in 8-bit channel units:

| Filter | Spatial error | Temporal residual |
| --- | ---: | ---: |
| Original | 0.3853 | 0.2425 |
| Pixel-area prototype | 0.3650 | 0.2186 |
| Footprint mip (selected) | 0.3742 | 0.1888 |

The chosen filter reduces temporal residual by 22% in this fixture with the same
texture lookup count as before. The area prototype had a small spatial advantage
but higher temporal residual and extra sampling cost. These are simulator image
metrics, not a device FPS claim or a universal noise-reduction percentage.

GPU regression checks cover static galaxy invariance, subpixel camera movement,
faint-star stability, retained bright-star twinkle, phase invariance under buffer
reordering, and water sampling. Dark-mode app captures include wide and 8° views.
Evidence and metrics: `DesignReview/Planetarium/GalaxyStability/`.
Apple filtering reference:
https://developer.apple.com/documentation/metal/improving-texture-sampling-quality-and-performance-with-mipmaps

### Close-zoom photographic grain — September 19

The temporal stability fix above remains in place. A separate close-zoom filter
now suppresses the tiny baked-in photographic speckles that become enlarged
against the dark background. It blends in between 32° and 10° field of view.
At close zoom, linear-light mip levels 5 and 3 separate diffuse structure from
fine variation; low-contrast residual detail is suppressed while stronger dust
lane structure survives. This supersedes the previous level-zero magnification
behavior only at close zoom. Original assets and catalog-star rendering remain
unchanged, and wide views retain the previous sampling.

The 8° isolated-background fixture's local high-frequency residual decreased
from 1.1764 to 0.1202 in 8-bit channel units. This is a spatial grain metric,
not a general image-quality or device performance score. Close views deliberately
lose fine photographic speckles; separate catalog stars remain sharp. The filter
adds two panorama samples only below 32°. Temporal sampling and star-twinkle
regression tests still pass. Dark-mode evidence:
`DesignReview/Planetarium/GalaxyGrain/`.

### Selection-only motion trails — September 19

Annual planetary trails and the Earth's Moon trail are now shown only for the
selected body. Dismissing or replacing the selection immediately clears or
switches the GPU trail buffer; subsequent time refreshes retain this policy.
Natural moon orbits retain their existing selected-moon/selected-parent and
close-zoom visibility rules. Regression coverage checks no selection, a star,
a planet, the Moon, dismissal, and a time refresh after dismissal.

### Directional body trails — September 19

Selected planets and Earth's Moon now share the ISS segment rendering: a solid
past, round dotted future, and animated highlight advancing with ephemeris time.
Reduce Motion disables the highlight animation. Planet geometry covers 365 days
at six-hour intervals; lunar geometry covers ±7 days at fifteen-minute intervals.
Visible dot spacing is decoupled from those samples and scales with the viewport,
so the Moon no longer appears as isolated twelve-hour marks. The current epoch
is an exact vertex. Only the selected body's geometry is calculated/uploaded.

Selected natural-moon/parent orbits use the same styling and remain one orbital
period long. Missing or occulted samples break segments instead of bridging
through the planet. These local orbits remain restricted to enlarged views.
Daytime annotations remain suppressed. GPU regression coverage checks animated
output, solid-versus-dotted coverage, buffer clearing, and occultation gaps.

### Follow Device control — September 19

The header pill now contains Follow Device, Sky options, and Close. Follow Device
uses location.north.line (filled/cyan when enabled) and replaces Find satellite;
the offscreen station arrow still recenters the station. The menu contains only
constellation labels and lines. Motion preference lives in the controller so
manual dragging, recentering, and the UI cannot disagree. A pan stops motion
immediately and preserves the current direction and roll; translation follows
the frozen screen axes. Late callbacks from stopped sensor sessions are ignored.
Background suspension preserves the chosen mode and cannot undo a manual drag.
Simulator coverage injects orientation into the same camera-update path; actual
sensor tracking still requires physical-device review.

### Momentum panning — September 19

Pan release now starts inertia using gesture velocity and zoom-scaled screen
translation, inspired by StarryNight/Planetarium/Metal/Camera.swift. Exponential
decay matches its 0.9-per-frame damping at 60 Hz but integrates elapsed time to
keep 30/60/120 Hz behavior consistent. Speeds are capped at 3000 points/second
and settle below 8 points/second. Dragging still disengages Follow Device.
New drags, taps, zoom, camera recentering, motion tracking, and backgrounding
cancel inertia. Reduce Motion suppresses coasting; a frame gap over 250 ms
cancels it to avoid a jump after suspension. Regression tests cover refresh-rate
consistency, settling, interruptions, and the existing motion-to-manual handoff.

### Pole-safe manual panning and leveling — September 19

Manual drag and inertia now use bounded yaw/pitch deltas scaled by field of view.
This replaces screen-tangent reprojection, whose azimuth rate grew sharply near
zenith/nadir. Elevation clamps at ±89.5° without crossing and flipping heading.
Beginning a manual drag clears device roll while retaining the viewing direction;
this supersedes the earlier roll-preserving handoff. Pole regression checks cover
both ends, stable yaw sensitivity, no heading flip, and the leveled handoff.

### Profile-guided rendering improvements — September 19

The Metal view now targets 60 FPS and Follow Device samples at 60 Hz. Clock and
preview state live in their own SwiftUI view. The offscreen arrow and selection
card observe separate state objects; renderer-only field-of-view changes no
longer publish screen-wide invalidations. Repeated motion availability values
are not republished.

Star cells precompute their magnitude tiers once. Each visible cell/tier gets an
immutable Metal buffer on first use and reuses it on subsequent visits. Catalog
replacement clears the cache; already-submitted commands retain old buffers until
completion. Zoom refreshes use angular overscan (2° FOV change, 3° camera change)
and magnitude-tier changes instead of forcing a rebuild for every pinch event.
GPU star conversion and upload now happen only for uncached cell/tier pairs.
Visual quality, panorama resolution, Moon detail, and the existing galaxy filters
are unchanged.

Regression checks compare cached versus uncached GPU output, validate tier
membership and buffer reuse, and assert camera/arrow/card changes do not publish
whole-screen updates. The phone uses an optimized Release build for follow-up
measurement. A new physical-device trace is needed before claiming sustained
60 FPS or numerical CPU/GPU improvements.

### Satellite marker/path consistency — September 19

The 3D pass track is regenerated from the context's current SatelliteInfo and
observer instead of reusing cached forecast snapshot positions. Samples are no
more than one second apart and include the exact rise/set endpoints. Rendering,
marker interpolation, illumination, and the solid/future-dotted split share the
same time-indexed track. The marker uses normalized chord interpolation, exactly
on the rendered segment, avoiding discrepancies between separate path and marker
calculations. This also removes per-tick SGP4 propagation from the UI timer.
Regression checks cover intermediate times, the rendered segment endpoints,
sub-second sampling, out-of-range visibility, and agreement with independent
orbital propagation. This guarantees internal consistency, not fresh orbital
elements; updating TLE data remains the ephemeris service's responsibility.

## Celestial typography and bright-star names

Sky constellation/body names use the system serif design (Apple New York) in both the 2D chart and Metal planetarium, with system glyph fallback for other scripts. The 3D labels retain mixed case and are rasterized at 2× texture resolution. Selected celestial-object names use the same serif design; controls and numerical readouts retain their existing fonts.

`AppStarCatalog.load()` enriches the 50 brightest catalog entries once with existing catalog metadata (proper names, otherwise catalog designations), excluding the Sun. The 2D chart and wide planetarium overview reuse the immutable named subset. At 70° FOV or closer, the planetarium ranks all rendered stars in the current viewport, including the deeper magnitude-9 catalog. It refreshes up to 24 candidates every 150 ms and resolves missing names asynchronously through the catalog actor. Proper names fall back to existing catalog designations; a 128-texture cache bounds GPU memory. The planetarium chooses visible stars in magnitude order and caps labels at 3 above 70° FOV, 5 above 35°, and 7 at closer zoom. Label rectangles must fit on screen and avoid body/constellation/station labels. The labels toggle and daytime hiding apply to star names too. The 2D chart uses at most 3 labels on ordinary charts or 6 on charts at least 450 points across, reserving space for displayed constellation and planetary labels and keeping names within the horizon.

Apple API reference: https://developer.apple.com/documentation/uikit/uifontdescriptor/systemdesign/serif

Constellation name opacity falls smoothly with normalized screen distance from the viewport center: unchanged within the central 15%, down to 20% of its normal opacity at the edges. This is evaluated from projected positions each frame, so panning, zoom, aspect ratio, and device roll stay consistent. Star and body labels retain their existing opacity.

## Preview tracking and continuous sky motion

Preview playback uses the Metal render clock at 10 simulated seconds per elapsed second. SwiftUI's timer only refreshes the controls; it no longer advances simulation time in fixed 30 Hz increments. Every rendered preview frame updates the observer's equatorial/local basis. Planet and lunar directions interpolate between cached ephemeris endpoints (10 simulated seconds, or 1 second under 2° FOV); lunar surface images retain their slower refresh schedule. Natural-moon positions interpolate the cached tables each frame, while orbit geometry refreshes at most once per simulated second unless selection or zoom mode changes.

During preview playback and scrubbing, a selected star, planet, or moon retains its camera-space direction. A quaternion rotates the camera's complete basis from the previous selected direction to the new one, preserving off-center positioning and roll without Euler-angle pole singularities. Manual panning changes the anchor naturally. Selection tracking disengages Follow Device; clearing selection ends tracking. Now mode does not engage this tracking. Preview pauses when the app leaves the active scene.

Regression coverage: sub-second sky rotation, off-center star tracking across forward/backward time jumps, elapsed-time playback and end clamping, and Moon tracking over multiple cached ephemeris intervals at close zoom.

### Stable star-label admission

Star labels retain their slots while readable instead of reranking every frame. New labels need 250 ms of uninterrupted clearance, 12 pt horizontal / 8 pt vertical entrance padding, and fade in over 200 ms. Existing labels use 4/3 pt padding and remain ahead of brighter newcomers. A real collision suppresses the label immediately (no fading through other text), with a 600 ms retry cooldown. Candidate refresh retains admitted stars beyond the 24-candidate brightness cutoff; metadata remains asynchronous and textures bounded. Labels clear when disabled or in daylight. The layout is screen-space and independent of frame rate. No analytics events or collection boundaries change.

### Follow Device smoothing

Device orientation uses a quaternion exponential low-pass filter with a 0.25-second time constant and sensor timestamps (`1 - exp(-dt / tau)`), so damping is consistent at 30/60/120 Hz. It smooths yaw, pitch, and roll together along the shortest rotation, including the north wrap and zenith. The first sample after enabling/resuming seeds the filter; interrupted delivery of at least 0.5 seconds also reseeds. Invalid/degenerate poses are ignored. Disabling, suspending, or starting a manual drag resets filter history. The rendered camera uses the filtered orthonormal basis directly; manual dragging still disengages tracking and levels tilt. No analytics changes.

### Continuous live motion and observed planet inclination (2026-09-20)

Live orbital sampling uses the exact time provider value at each 30 Hz timer tick;
only the visible clock is throttled to whole seconds. Existing normalized track
interpolation supplies intermediate positions without repeating orbital propagation.

Resolved planets use IAU J2000 pole directions from NASA NAIF
[pck00011.tpc](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc).
The pole is transformed into the observer's local frame and projected onto camera
right/up for position angle. Signed sub-observer latitude controls the sphere
material latitude and Saturn's ring opening/near-side occlusion. Mars and Neptune
periodic pole terms are included; Jupiter's sub-0.01-degree nutations are omitted.
Viewing inclination and solar phase now share the observed geometry described
below. Texture longitude remains illustrative. All seven visible planets can
resolve without waiting for natural-moon ephemerides.

Sky Chart prefilters the shared Gaia background to 1024×512 with a separable
5-tap blur, wrapping longitude and clamping latitude before sky reprojection.
Catalog stars are unaffected. The static decode is cached; no filtering is added
to animation frames. Dark review images are in
`Documentation/DesignReview/Planetarium/ObservedInclinations/`.
Validation: four orbit/Metal/inclination integration checks and six Galactic
projection/filter tests passed on the iPhone SE simulator (iOS 26.5).
The interactive dark-mode Saturn review also passed; its close-up screenshot is
`ObservedInclinations/saturn-simulator-dark.jpg` (2021-06-07 fixture). Eleven
focused checks passed in total. Simulator verification does not establish device
frame-rate performance.


### Physical planetary phases, Saturn proportions, and Sun labels (2026-09-20)

The Sun label is 15 pt at the existing display scale, with no shadow or outline.
Its text adapts to the estimated sky and solar-glare brightness at the label:
near-black navy on bright backgrounds, pale warm text on darker backgrounds.
Its center clears the angular solar radius (at least 17 pt), plus a 10 pt gap
and half the label height, keeping it close while avoiding the solar disk.

`PlanetariumPlanetAppearance` computes Sun/planet/observer geometry from the
bundled VSOP87A positions, converts the J2000 ecliptic frame to J2000 equatorial,
subtracts the terrestrial observer position, and iterates down-leg light time.
The projected IAU pole defines an orthonormal disk basis. The Sun vector in this
basis drives the terminator and illuminated fraction; the pole drives the ring
opening and the screen position angle. Camera roll is applied consistently to
both the resolved sky texture and selection-card model. Selected globes retain
illustrative accelerated texture rotation, while phase and pole orientation stay
fixed to the observed geometry. Surface longitude is not a calibrated ephemeris.

Saturn is an oblate spheroid with equatorial/polar radii 60,268/54,364 km.
The C ring begins at 74,658 km, B at 91,975 km; the Cassini division spans
117,507–122,340 km, and the main A ring ends at 136,780 km (2.2695 equatorial
radii). The old 1.91 outer radius was too small. GPU ray intersections model
flattening, ring/globe occultation, globe shadow on rings, and ring shadow on the
globe. Ring color/opacity remains a procedural approximation; the very faint
D/E/G and narrow F rings are not rendered as a bright extension of the main rings.
Sources: [NASA Saturn](https://nssdc.gsfc.nasa.gov/planetary/factsheet/saturnfact.html),
[NASA rings](https://nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html).

Resolved disks are 512 px. Night-side ambient fill is removed. In the sky,
daylight atmospheric scattering is composited in front of the opaque disk,
so the unlit hemisphere does not become an artificial black circle in blue sky.
Selection models use the same illumination geometry without the sky atmosphere.

Independent [JPL Horizons](https://ssd.jpl.nasa.gov/horizons/manual.html) tables
for Mercury, Venus, and Saturn are saved under `PhysicalPhases/horizons-*.txt`
in the Planetarium design-review directory. Tests cover half/crescent/gibbous
phases and Saturn's 2025 ring-plane crossing: illumination within 0.12 percentage
points, opening within 0.12°, pole angle within 0.35°, and bright-limb angle within
0.4°. Horizons planetodetic latitude is converted to planetocentric latitude for
comparison with ring opening. Separate GPU tests count illuminated pixels,
verify the A-ring extent/Cassini division, and check daylight night-side color.
Dark-mode app review uses iPhone 17 Pro Max / iOS 26.5. The interactive test's
date override changes the rendered sky independently of its pass-control clock;
the Venus screenshot uses JD 2461303.3333333, the Sun JD 2459373.3333333, and
Saturn the normal 2021-06-07 pass fixture. These are visual fixtures, not releases.
Validation completed: six distinct targeted tests passed (including the
interactive review), followed by a fresh simulator build/run. Sun, Saturn, and
Venus app screenshots were captured and reviewed in dark mode; the Venus daytime
image confirms the unlit disk blends into the foreground atmosphere.

### Century-range verification (1926–2126)

See [the measured accuracy report](DesignReview/Planetarium/CenturyAccuracy/README.md).
The planetarium now transforms the observer's equator-of-date basis back to
J2000 using IAU 2006 precession, keeping catalog, galaxy, planet poles, planetary
positions, moon ephemerides, and trajectories in one inertial frame. The observer
position is converted to J2000 before topocentric subtraction. Planet directions
and phases share the light-time-corrected geometry; the Sun uses J2000 ecliptic
coordinates. Moon theory coordinates (of date) are explicitly converted where
needed. No changes were made to the separate 2D chart's astrometry in this step.

Monthly regression checks cover seven planets across 1926-09-20–2126-09-20.
Saturn's sampled opening error is below 0.000122° and pole position-angle error
below 0.003232° versus JPL. The report documents residual approximations and
does not promise this measured accuracy outside the tested interval.
