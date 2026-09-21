"""Delivery receipts survive retries; FCM acceptance is distinct from device delivery."""
from datetime import datetime, timedelta, timezone
from google.cloud import firestore

TERMINAL = {'sent', 'skipped', 'unregistered'}


@firestore.transactional
def claim_delivery(transaction, ref, task_id, now):
    data = ref.get(transaction=transaction).to_dict() or {}
    if data.get('status') in TERMINAL:
        return 'done'
    if data.get('task_id') and data['task_id'] != task_id:
        return 'superseded'
    if data.get('lease_until') and data['lease_until'] > now:
        return 'busy'
    transaction.set(ref, {'status': 'sending', 'lease_until': now + timedelta(minutes=2),
                          'task_id': task_id}, merge=True)
    return 'claimed'


def finish_delivery(ref, status, now, reason=None):
    values = {'status': status, 'lease_until': None,
              'completed_at': now, 'expires_at': now + timedelta(days=7)}
    if reason:
        values['reason'] = reason
    ref.set(values, merge=True)
