"""Station Live Activity wire protocol. All schedule times are Unix seconds."""
import math

APPLE_EPOCH = 978307200


def validate_schedule(value, now):
    if not isinstance(value, dict):
        raise ValueError('schedule')
    def number(x):
        if isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x):
            raise ValueError('time')
        return float(x)
    rise, end = number(value['rise']), number(value['set'])
    if not now - 1800 <= rise <= now + 86400 or not rise < end <= rise + 1800 or end <= now:
        raise ValueError('window')
    intervals = value['illuminated']
    if not isinstance(intervals, list) or not 1 <= len(intervals) <= 8:
        raise ValueError('intervals')
    result, previous = [], rise
    for item in intervals:
        start, stop = number(item['start']), number(item['end'])
        if not previous <= start < stop <= end:
            raise ValueError('interval')
        result.append({'start': start, 'end': stop})
        previous = stop
    return {'rise': rise, 'set': end, 'illuminated': result}


def state_at(schedule, now):
    end = schedule['set']
    if now >= end:
        return {'phase': 'ended', 'target': end - APPLE_EPOCH, 'targetsShadow': False}
    for interval in schedule['illuminated']:
        if now < interval['start']:
            return {'phase': 'upcoming' if now < schedule['rise'] else 'shadow',
                    'target': interval['start'] - APPLE_EPOCH, 'targetsShadow': False}
        if now < interval['end']:
            return {'phase': 'visible', 'target': interval['end'] - APPLE_EPOCH,
                    'targetsShadow': interval['end'] < end}
    return {'phase': 'shadow', 'target': end - APPLE_EPOCH, 'targetsShadow': False}


def boundaries(schedule):
    return sorted({schedule['rise'], schedule['set'],
                   *(t for i in schedule['illuminated'] for t in i.values())})


def aps_payload(schedule, now):
    state = state_at(schedule, now)
    aps = {'timestamp': int(now), 'event': 'end' if state['phase'] == 'ended' else 'update',
           'content-state': state}
    if state['phase'] == 'ended':
        aps['dismissal-date'] = int(now + 60)
    else:
        aps['stale-date'] = math.ceil(min(t for t in boundaries(schedule) if t > now))
    return aps
