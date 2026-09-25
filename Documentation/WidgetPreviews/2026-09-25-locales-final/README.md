# Widget size and locale review

Native SwiftUI previews, dark mode, iPhone 17 Pro Max simulator. These are test
renders of the widget content, not installed Home Screen screenshots.

- Short localized numeric dates; no repeated headers.
- 912 cases, zero pixels outside the tested widget bounds.
- 40 targeted tests passed.
- All 112 contact sheets scanned for ellipsis: no remaining OCR flags; flagged cases were also visually reviewed.
- Default and XXXL text; AX5 stress tests use the widget's XXXL font ceiling.

[All evidence in a browsable gallery](gallery.html) · [Test log](tests.log) ·
[Bounds results](locale-matrix/bounds.csv) · [OCR results](locale-matrix/ocr-review.json)

| Locale | Compact | Narrow | Regular | Wide |
| --- | --- | --- | --- | --- |
| English | [Default](locale-matrix/en_US-compact-normal.png) / [XXXL](locale-matrix/en_US-compact-XXXL.png) | [Default](locale-matrix/en_US-narrow-normal.png) / [XXXL](locale-matrix/en_US-narrow-XXXL.png) | [Default](locale-matrix/en_US-regular-normal.png) / [XXXL](locale-matrix/en_US-regular-XXXL.png) | [Default](locale-matrix/en_US-wide-normal.png) / [XXXL](locale-matrix/en_US-wide-XXXL.png) |
| Spanish | [Default](locale-matrix/es_ES-compact-normal.png) / [XXXL](locale-matrix/es_ES-compact-XXXL.png) | [Default](locale-matrix/es_ES-narrow-normal.png) / [XXXL](locale-matrix/es_ES-narrow-XXXL.png) | [Default](locale-matrix/es_ES-regular-normal.png) / [XXXL](locale-matrix/es_ES-regular-XXXL.png) | [Default](locale-matrix/es_ES-wide-normal.png) / [XXXL](locale-matrix/es_ES-wide-XXXL.png) |
| French | [Default](locale-matrix/fr_FR-compact-normal.png) / [XXXL](locale-matrix/fr_FR-compact-XXXL.png) | [Default](locale-matrix/fr_FR-narrow-normal.png) / [XXXL](locale-matrix/fr_FR-narrow-XXXL.png) | [Default](locale-matrix/fr_FR-regular-normal.png) / [XXXL](locale-matrix/fr_FR-regular-XXXL.png) | [Default](locale-matrix/fr_FR-wide-normal.png) / [XXXL](locale-matrix/fr_FR-wide-XXXL.png) |
| Brazilian Portuguese | [Default](locale-matrix/pt_BR-compact-normal.png) / [XXXL](locale-matrix/pt_BR-compact-XXXL.png) | [Default](locale-matrix/pt_BR-narrow-normal.png) / [XXXL](locale-matrix/pt_BR-narrow-XXXL.png) | [Default](locale-matrix/pt_BR-regular-normal.png) / [XXXL](locale-matrix/pt_BR-regular-XXXL.png) | [Default](locale-matrix/pt_BR-wide-normal.png) / [XXXL](locale-matrix/pt_BR-wide-XXXL.png) |
| Russian | [Default](locale-matrix/ru_RU-compact-normal.png) / [XXXL](locale-matrix/ru_RU-compact-XXXL.png) | [Default](locale-matrix/ru_RU-narrow-normal.png) / [XXXL](locale-matrix/ru_RU-narrow-XXXL.png) | [Default](locale-matrix/ru_RU-regular-normal.png) / [XXXL](locale-matrix/ru_RU-regular-XXXL.png) | [Default](locale-matrix/ru_RU-wide-normal.png) / [XXXL](locale-matrix/ru_RU-wide-XXXL.png) |
| Simplified Chinese | [Default](locale-matrix/zh_Hans-compact-normal.png) / [XXXL](locale-matrix/zh_Hans-compact-XXXL.png) | [Default](locale-matrix/zh_Hans-narrow-normal.png) / [XXXL](locale-matrix/zh_Hans-narrow-XXXL.png) | [Default](locale-matrix/zh_Hans-regular-normal.png) / [XXXL](locale-matrix/zh_Hans-regular-XXXL.png) | [Default](locale-matrix/zh_Hans-wide-normal.png) / [XXXL](locale-matrix/zh_Hans-wide-XXXL.png) |
| Japanese | [Default](locale-matrix/ja_JP-compact-normal.png) / [XXXL](locale-matrix/ja_JP-compact-XXXL.png) | [Default](locale-matrix/ja_JP-narrow-normal.png) / [XXXL](locale-matrix/ja_JP-narrow-XXXL.png) | [Default](locale-matrix/ja_JP-regular-normal.png) / [XXXL](locale-matrix/ja_JP-regular-XXXL.png) | [Default](locale-matrix/ja_JP-wide-normal.png) / [XXXL](locale-matrix/ja_JP-wide-XXXL.png) |
| Korean | [Default](locale-matrix/ko_KR-compact-normal.png) / [XXXL](locale-matrix/ko_KR-compact-XXXL.png) | [Default](locale-matrix/ko_KR-narrow-normal.png) / [XXXL](locale-matrix/ko_KR-narrow-XXXL.png) | [Default](locale-matrix/ko_KR-regular-normal.png) / [XXXL](locale-matrix/ko_KR-regular-XXXL.png) | [Default](locale-matrix/ko_KR-wide-normal.png) / [XXXL](locale-matrix/ko_KR-wide-XXXL.png) |

