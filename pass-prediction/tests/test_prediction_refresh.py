"""Regression coverage for production refresh failures; no network or credentials."""
import datetime
import importlib.util
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

from flask import Flask, request
from firebase_functions import scheduler_fn

FUNCTIONS = Path(__file__).resolve().parents[1] / 'functions'
sys.path.insert(0, str(FUNCTIONS))
with patch('firebase_admin.initialize_app'), patch('firebase_admin.firestore.client'), \
     patch('google.auth.default', return_value=(MagicMock(), 'test-project')), \
     patch('google.cloud.tasks_v2.CloudTasksClient'):
    spec = importlib.util.spec_from_file_location('prediction_main', FUNCTIONS / 'main.py')
    main = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(main)


class SchedulerTimestampTests(unittest.TestCase):
    def test_global_refresh_accepts_production_scheduler_timestamp(self):
        app = Flask(__name__)
        with patch.object(main, 'db') as db, app.test_request_context('/', method='POST', headers={
            'X-CloudScheduler-ScheduleTime': '2026-09-18T17:00:01.515191-07:00',
            'X-CloudScheduler-JobName': 'global-refresh-regression',
        }):
            query = db.collection.return_value.select.return_value.order_by.return_value.limit.return_value
            query.stream.return_value = []
            response = main.refresh_all_user_transits(request)
        self.assertEqual(response.status_code, 200)
        self.assertIn(unittest.mock.call('users'), db.collection.call_args_list)
        query.stream.assert_called_once_with()

    def test_scheduler_delivers_fractional_seconds_without_losing_precision(self):
        received = []

        @scheduler_fn.on_schedule(schedule='0 * * * *')
        def scheduled(event):
            received.append(event)

        app = Flask(__name__)
        for value in ('2026-09-18T17:00:01.515191-07:00',
                      '2026-09-21T06:17:00.244034Z',
                      '2026-09-21T06:17:00Z'):
            with self.subTest(value=value), app.test_request_context('/', method='POST', headers={
                'X-CloudScheduler-ScheduleTime': value,
                'X-CloudScheduler-JobName': 'regression-test',
            }):
                response = scheduled(request)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(received[-1].schedule_time,
                                 datetime.datetime.fromisoformat(value))
                self.assertEqual(received[-1].job_name, 'regression-test')


class LocationEnqueueTests(unittest.TestCase):
    def test_location_write_queues_work_without_calculating(self):
        snapshot = MagicMock(exists=True)
        snapshot.to_dict.return_value = {'lat': 0, 'lon': 0, 'alt': 0}
        event = SimpleNamespace(params={'push_token': 'test-device'},
                                data=SimpleNamespace(before=snapshot, after=snapshot))
        with patch.object(main, 'enqueue_region') as enqueue, patch.object(main, 'find_visible_satellite_transits') as predict:
            main.on_user_location_change.__wrapped__(event)
        enqueue.assert_called_once()
        snapshot.reference.update.assert_called_once_with({'geoHash5': '7zzzz'})
        predict.assert_not_called()

    def test_invalid_and_disabled_registrations_are_ignored(self):
        for data in ({'lat': float('nan'), 'lon': 0}, {'lat': 0, 'lon': 0, 'notifications_disabled': True}):
            snapshot = MagicMock(exists=True)
            snapshot.to_dict.return_value = data
            event = SimpleNamespace(data=SimpleNamespace(after=snapshot))
            with patch.object(main, 'enqueue_region') as enqueue:
                main.on_user_location_change.__wrapped__(event)
            enqueue.assert_not_called()




class DeliveryEndpointTests(unittest.TestCase):
    def call(self, *, moved=False, expired=False, success=True, code=500, claim='claimed'):
        now = datetime.datetime.now(datetime.timezone.utc)
        peak = now + datetime.timedelta(minutes=-1 if expired else 5)
        payload = {'push_token': 'test-device', 'sat_id': '25544', 'tz_offset': 0,
                   'notification_id': 'pass-one', 'geo_hash_5': 'xxxxx' if moved else '7zzzz',
                   'transit': {'culmination': {'time': peak.isoformat()}, 'visible_culmination_elev': 45}}
        app = Flask(__name__)
        database = MagicMock()
        user_ref = MagicMock()
        user_ref.get.return_value.to_dict.return_value = {'lat': 0, 'lon': 0, 'alt': 0, 'tzOffset': 0}
        receipt = MagicMock(path='receipt/test')
        def collection(name):
            result = MagicMock()
            if name == 'users':
                result.document.return_value = user_ref
            else:
                result.document.return_value.collection.return_value.document.return_value = receipt
            return result
        database.collection.side_effect = collection
        with patch.object(main, 'db', database), patch.object(main, 'claim_delivery', return_value=claim), \
             patch.object(main, 'finish_delivery') as finish, \
             patch.object(main, '_send_fcm_notification', return_value=(success, None if success else ('failed', code))) as send, \
             app.test_request_context('/', method='POST', json=payload, headers={'X-CloudTasks-TaskName': 'task-one'}):
            response = main._deliver_notification(request)
        return response, finish, send, receipt, user_ref

    def test_success_is_recorded_after_fcm_accepts(self):
        response, finish, send, receipt, _ = self.call()
        self.assertEqual(response[1], 200)
        send.assert_called_once()
        self.assertEqual(finish.call_args.args[1], 'sent')
        self.assertEqual(len(send.call_args.kwargs['collapse_id']), 64)
        receipt.delete.assert_not_called()

    def test_moved_and_expired_notifications_are_acknowledged_without_sending(self):
        for options, reason in (({'moved': True}, 'location_changed'), ({'expired': True}, 'pass_expired')):
            response, finish, send, _, _ = self.call(**options)
            self.assertEqual(response[1], 200)
            self.assertEqual(finish.call_args.args[3], reason)
            send.assert_not_called()

    def test_transient_failure_keeps_receipt_retryable(self):
        response, finish, send, receipt, _ = self.call(success=False)
        self.assertEqual(response[1], 500)
        finish.assert_not_called()
        receipt.set.assert_called_once_with({'status': 'planned', 'lease_until': None}, merge=True)
        receipt.delete.assert_not_called()

    def test_unregistered_token_is_disabled_and_acknowledged(self):
        response, finish, send, _, user = self.call(success=False, code=410)
        self.assertEqual(response[1], 200)
        self.assertEqual(finish.call_args.args[1], 'unregistered')
        self.assertTrue(user.update.call_args.args[0]['notifications_disabled'])

    def test_retry_after_success_does_not_send_again(self):
        response, finish, send, _, _ = self.call(claim='done')
        self.assertEqual(response[1], 200)
        send.assert_not_called()


if __name__ == '__main__':
    unittest.main()
