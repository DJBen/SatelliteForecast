#!/usr/bin/env python3
# Copyright 2025
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from datetime import datetime, timedelta, timezone
import math


# Complete localized sentences keep the same calm tone in every supported language.
LOCALIZATIONS = {'en': {'directions': ['north',
                       'north-northeast',
                       'northeast',
                       'east-northeast',
                       'east',
                       'east-southeast',
                       'southeast',
                       'south-southeast',
                       'south',
                       'south-southwest',
                       'southwest',
                       'west-southwest',
                       'west',
                       'west-northwest',
                       'northwest',
                       'north-northwest'],
        'satellite_full_names': {'25544': 'International Space Station', '48274': 'Tiangong Space Station'},
        'satellite_short_names': {'25544': 'ISS', '48274': 'Tiangong'},
        'upcoming_title': '{satellite_name} passes by soon',
        'prominent_title': 'A chance to spot {satellite_name}',
        'viewing_details': 'Look {rise_dir} around {rise_time}. It reaches {elevation}° above the horizon, '
                           'with about {duration} to watch if skies are clear.',
        'no_visible_transit': 'No visible pass is expected.',
        'transit_incomplete': 'Viewing details are unavailable for this pass.',
        'duration_minutes': '{minutes} min',
        'duration_seconds': '{seconds} sec'},
 'ru': {'directions': ['С',
                       'ССВ',
                       'СВ',
                       'ВСВ',
                       'В',
                       'ВЮВ',
                       'ЮВ',
                       'ЮЮВ',
                       'Ю',
                       'ЮЮЗ',
                       'ЮЗ',
                       'ЗЮЗ',
                       'З',
                       'ЗСЗ',
                       'СЗ',
                       'ССЗ'],
        'satellite_full_names': {'25544': 'Международная космическая станция',
                                 '48274': 'Космическая станция Тяньгун'},
        'satellite_short_names': {'25544': 'МКС', '48274': 'Тяньгун'},
        'upcoming_title': 'Скоро пролетит {satellite_name}',
        'prominent_title': 'Возможность увидеть: {satellite_name}',
        'viewing_details': 'Смотрите в направлении {rise_dir} около {rise_time}. Высота — до {elevation}° '
                           'над горизонтом. При ясном небе на наблюдение будет около {duration}.',
        'no_visible_transit': 'Видимый пролёт не ожидается.',
        'transit_incomplete': 'Подробности наблюдения этого пролёта недоступны.',
        'duration_minutes': '{minutes} мин',
        'duration_seconds': '{seconds} с'},
 'fr': {'directions': ['N',
                       'NNE',
                       'NE',
                       'ENE',
                       'E',
                       'ESE',
                       'SE',
                       'SSE',
                       'S',
                       'SSO',
                       'SO',
                       'OSO',
                       'O',
                       'ONO',
                       'NO',
                       'NNO'],
        'satellite_full_names': {'25544': 'Station Spatiale Internationale',
                                 '48274': 'Station Spatiale Tiangong'},
        'satellite_short_names': {'25544': 'ISS', '48274': 'Tiangong'},
        'upcoming_title': '{satellite_name} passe bientôt',
        'prominent_title': 'Une occasion de voir {satellite_name}',
        'viewing_details': 'Regardez vers {rise_dir} vers {rise_time}. Le passage atteint {elevation}° '
                           'au-dessus de l’horizon, avec environ {duration} d’observation si le ciel est '
                           'dégagé.',
        'no_visible_transit': 'Aucun passage visible n’est prévu.',
        'transit_incomplete': 'Les détails d’observation de ce passage sont indisponibles.',
        'duration_minutes': '{minutes} min',
        'duration_seconds': '{seconds} s'},
 'es': {'directions': ['N',
                       'NNE',
                       'NE',
                       'ENE',
                       'E',
                       'ESE',
                       'SE',
                       'SSE',
                       'S',
                       'SSO',
                       'SO',
                       'OSO',
                       'O',
                       'ONO',
                       'NO',
                       'NNO'],
        'satellite_full_names': {'25544': 'Estación Espacial Internacional',
                                 '48274': 'Estación Espacial Tiangong'},
        'satellite_short_names': {'25544': 'EEI', '48274': 'Tiangong'},
        'upcoming_title': '{satellite_name} pasará pronto',
        'prominent_title': 'Una oportunidad de ver {satellite_name}',
        'viewing_details': 'Mira hacia {rise_dir} sobre las {rise_time}. Alcanzará {elevation}° sobre el '
                           'horizonte, con unos {duration} para observar si el cielo está despejado.',
        'no_visible_transit': 'No se espera un paso visible.',
        'transit_incomplete': 'Los detalles de observación de este paso no están disponibles.',
        'duration_minutes': '{minutes} min',
        'duration_seconds': '{seconds} s'},
 'pt': {'directions': ['N',
                       'NNE',
                       'NE',
                       'ENE',
                       'E',
                       'ESE',
                       'SE',
                       'SSE',
                       'S',
                       'SSO',
                       'SO',
                       'OSO',
                       'O',
                       'ONO',
                       'NO',
                       'NNO'],
        'satellite_full_names': {'25544': 'Estação Espacial Internacional',
                                 '48274': 'Estação Espacial Tiangong'},
        'satellite_short_names': {'25544': 'EEI', '48274': 'Tiangong'},
        'upcoming_title': '{satellite_name} passa em breve',
        'prominent_title': 'Uma chance de ver {satellite_name}',
        'viewing_details': 'Olhe na direção {rise_dir} por volta das {rise_time}. A passagem chega a '
                           '{elevation}° acima do horizonte, com cerca de {duration} para observar se o céu '
                           'estiver limpo.',
        'no_visible_transit': 'Nenhuma passagem visível está prevista.',
        'transit_incomplete': 'Os detalhes de observação desta passagem estão indisponíveis.',
        'duration_minutes': '{minutes} min',
        'duration_seconds': '{seconds} s'},
 'zh_Hans': {'directions': ['北',
                            '北东北',
                            '东北',
                            '东北东',
                            '东',
                            '东南东',
                            '东南',
                            '南东南',
                            '南',
                            '南西南',
                            '西南',
                            '西南西',
                            '西',
                            '西北西',
                            '西北',
                            '北西北'],
             'satellite_full_names': {'25544': '国际空间站', '48274': '天宫空间站'},
             'satellite_short_names': {'25544': '国际空间站', '48274': '天宫'},
             'upcoming_title': '{satellite_name}即将经过',
             'prominent_title': '抬头找找{satellite_name}',
             'viewing_details': '{rise_time}左右，朝{rise_dir}看。最高可达地平线上方{elevation}°；天气晴朗时，约有{duration}可以观赏。',
             'no_visible_transit': '预计没有可见的过境。',
             'transit_incomplete': '暂时无法获取这次过境的观测详情。',
             'duration_minutes': '{minutes}分钟',
             'duration_seconds': '{seconds}秒'},
 'ja': {'directions': ['北',
                       '北北東',
                       '北東',
                       '東北東',
                       '東',
                       '東南東',
                       '南東',
                       '南南東',
                       '南',
                       '南南西',
                       '南西',
                       '西南西',
                       '西',
                       '西北西',
                       '北西',
                       '北北西'],
        'satellite_full_names': {'25544': '国際宇宙ステーション', '48274': '天宮宇宙ステーション'},
        'satellite_short_names': {'25544': 'ISS', '48274': '天宮'},
        'upcoming_title': '{satellite_name}がまもなく通過',
        'prominent_title': '{satellite_name}を探してみませんか',
        'viewing_details': '{rise_time}ごろ、{rise_dir}の空を見てみましょう。地平線から最大{elevation}°まで昇り、晴れていれば約{duration}観察できます。',
        'no_visible_transit': '見える通過は予測されていません。',
        'transit_incomplete': 'この通過の観察情報は現在利用できません。',
        'duration_minutes': '{minutes}分',
        'duration_seconds': '{seconds}秒'},
 'ko': {'directions': ['북',
                       '북북동',
                       '북동',
                       '동북동',
                       '동',
                       '동남동',
                       '남동',
                       '남남동',
                       '남',
                       '남남서',
                       '남서',
                       '서남서',
                       '서',
                       '서북서',
                       '북서',
                       '북북서'],
        'satellite_full_names': {'25544': '국제우주정거장', '48274': '톈궁 우주정거장'},
        'satellite_short_names': {'25544': 'ISS', '48274': '톈궁'},
        'upcoming_title': '{satellite_name}이 곧 지나가요',
        'prominent_title': '{satellite_name}을 찾아보세요',
        'viewing_details': '{rise_time}쯤 {rise_dir}쪽 하늘을 보세요. 지평선 위 최대 {elevation}°까지 올라가며, 하늘이 맑으면 약 '
                           '{duration} 동안 관찰할 수 있어요.',
        'no_visible_transit': '관측 가능한 통과가 예상되지 않아요.',
        'transit_incomplete': '이번 통과의 관측 정보를 확인할 수 없어요.',
        'duration_minutes': '{minutes}분',
        'duration_seconds': '{seconds}초'}}