## State reviews

- English: [ongoing](locale-matrix/en_US-states-ongoing.png), [empty](locale-matrix/en_US-states-empty.png), [setup](locale-matrix/en_US-states-setup.png), [expired](locale-matrix/en_US-states-expired.png), [legacy](locale-matrix/en_US-states-legacy.png)
- Spanish: [ongoing](locale-matrix/es_ES-states-ongoing.png), [empty](locale-matrix/es_ES-states-empty.png), [setup](locale-matrix/es_ES-states-setup.png), [expired](locale-matrix/es_ES-states-expired.png), [legacy](locale-matrix/es_ES-states-legacy.png)
- French: [ongoing](locale-matrix/fr_FR-states-ongoing.png), [empty](locale-matrix/fr_FR-states-empty.png), [setup](locale-matrix/fr_FR-states-setup.png), [expired](locale-matrix/fr_FR-states-expired.png), [legacy](locale-matrix/fr_FR-states-legacy.png)
- Brazilian Portuguese: [ongoing](locale-matrix/pt_BR-states-ongoing.png), [empty](locale-matrix/pt_BR-states-empty.png), [setup](locale-matrix/pt_BR-states-setup.png), [expired](locale-matrix/pt_BR-states-expired.png), [legacy](locale-matrix/pt_BR-states-legacy.png)
- Russian: [ongoing](locale-matrix/ru_RU-states-ongoing.png), [empty](locale-matrix/ru_RU-states-empty.png), [setup](locale-matrix/ru_RU-states-setup.png), [expired](locale-matrix/ru_RU-states-expired.png), [legacy](locale-matrix/ru_RU-states-legacy.png)
- Simplified Chinese: [ongoing](locale-matrix/zh_Hans-states-ongoing.png), [empty](locale-matrix/zh_Hans-states-empty.png), [setup](locale-matrix/zh_Hans-states-setup.png), [expired](locale-matrix/zh_Hans-states-expired.png), [legacy](locale-matrix/zh_Hans-states-legacy.png)
- Japanese: [ongoing](locale-matrix/ja_JP-states-ongoing.png), [empty](locale-matrix/ja_JP-states-empty.png), [setup](locale-matrix/ja_JP-states-setup.png), [expired](locale-matrix/ja_JP-states-expired.png), [legacy](locale-matrix/ja_JP-states-legacy.png)
- Korean: [ongoing](locale-matrix/ko_KR-states-ongoing.png), [empty](locale-matrix/ko_KR-states-empty.png), [setup](locale-matrix/ko_KR-states-setup.png), [expired](locale-matrix/ko_KR-states-expired.png), [legacy](locale-matrix/ko_KR-states-legacy.png)
