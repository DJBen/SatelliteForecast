import sys
from pathlib import Path
import unittest
from unittest.mock import Mock, patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'functions'))
from common.live_activity import APPLE_EPOCH, validate_schedule, boundaries, aps_payload
from common.live_activity_backend import handle_delivery, handle_registration, register, enqueue, DELIVERY_URL
from firebase_admin import messaging

class LiveActivityTests(unittest.TestCase):
    def schedule(self, intervals=None):
        return {'rise': 1800000000., 'set': 1800000480.,
                'illuminated': intervals or [{'start': 1800000000., 'end': 1800000480.}]}

    def test_full_illumination_and_end(self):
        s = self.schedule()
        self.assertEqual(boundaries(s), [s['rise'], s['set']])
        self.assertEqual(aps_payload(s, s['rise'] - 1)['content-state']['phase'], 'upcoming')
        p = aps_payload(s, s['rise'])
        self.assertEqual(p['content-state'], {'phase': 'visible', 'target': s['set'] - APPLE_EPOCH, 'targetsShadow': False})
        self.assertEqual(p['stale-date'], s['set'])
        end = aps_payload(s, s['set'])
        self.assertEqual(end['event'], 'end')
        self.assertEqual(end['dismissal-date'], s['set'] + 60)
        self.assertNotIn('stale-date', end)

    def test_shadow_entry_exit_and_multiple_intervals(self):
        s = self.schedule([{'start': 1800000120., 'end': 1800000240.}, {'start': 1800000360., 'end': 1800000480.}])
        phases = ['upcoming', 'shadow', 'visible', 'shadow', 'visible', 'ended']
        for offset, phase in zip([-1, 0, 120, 240, 360, 480], phases):
            self.assertEqual(aps_payload(s, s['rise'] + offset)['content-state']['phase'], phase)
        self.assertTrue(aps_payload(s, s['rise'] + 120)['content-state']['targetsShadow'])
        self.assertEqual(aps_payload(s, s['rise'] - 1)['stale-date'], s['rise'])

    def test_invalid_schedules(self):
        now = 1799999900
        self.assertEqual(validate_schedule(self.schedule(), now), self.schedule())
        for value in [float('nan'), float('inf'), True, '1800000000', now + 90000]:
            with self.assertRaises(ValueError): validate_schedule({**self.schedule(), 'rise': value}, now)
        with self.assertRaises(ValueError): validate_schedule(self.schedule(), 1800000500)
        with self.assertRaises(ValueError): validate_schedule(self.schedule([{'start': 1800000240., 'end': 1800000360.}, {'start': 1800000120., 'end': 1800000200.}]), now)

    def test_sdk_preserves_live_token_and_wire_dates(self):
        from firebase_admin._messaging_encoder import MessageEncoder
        p = aps_payload(self.schedule(), 1800000123)
        message = messaging.Message(token='fcm-token', apns=messaging.APNSConfig(live_activity_token='abc',
            payload=messaging.APNSPayload(messaging.Aps(custom_data=p))))
        encoded = MessageEncoder().default(message)
        self.assertEqual(encoded['apns']['live_activity_token'], 'abc')
        self.assertEqual(encoded['apns']['payload']['aps'], p)
        self.assertEqual(p['timestamp'], 1800000123)
        self.assertEqual(p['content-state']['target'], 1800000480 - APPLE_EPOCH)

    @patch('common.live_activity_backend.retire')
    @patch('common.live_activity_backend.messaging.send')
    @patch('common.live_activity_backend.time.time', return_value=1800000500)
    def test_late_job_sends_end_not_obsolete_phase(self, clock, send, retire):
        db, request = Mock(), Mock()
        request.get_json.return_value = {'id': '0123456789abcdef'}
        db.collection.return_value.document.return_value.get.return_value.to_dict.return_value = {
            'schedule': self.schedule(), 'activity_token': 'abc', 'fcm_token': 'fcm', 'revision': 1}
        self.assertEqual(handle_delivery(request, db)[1], 204)
        self.assertEqual(send.call_args.args[0].apns.payload.aps.custom_data['event'], 'end')

    @patch('common.live_activity_backend.messaging.send')
    def test_cancelled_job_sends_nothing(self, send):
        db, request = Mock(), Mock()
        request.get_json.return_value = {'id': '0123456789abcdef'}
        db.collection.return_value.document.return_value.get.return_value.to_dict.return_value = {'cancelled': True}
        self.assertEqual(handle_delivery(request, db)[1], 204)
        send.assert_not_called()

    @patch('common.live_activity_backend.app_check.verify_token', side_effect=ValueError())
    def test_unauthenticated_registration_rejected(self, verify):
        request, db = Mock(), Mock()
        request.method, request.content_length = 'POST', 100
        self.assertEqual(handle_registration(request, db, Mock(), 'project')[1], 401)
        db.collection.assert_not_called()

    def test_queue_uses_service_url_as_oidc_audience(self):
        client = Mock()
        client.queue_path.return_value = 'projects/p/locations/us-central1/queues/q'
        enqueue(client, 'p', '0123456789abcdef', 1800000000.)
        request = client.create_task.call_args.kwargs['task']['http_request']
        self.assertEqual(request['url'], DELIVERY_URL)
        self.assertEqual(request['oidc_token']['audience'], DELIVERY_URL)
        self.assertNotIn('token', request['body'].decode())

    def registration_body(self):
        return {'id': '0123456789abcdef', 'secret': 'secret-0123456789abcdef',
                'schedule': self.schedule(), 'activityToken': 'ab' * 32,
                'fcmToken': 'fcm-token-0123456789abcdef', 'revision': 1799999999000}

    def test_registration_token_rotation_and_ownership(self):
        ref, tx = Mock(), Mock()
        body = self.registration_body()
        ref.get.return_value.to_dict.return_value = None
        value, active = register.to_wrap(tx, ref, body, 1799999999)
        self.assertTrue(active)
        ref.get.return_value.to_dict.return_value = value
        older = {**body, 'revision': body['revision'] - 1, 'activityToken': 'cd' * 32}
        self.assertFalse(register.to_wrap(tx, ref, older, 1799999999)[1])
        with self.assertRaises(PermissionError):
            register.to_wrap(tx, ref, {**body, 'secret': 'other-0123456789abcdef'}, 1799999999)
        newer = {**body, 'revision': body['revision'] + 1, 'activityToken': 'cd' * 32}
        self.assertEqual(register.to_wrap(tx, ref, newer, 1799999999)[0]['activity_token'], 'cd' * 32)

    def test_cancel_tombstone_blocks_late_registration(self):
        ref, tx = Mock(), Mock()
        body = self.registration_body()
        ref.get.return_value.to_dict.return_value = None
        register.to_wrap(tx, ref, {**body, 'cancel': True}, 1799999999)
        tombstone = tx.set.call_args.args[1]
        self.assertNotIn('activity_token', tombstone)
        ref.get.return_value.to_dict.return_value = tombstone
        self.assertFalse(register.to_wrap(tx, ref, body, 1799999999)[1])

if __name__ == '__main__': unittest.main()