def _get_locale_code(locale):
    normalized = (locale or "en").replace("-", "_").lower()
    if normalized in ("zh", "zh_cn", "zh_sg") or normalized.startswith("zh_hans"):
        return "zh_Hans"
    base = normalized.split("_")[0]
    return base if base in LOCALIZATIONS else "en"


def _get_direction_from_azimuth(azimuth, locale="en"):
    directions = LOCALIZATIONS[_get_locale_code(locale)]["directions"]
    return directions[int((azimuth / 22.5) + 0.5) % 16]


def localized_satellite_name(key, locale="en", use_short_name=False):
    texts = LOCALIZATIONS[_get_locale_code(locale)]
    names = texts["satellite_short_names" if use_short_name else "satellite_full_names"]
    return names.get(str(key), str(key))


def get_localized_satellite_title(sat_id, locale="en", is_rising=False):
    """Keep the handler API; regular pushes arrive five minutes before culmination.

    The legacy is_rising flag selects the upcoming alert, not an actual rise event.
    Avoid relative day names: queued passes can cross midnight or occur in daylight.
    """
    texts = LOCALIZATIONS[_get_locale_code(locale)]
    template = texts["upcoming_title" if is_rising else "prominent_title"]
    return template.format(satellite_name=localized_satellite_name(sat_id, locale, use_short_name=True))


