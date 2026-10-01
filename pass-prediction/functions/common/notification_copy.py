"""Compact automatic station-alert copy. Manual local alarms keep their own copy."""
from datetime import timedelta
from common.description import LOCALIZATIONS, _get_locale_code, _duration, localized_satellite_name
from common.notification_weather import visible_window


COPY = {
    'en': {'subtitle': 'Look {direction} · {duration} · Up to {elevation}°',
           'clear': 'Mostly clear skies expected.',
           'cloudy': 'Clouds may obscure the view.',
           'mostly_cloudy': 'Mostly cloudy. Look for gaps.',
           'possible_rain': 'Rain possible; visibility may be limited.',
           'unknown': 'Check the sky before heading out.'},
    'ru': {'subtitle': 'Смотрите {direction} · {duration} · До {elevation}°',
           'clear': 'Ожидается преимущественно ясное небо.',
           'cloudy': 'Облака могут помешать наблюдению.',
           'mostly_cloudy': 'Преимущественно облачно. Ищите просветы.',
           'possible_rain': 'Возможен дождь; видимость может быть ограничена.',
           'unknown': 'Перед выходом посмотрите на небо.'},
    'fr': {'subtitle': 'Vers {direction} · {duration} · Jusqu’à {elevation}°',
           'clear': 'Ciel généralement dégagé prévu.',
           'cloudy': 'Les nuages pourraient gêner la vue.',
           'mostly_cloudy': 'Ciel très nuageux. Guettez les éclaircies.',
           'possible_rain': 'Pluie possible ; visibilité peut-être réduite.',
           'unknown': 'Vérifiez le ciel avant de sortir.'},
    'es': {'subtitle': 'Mira al {direction} · {duration} · Hasta {elevation}°',
           'clear': 'Se espera un cielo mayormente despejado.',
           'cloudy': 'Las nubes podrían dificultar la observación.',
           'mostly_cloudy': 'Muy nublado. Busca claros entre las nubes.',
           'possible_rain': 'Posible lluvia; la visibilidad podría ser limitada.',
           'unknown': 'Comprueba el cielo antes de salir.'},
    'pt': {'subtitle': 'Olhe para {direction} · {duration} · Até {elevation}°',
           'clear': 'Previsão de céu predominantemente limpo.',
           'cloudy': 'As nuvens podem dificultar a observação.',
           'mostly_cloudy': 'Muito nublado. Procure aberturas nas nuvens.',
           'possible_rain': 'Possível chuva; a visibilidade pode ser limitada.',
           'unknown': 'Confira o céu antes de sair.'},
    'zh_Hans': {'subtitle': '朝{direction}看 · {duration} · 最高{elevation}°',
                'clear': '预计天空大致晴朗。',
                'cloudy': '云层可能遮挡视线。',
                'mostly_cloudy': '云层较多，留意云间的空隙。',
                'possible_rain': '可能下雨，能见度或受影响。',
                'unknown': '出门前看看天空状况。'},
    'ja': {'subtitle': '{direction}の空 · {duration} · 最大{elevation}°',
           'clear': 'おおむね晴れる見込みです。',
           'cloudy': '雲で見えにくい可能性があります。',
           'mostly_cloudy': '雲が多い見込み。雲の切れ間を探してみましょう。',
           'possible_rain': '雨の可能性があり、見えにくいかもしれません。',
           'unknown': '出かける前に空の様子を確認しましょう。'},
    'ko': {'subtitle': '{direction}쪽 · {duration} · 최대 {elevation}°',
           'clear': '대체로 맑은 하늘이 예상돼요.',
           'cloudy': '구름 때문에 잘 안 보일 수 있어요.',
           'mostly_cloudy': '구름이 많아요. 구름 사이를 살펴보세요.',
           'possible_rain': '비가 올 수 있어 잘 안 보일 수 있어요.',
           'unknown': '나가기 전에 하늘을 확인해 보세요.'},
}
EN_DIRECTIONS = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW']


def notification_content(sat_id, transit, offset_from_utc, locale='en', weather='unknown'):
    code = _get_locale_code(locale)
    texts, copy = LOCALIZATIONS[code], COPY[code]
    name = localized_satellite_name(sat_id, locale, use_short_name=True)
    body = copy.get(weather, copy['unknown'])
    window = visible_window(transit)
    if window is None:
        return name, texts['transit_incomplete'], body
    start, end, azimuth, elevation = window
    local_start = start + timedelta(seconds=offset_from_utc)
    # Keep the app's existing 24-hour local-time convention. A single rounded
    # duration unit leaves room for direction and elevation in the subtitle.
    seconds = (end - start).total_seconds()
    duration = _duration(max(60, int(seconds / 60 + 0.5) * 60) if seconds >= 60 else seconds, texts)
    directions = EN_DIRECTIONS if code == 'en' else texts['directions']
    direction = directions[int(azimuth / 22.5 + 0.5) % 16]
    title = f'{name} · {local_start:%H:%M}'
    subtitle = copy['subtitle'].format(direction=direction, duration=duration, elevation=int(round(elevation)))
    return title, subtitle, body
