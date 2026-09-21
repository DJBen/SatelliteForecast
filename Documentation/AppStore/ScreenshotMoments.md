# Reusable screenshot moments

These are reviewed historical fixtures from release 1.7.1, not live forecasts. Reuse the **saved TLEs, observer coordinates, dates, and time zones together**. Replacing the TLEs changes the orbit, flags, pass timing, and visibility; regenerate and review if any input changes.

Source of truth: [`1.7.1/screenshots/selection-*.json`](1.7.1/screenshots/). Selection and rendering live in `ScreenSnapshotTests.testAppStoreScreenshots` and `Fixture.storeScreens` in [`ScreenSnapshotTests.swift`](../../SatelliteForecastTests/ScreenSnapshotTests.swift).

## Home screen moments

Home time is independent of the pass-screen time. Each position was checked against the app’s offline geographic lookup to confirm the intended country and land flag. Tiangong is first for Chinese locales; ISS is first for all others.

| Locale | Station | Verified place | Home instant (UTC) |
| --- | --- | --- | --- |
| en-US | ISS | California, US | 2026-09-10 10:11:15 |
| fr-FR | ISS | France | 2026-09-12 19:12:45 |
| es-ES | ISS | Spain | 2026-09-11 01:39:00 |
| pt-BR | ISS | São Paulo, Brazil | 2026-09-10 08:59:15 |
| ru | ISS | Volgograd Oblast, Russia | 2026-09-10 17:41:15 |
| ja | ISS | Japan | 2026-09-10 09:51:00 |
| ko | ISS | South Korea | 2026-09-11 17:09:45 |
| zh-Hans | Tiangong | Anhui, China | 2026-09-12 11:52:30 |

## Pass-screen moments

The UTC and local times below are **pass rise/start**, not the “best view” time displayed in the list. The list displays the highest illuminated point, rounded/formatted to minute precision. Set the list’s reference time to **one hour before rise** (`passForecastDateUTC` in the JSON) so this strong pass is the first upcoming visible row. The detail chart and list must describe the same pass.

| Locale | Rise (UTC) | Rise (local) | Peak illuminated elevation | Observer latitude, longitude | Time zone |
| --- | --- | --- | --- | --- | --- |
| en-US | 2026-09-10 03:34:57 | 2026-09-09 20:34:57 | 55.6° | 37.486743, -122.226560 | America/Los_Angeles |
| fr-FR | 2026-09-12 19:07:21 | 2026-09-12 21:07:21 | 70.8° | 45.764000, 4.835700 | Europe/Paris |
| es-ES | 2026-09-09 19:50:57 | 2026-09-09 21:50:57 | 83.0° | 40.416800, -3.703800 | Europe/Madrid |
| pt-BR | 2026-09-14 07:20:36 | 2026-09-14 04:20:36 | 45.9° | -23.550500, -46.633300 | America/Sao_Paulo |
| ru | 2026-09-13 16:49:51 | 2026-09-13 19:49:51 | 74.1° | 48.708000, 44.513300 | Europe/Volgograd |
| ja | 2026-09-10 09:45:36 | 2026-09-10 18:45:36 | 60.3° | 35.676200, 139.650300 | Asia/Tokyo |
| ko | 2026-09-08 11:18:48 | 2026-09-08 20:18:48 | 86.5° | 37.566500, 126.978000 | Asia/Seoul |
| zh-Hans | 2026-09-13 10:48:51 | 2026-09-13 18:48:51 | 57.4° | 31.230400, 121.473700 | Asia/Shanghai |

## Why these choices work

