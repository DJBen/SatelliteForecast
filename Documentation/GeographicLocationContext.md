# Home-screen geographic context

Each station card shows one compact line beneath its title: a country flag and
“Over Japan” (or “Over California, US” for supported large countries), or a water
icon and an ocean name. When a coast is within 500 km,
the ocean line may add “near Japan”. Distance and direction remain available in
the lookup's detailed summary, but are not shown on home. ISO alpha-2 codes from
Natural Earth produce country/territory flag emoji; missing codes use a globe.
Labels support all eight app languages. The original always-visible Mission
Control Apple Map is restored on the pass list.

The label uses AppTheme colors and a single truncated line with a complete
VoiceOver description. Current satellite elements come from the existing
ForecastService/cache independently of observer permission, renew hourly, and
geographic labels update every ten seconds while the view is active. Failures
show a neutral unavailable label, never an invented flag.

## Source research

| Source | Strengths | Fit for this feature |
| --- | --- | --- |
| [Natural Earth](https://www.naturalearthdata.com/downloads/) | Offline countries, islands, marine regions; multilingual names; public domain | Selected: modest bundled data, no credentials or request limits |
| [GeoNames](https://www.geonames.org/export/web-services.html) | Global gazetteer, alternate names, ocean reverse lookup | Useful future richer place names; attribution and hosted service limits apply |
| [Apple CLGeocoder](https://developer.apple.com/documentation/corelocation/clgeocoder) | Preferred locale, native integration | Network/rate limits unsuitable for frequent satellite movement; no deterministic nearest-coast context |
| [OSM Nominatim](https://nominatim.org/release-docs/develop/api/Reverse/) | Detailed inhabited places, language preferences | Returns nearest suitable OSM object; not a global ocean-region solution |
| [Who's On First](https://whosonfirst.org/docs/properties/wof/) | Place hierarchy and language metadata | Richer administrative hierarchy, more data and source-specific license work |
| [NGA GNS](https://geonames.nga.mil/geonames/GNSHome/index.html) | Standardized foreign geographic names | Useful specialist gazetteer, less appropriate for a compact worldwide consumer summary |

## Bundled data and regeneration

Run `python3 scripts/generate-geography.py`. The generator pins Natural Earth
v5.1.2 and extracts translated names, ISO codes and polygon geometry from
`ne_10m_admin_0_countries` and `ne_10m_geography_marine_polys`. Output is about
11 MB, processed as a Swift package resource. Made with Natural Earth;
[data is public domain](https://www.naturalearthdata.com/about/terms-of-use/).
Place names are stored once per stable Natural Earth feature ID, separately
from polygon geometry. All 552 named features have English, French, Spanish,
Portuguese, Japanese, Korean and Simplified Chinese names; 548 have Russian
names. Four missing Russian names fall back to English.

Country containment takes priority over marine labels. Smaller marine polygons
win when regions overlap. Over water, spherical distance to the nearest sampled
country/territory boundary provides an approximate distance (rounded to 10 km)
and compass direction. This is proximity to a boundary, not a capital or country
centroid. No network requests are made. Loading and lookup run on an actor, with
results refreshed every ten seconds and cancelled when the row disappears.

Natural Earth coastlines and physical-region boundaries are generalized. Tiny
islands, lakes, disputed boundaries and coastal points can be approximate;
marine labels are geographic context, not authoritative sea boundaries. A
missing marine polygon falls back to proximity without inventing an ocean name.
Do not use this feature for navigation. Missing resources or failed propagation
show an unavailable state. Country and territory
labels follow the upstream dataset's conventions.


## Localization strategy and implementation

1. **Keep geometry independent of language.** The actor returns place records,
   raw approximate distance and bearing. It does not create sentences or detect
   state by parsing English prefixes. Flags use ISO codes, never translated names.
2. **Resolve language at presentation time.** The caption reads SwiftUI's locale,
   so a locale change immediately updates the cached result and its VoiceOver
   label. Supported app localizations are en, fr, es, pt-BR, ru, ja, ko and zh-Hans.
   Regional French/Spanish/etc. variants use their base translation; Portuguese
   variants use the app's Brazilian Portuguese. Simplified Chinese includes
   zh-CN/zh-SG. Unsupported languages and Traditional Chinese fall back to English.
3. **Use offline translated names with a deterministic fallback.** Names come
   from the pinned Natural Earth name fields. Brazilian Portuguese uses upstream
   Portuguese names. A missing translation uses that feature's English name;
   country names are not substituted from another gazetteer, which could change
   territory identity. Missing flag codes use the existing globe symbol.
4. **Translate whole phrases.** The existing Localizable.strings tables contain
   geography.* keys for above, near, water-near-country, unavailable, coast,
   distance, land detail and eight compass directions. Positional placeholders
   let translators reorder arguments. Neutral label syntax in French, Russian
   and other inflecting languages allows standalone gazetteer names without
   guessing articles or case endings. Translator comments explain every argument.
   Missing template translations fall back to the English table.
5. **Preserve the compact design.** Only the name and optional country proximity
   appear on home. The visual line may truncate; VoiceOver gets the complete
   localized sentence. The optional detail formatter retains distance and
   direction, with locale-aware numeric grouping, without exposing them on home.
6. **Validate both content and layout.** Tests cover all eight Japan labels,
   Japanese nearby-country ordering, Chinese ocean names, country flag stability,
   regional locale aliases, unsupported-language and missing-name fallbacks,
   unlocated-water proximity, and localized detailed directions. Native light/dark
   gallery snapshots render the actual caption in all eight languages, including
   water, land and unavailable states. Existing geometry tests stay in place.

When adding a language: add its name-field mapping to the generator, a full set
of geography.* templates to its .lproj table, a resolver mapping, and matching
content/gallery tests. Regenerate the dataset and inspect coverage and layout.
Translations here are implemented and tested, but have not had independent
native-speaker editorial review.


## Large-country subdivisions and short country names

The separate `subdivisions.json` resource contains 374 first-level regions from
[Natural Earth Admin 1 states/provinces](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/),
pinned to the same v5.1.2 release. Initial coverage is US, Canada, Mexico, Brazil,
Argentina, Russia, China, India, Australia, Indonesia, Kazakhstan and Saudi Arabia.
This explicit product selection is configurable in the generator; it is not an
assertion that other countries are small. The extra geometry is about 9 MB and
loads only when a land location falls in one of the configured countries.

A country containment check runs first. Only subdivisions belonging to that
same ISO country can match. A successful match displays the translated
state/province/region plus its parent country; no match or unavailable subdivision
data falls back to the country. The parent country's flag is preserved. State
boundaries do not participate in offshore distance calculations: those continue
to use the original country boundaries.

Country names use localized familiar forms keyed by ISO code, not text matching:
English US/UAE/UK, French USA/ÉAU/Royaume-Uni, Spanish EE. UU./EAU/Reino Unido,
Portuguese EUA/EAU/Reino Unido, Russian США/ОАЭ/Великобритания, Japanese
アメリカ/UAE/イギリス, Korean 미국/UAE/영국, and Chinese 美国/阿联酋/英国.
These forms apply consistently to land, proximity and detailed descriptions.
Subdivision names remain unabbreviated; positional templates place country first
in Japanese, Korean and Chinese. Subdivision translations use the same
locale-to-name-field mapping and English fallback as the country dataset.
