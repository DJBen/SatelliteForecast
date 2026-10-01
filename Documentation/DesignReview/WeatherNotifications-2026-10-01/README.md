# Weather-aware automatic station notifications

Reviewed copy for all eight app languages. Times are local, durations approximate.

| Locale | Title | Subtitle | Cloudy body |
| --- | --- | --- | --- |
| en | ISS · 18:21 | Look SW · 4 min · Up to 62° | Clouds may obscure the view. |
| ru | МКС · 18:21 | Смотрите ЮЗ · 4 мин · До 62° | Облака могут помешать наблюдению. |
| fr | ISS · 18:21 | Vers SO · 4 min · Jusqu’à 62° | Les nuages pourraient gêner la vue. |
| es | EEI · 18:21 | Mira al SO · 4 min · Hasta 62° | Las nubes podrían dificultar la observación. |
| pt | EEI · 18:21 | Olhe para SO · 4 min · Até 62° | As nuvens podem dificultar a observação. |
| zh_Hans | 国际空间站 · 18:21 | 朝西南看 · 4分钟 · 最高62° | 云层可能遮挡视线。 |
| ja | ISS · 18:21 | 南西の空 · 4分 · 最大62° | 雲で見えにくい可能性があります。 |
| ko | ISS · 18:21 | 남서쪽 · 4분 · 최대 62° | 구름 때문에 잘 안 보일 수 있어요. |

Every weather body:

| Locale | Mostly clear | Mostly cloudy | Possible rain | Unknown/stale |
| --- | --- | --- | --- | --- |
| en | Mostly clear skies expected. | Mostly cloudy. Look for gaps. | Rain possible; visibility may be limited. | Check the sky before heading out. |
| ru | Ожидается преимущественно ясное небо. | Преимущественно облачно. Ищите просветы. | Возможен дождь; видимость может быть ограничена. | Перед выходом посмотрите на небо. |
| fr | Ciel généralement dégagé prévu. | Ciel très nuageux. Guettez les éclaircies. | Pluie possible ; visibilité peut-être réduite. | Vérifiez le ciel avant de sortir. |
| es | Se espera un cielo mayormente despejado. | Muy nublado. Busca claros entre las nubes. | Posible lluvia; la visibilidad podría ser limitada. | Comprueba el cielo antes de salir. |
| pt | Previsão de céu predominantemente limpo. | Muito nublado. Procure aberturas nas nuvens. | Possível chuva; a visibilidade pode ser limitada. | Confira o céu antes de sair. |
| zh_Hans | 预计天空大致晴朗。 | 云层较多，留意云间的空隙。 | 可能下雨，能见度或受影响。 | 出门前看看天空状况。 |
| ja | おおむね晴れる見込みです。 | 雲が多い見込み。雲の切れ間を探してみましょう。 | 雨の可能性があり、見えにくいかもしれません。 | 出かける前に空の様子を確認しましょう。 |
| ko | 대체로 맑은 하늘이 예상돼요. | 구름이 많아요. 구름 사이를 살펴보세요. | 비가 올 수 있어 잘 안 보일 수 있어요. | 나가기 전에 하늘을 확인해 보세요. |

Validation:

- 80 Python regression tests passed, including delivery receipts, rain suppression for both alert types, all locale/station/weather combinations, APNs subtitle serialization, pass-window boundaries, stale/missing data, and wire-response handling.
- 27 ClearSkyChart TypeScript tests passed, including the private handler validation and existing shared H3 cache/refresh-lease coverage.
- Live weather lookup under the notification runtime service account returned two future pass-hour samples. Nearby coordinates reused the same weather data and fetch timestamp. Unauthenticated access returned 403; `weather-iam.json` records the sole invoker binding.
- `notificationWeather`, `notify`, and `notify_prominent` were deployed. No test notification was sent to a real device or person.
- The app rebuilt and ran in the iPhone 17 Pro Max simulator with dark appearance. `home-dark.jpg` records the app state. Native banner preview was blocked because this simulator has not authorized notifications; the locale `.apns` fixtures and payload serialization tests verify the content, but are not screenshots of rendered banners.