- Select **highest illuminated elevation**, not geometric culmination alone. A high pass in Earth’s shadow is not an impressive visible pass.
- Require a visible pass with Sun elevation at transit below −10° for stars and the Milky Way. In 1.7.0 an 84° ISS candidate was rejected because twilight hid the stars; the 56° dark-sky pass looked better.
- Prefer above 55° when available; the fixture asserts above 45°. Brazil’s 46° predawn pass is useful because the station emerges from shadow. Japan’s 60° scene also includes the Moon. Korea’s 86° pass is nearly overhead.
- For home geography, scan real propagated positions near the locale’s observing site, then verify the resulting country code. An orbit point close to Shanghai in the selected interval resolves to **Anhui**, so document the actual region rather than claiming Shanghai overhead.
- Longitude normalization matters: satellite coordinates may use 0…360°. Use the shortest longitude delta `((satelliteLongitude - targetLongitude + 540) % 360) - 180` when ranking candidates. Omitting this caused the initial U.S. search to miss California.
- The current home search samples three days from `2026-09-10T01:00:00Z` every 45 seconds. The pass search checks seven-day windows starting at offsets 0, −7, and +7 days, stopping when it finds a suitable pass above 55°. A home timestamp may fall after the best pass; keep their clocks independent.
- Populate both ISS and Tiangong ephemerides in the screenshot forecast client. Otherwise the secondary station incorrectly shows “Location unavailable” in the fixture.

## Orbital inputs

Saved September 13, 2026 TLEs (ISS NORAD 25544; Tiangong NORAD 48274). Displayed name lines omit trailing padding; hashes refer to the original fixture files:

### iss.tle

Source: [`iss.tle`](../../SatelliteForecastTests/Fixtures/AppStore/iss.tle). SHA-256: `661c139623b7fe1824e8886a6cafe450ba2a9bec076977813785cd3834e9a883`.

```text
ISS (ZARYA)
1 25544U 98067A   26256.62713074  .00005522  00000+0  10793-3 0  9997
2 25544  51.6309 222.3825 0004920 137.6518 222.4851 15.49103177585466
```

### tiangong.tle

Source: [`tiangong.tle`](../../SatelliteForecastTests/Fixtures/AppStore/tiangong.tle). SHA-256: `b4f2399969bee7066b5c380a19822fb8fdbe0970842002fa37d292b77839f5fa`.

```text
CSS (TIANHE)
1 48274U 21035A   26256.94440729  .00019023  00000+0  23303-3 0  9994
2 48274  41.4678 143.1320 0002658 276.9556  83.0980 15.59905071307024
```

## Earlier useful scene

Release 1.7.0 used the San Francisco Bay observer `(37.486743, -122.226560)` and the same TLEs, with a reference time of `2026-09-10T01:00:00Z`. The ISS scene rose around September 9 at 20:34 America/Los_Angeles, reaching 56°. Tiangong’s September 10 scene around 20:27 reached 87°. See the [1.7.0 release notes](1.7.0/README.md) and its reviewed captures before reusing; those rounded times are a selection hint, not exact rise timestamps.

## 1.8.0 fifth slot: planetarium

`05-planetarium` uses the same locale observer, time zone, pinned station TLE, and reviewed featured pass as the pass-chart slot. It opens the actual Metal planetarium in Preview at the pass midpoint, with constellation labels/lines enabled and Follow Device off (deterministic simulator). The camera uses 100° field of view, culmination azimuth, and elevation `max(25°, culmination elevation − 30°)` to include more of the sky and horizon while retaining the station. No synthetic sky or composited UI is used.

Capture to `Documentation/AppStore/1.8.0/screenshots`, inspect each full-size dark-mode image, and append it to the inherited four images. The saved `selection-<locale>.json` records reproduce the existing reviewed pass inputs.

### Build 8 refresh

The pass-chart and planetarium captures were regenerated in all eight locales into `1.8.0/build-8/screenshots/`. Each new selection JSON exactly matches the previous reviewed locale fixture: observer, time zone, featured pass, and pinned TLE inputs are unchanged. Dark native iPhone 17 Pro Max captures show the adaptive Chart/Planetarium buttons, New York celestial labels, bright-star names, and fading peripheral constellation labels. The other three screenshot slots remain unchanged. Review contact sheets are aids only; upload the native 1320 × 2868 PNGs.
