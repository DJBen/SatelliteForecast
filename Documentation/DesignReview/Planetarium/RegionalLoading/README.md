# Visible-region star loading

The planetarium reuses the app's magnitude-6.5 all-sky snapshot for its base layer. The previous first-zoom load of an entire magnitude-9 snapshot has been removed. Additional stars (6.5 < magnitude <= 7.5 or 9, depending on zoom) come from indexed H3 cell queries, using the existing StarryNight database API.

## Coverage algorithm

1. Transform the camera's forward/right/up basis to the catalog's J2000 frame, including the existing precession transform.
2. Construct the four inward-facing unit normals of the perspective frustum. Expand each half-angle by two degrees for small movements and edge prefetching.
3. Enumerate H3 resolution 0–2 cell **geometry**, not star records, on the catalog actor. Bound each cell by a spherical cap centered on its H3 center, with radius equal to the maximum angle to its boundary vertices plus a numerical tolerance. H3's face-crossing vertices are included, as are pentagons. All caps are smaller than a hemisphere, so their great-circle edges and interiors are contained by the cap.
4. A cell is rejected only when its entire cap is outside a frustum plane: `dot(planeNormal, cellCenter) < -sin(cellRadius)`. This is conservative: some edge/corner neighbors load, but intersecting cells cannot be excluded. It uses 3D vectors, with no longitude wrapping, pole splitting, or center-only polygon fill.
5. Reuse a request only when all four new viewport corners remain inside its padded frustum and its magnitude tier is unchanged. Convexity makes this sufficient to contain the whole new viewport, including camera roll, aspect changes, and zoom.

All three database resolutions are considered rather than assuming fixed magnitude boundaries between H3 tables. Requests are ordered by resolution (the catalog's brightness tiers), then by distance from the viewing direction. Every query includes the current magnitude cutoff, and returned base-layer stars are excluded to prevent duplicate draws.

## Scheduling and retention

SQLite access, cell-geometry construction, filtering, and CPU cache maintenance run on a dedicated actor. The controller requests batches of eight cells and progressively publishes results, with task cancellation plus a generation check before applying each batch. Superseded requests cannot replace the latest camera's cells. Returning to the base tier removes deep stars; stopping the view cancels pending work. Labels and hit testing use the active rendered catalog.

The CPU LRU is bounded by both 512 cells and 20,000 additional stars; empty cells are cached too. GPU buffers are keyed by H3 cell and magnitude, reused across camera movement, and evicted from inactive history above 256 entries or 4 MiB. Active buffers are pinned; Metal retains buffers needed by in-flight frames after cache eviction. StarryNight also retains its own bounded point-lookup cache (4,096 stars).

The small H3 geometry index is retained independently from star data. Base-layer buffers and the shared magnitude-6.5 snapshot remain available, so brighter sky content does not wait for deep-region queries.

## Verification

Tests compare regional query results against an independently projected full-sky catalog (loaded only in tests), across both poles, longitude seams, camera roll, portrait/landscape aspect ratios, both deep magnitude tiers, and sub-cell telescope fields of view. They also exercise cancellation, CPU/GPU eviction, duplicate prevention, final-camera generation checks, viewport containment reuse, and exact GPU pixel equivalence between flat and regional star buffers.

This change reduces the amount of deep-star data loaded and retained, and removes all-sky partitioning from the main actor. Steady-state FPS also depends on atmosphere, water, labels, and other rendering work; no device FPS improvement is assumed from star counts alone.

### Results — 2026-09-20

- iPhone 17 Pro Max / iOS 26.5 simulator: build/run succeeded and all 10 targeted tests passed.
- Unsigned iOS device build also succeeded.
- Example 24° portrait viewport: 918 additional stars loaded, all 395 in-frustum stars present, versus 74,559 additional stars in the previous all-sky magnitude-9 load (98.8% fewer additional stars).
- Across the eight recorded viewports, 210–3,119 additional stars loaded. Counts include conservative cell overlap and the two-degree prefetch margin. See `query-counts.json` for each view's counts.
- GPU regression confirms exact pixel equality between a flat star buffer and regional buffers, reuse without repeated uploads, and eviction without dropping active content.
- Dark-mode hosted simulator review at 24° FOV: deep sky, labels and overlays rendered correctly; FPS readout showed 60 after settling. This is a simulator observation, not a before/after physical-device benchmark. See `regional-sky-fps-dark.jpg`.