def _utc_time(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _duration(seconds, texts):
    minutes, seconds = divmod(max(1, int(round(seconds))), 60)
    parts = []
    if minutes:
        parts.append(texts["duration_minutes"].format(minutes=minutes))
    if seconds:
        parts.append(texts["duration_seconds"].format(seconds=seconds))
    return " ".join(parts)


def describe_transit(transit_info, offset_from_utc, locale="en") -> str:
    """Viewing guidance using the predicted illuminated window above 10°.

    offset_from_utc is in seconds, as stored in the scheduled task payload.
    The highest illuminated elevation need not occur at geometric culmination,
    so do not pair that elevation with culmination's time or direction.
    """
    texts = LOCALIZATIONS[_get_locale_code(locale)]
    if not transit_info:
        return texts["no_visible_transit"]
    try:
        duration = float(transit_info.get("visible_above_10_deg_duration_sec", 0))
        if not math.isfinite(duration):
            return texts["transit_incomplete"]
        if duration <= 0:
            return texts["no_visible_transit"]
        start = transit_info["elev10_rise"]
        start_time = _utc_time(start["time"])
        # A satellite still in shadow at 10° is not yet a useful viewing target.
        leaves_shadow = transit_info.get("leaves_shadow")
        if leaves_shadow and _utc_time(leaves_shadow["time"]) > start_time:
            start = leaves_shadow
            start_time = _utc_time(start["time"])
        azimuth = float(start["obs"]["azimuth"])
        elevation = float(transit_info["visible_culmination_elev"])
        if not math.isfinite(azimuth) or not math.isfinite(elevation) or not 0 <= elevation <= 90:
            return texts["transit_incomplete"]
        local_start = start_time + timedelta(seconds=offset_from_utc)
        return texts["viewing_details"].format(
            rise_dir=_get_direction_from_azimuth(azimuth, locale),
            rise_time=local_start.strftime("%H:%M"),
            elevation=int(round(elevation)),
            duration=_duration(duration, texts),
        )
    except (KeyError, TypeError, ValueError, AttributeError, OverflowError):
        return texts["transit_incomplete"]


def describe_prominent_transit(sat_id, transit_info, offset_from_utc, locale="en") -> str:
    """The prominent title supplies the name; the body prioritizes viewing details."""
    return describe_transit(transit_info, offset_from_utc, locale)
