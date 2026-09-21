import datetime as dt
import hashlib
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import MagicMock, patch
from google.api_core.exceptions import AlreadyExists, ServiceUnavailable

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'functions'))
from common import prediction_pipeline as pipeline
from common.delivery import claim_delivery, finish_delivery

spec = importlib.util.spec_from_file_location('notification_scheduler', ROOT / 'jobs/schedule_notifications/main.py')
scheduler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scheduler)
NOW = dt.datetime(2026, 9, 21, 12, tzinfo=dt.timezone.utc)


def transit(when=NOW + dt.timedelta(hours=6), elevation=65):
    return {'culmination': {'time': when.isoformat()}, 'visible_culmination_elev': elevation,
            'visible_above_10_deg_duration_sec': 240}


class PredictionPipelineTests(unittest.TestCase):
    def test_task_is_deduplicated_and_authenticated_without_device_data(self):
        client = MagicMock()
        client.queue_path.return_value = 'projects/test/locations/us-central1/queues/pass-predictions'
        pipeline.enqueue_region(client, 'test', 's0000', NOW)
        task = client.create_task.call_args.kwargs['task']
        pipeline.enqueue_region(client, 'test', 's0000', NOW + dt.timedelta(seconds=1))
        self.assertEqual(task['name'], client.create_task.call_args.kwargs['task']['name'])
        self.assertIn('oidc_token', task['http_request'])
        self.assertEqual(task['http_request']['body'], b'{"region": "s0000"}')
        client.create_task.side_effect = AlreadyExists('exists')
        self.assertFalse(pipeline.enqueue_region(client, 'test', 's0000', NOW))

    def test_source_change_expiry_and_old_calculation_invalidate_coverage(self):
        data = {'schema_version': 2, 'source_hash': 'new', 'scan_end_time': NOW + dt.timedelta(days=7), 'generated_at': NOW}
        self.assertTrue(pipeline.coverage_is_fresh(data, 'new', NOW))
        self.assertFalse(pipeline.coverage_is_fresh(data, 'different', NOW))
        self.assertFalse(pipeline.coverage_is_fresh(data, 'new', NOW + dt.timedelta(hours=13)))
        self.assertFalse(pipeline.coverage_is_fresh({**data, 'scan_end_time': NOW - dt.timedelta(days=181)}, 'new', NOW))

    def test_pass_identity_survives_tle_correction_but_not_another_orbit(self):
        old = [('old-pass', {'transit': transit()})]
        corrected = transit(NOW + dt.timedelta(hours=6, seconds=45))
        result = pipeline.match_pass_ids([corrected, transit(NOW + dt.timedelta(hours=7, minutes=30))], old, '25544')
        self.assertEqual(result[0][0], 'old-pass')
        self.assertNotEqual(result[1][0], 'old-pass')

    def test_incomplete_grazing_pass_does_not_block_valid_predictions(self):
        incomplete = {'visible_culmination_elev': 10, 'elev10_rise': {'time': NOW.isoformat()}}
        result = pipeline.match_pass_ids([incomplete, transit()], [], '25544')
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0][1], transit())

    def test_busy_worker_does_not_compute(self):
        db, storage, predict = MagicMock(), MagicMock(), MagicMock()
        blob = storage.bucket.return_value.get_blob.return_value
        blob.updated = dt.datetime.now(dt.timezone.utc)
        blob.download_as_text.return_value = 'ISS\nline1\nline2'
        with patch.object(pipeline, 'acquire', return_value='busy'):
            with self.assertRaisesRegex(RuntimeError, 'lease_busy'):
                pipeline.refresh_region(db, 's0000', predict, storage)
        predict.assert_not_called()
        db.batch.assert_not_called()

    def test_failed_compute_does_not_publish_coverage(self):
        db, storage = MagicMock(), MagicMock()
        blob = storage.bucket.return_value.get_blob.return_value
        blob.updated = dt.datetime.now(dt.timezone.utc)
        blob.download_as_text.return_value = 'ISS\nline1\nline2'
        with patch.object(pipeline, 'acquire', return_value='acquired'):
            with self.assertRaisesRegex(RuntimeError, 'prediction_failed'):
                pipeline.refresh_region(db, 's0000', MagicMock(return_value={'error': 'failed'}), storage)
        db.batch.assert_not_called()

    def test_expired_coverage_restarts_now_and_publishes_atomically(self):
        db, storage = MagicMock(), MagicMock()
        ref = db.collection.return_value.document.return_value
        ref.collection.return_value.stream.return_value = []
        blob = storage.bucket.return_value.get_blob.return_value
        blob.updated = dt.datetime.now(dt.timezone.utc)
        blob.download_as_text.return_value = 'ISS\nline1\nline2'
        owner = 'lease-test'
        ref.get.return_value.to_dict.return_value = {'lease_owner': owner}
        predict = MagicMock(return_value=[transit()])
        before = dt.datetime.now(dt.timezone.utc)
        with patch.object(pipeline, 'acquire', return_value='acquired'), patch.object(pipeline.uuid, 'uuid4', return_value=MagicMock(hex=owner)):
            self.assertEqual(pipeline.refresh_region(db, 's0000', predict, storage), 2)
        for call in predict.call_args_list:
            start, end = pipeline.utc(call.kwargs['start_time_str']), pipeline.utc(call.kwargs['end_time_str'])
            self.assertGreaterEqual(start, before)
            self.assertEqual(end - start, dt.timedelta(days=7))
        self.assertEqual(db.batch.return_value.commit.call_count, 2)
        self.assertEqual(db.batch.return_value.update.call_count, 2)
        self.assertIn('option', db.batch.return_value.update.call_args.kwargs)
        ref.set.assert_not_called()


class NotificationPlanTests(unittest.TestCase):
    def test_threshold_and_4pm_before_pass(self):
        self.assertIsNone(scheduler.schedule_for(transit(elevation=19.9), 0, 'regular'))
        self.assertEqual(scheduler.schedule_for(transit(), 0, 'regular'), NOW + dt.timedelta(hours=5, minutes=55))
        self.assertEqual(scheduler.schedule_for(transit(), 0, 'prominent'), NOW + dt.timedelta(hours=4))
        self.assertIsNone(scheduler.schedule_for(transit(NOW + dt.timedelta(hours=1)), 0, 'prominent'))

    def test_plan_does_not_overwrite_sent_or_legacy_receipt(self):
        tx, ref = MagicMock(), MagicMock()
        for data in ({'status': 'sent'}, {'task_id': 'legacy-task'}, {'lease_until': dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=1)}):
            ref.get.return_value.to_dict.return_value = data
            self.assertFalse(scheduler.plan.to_wrap(tx, ref, {'status': 'planned'}))
        tx.set.assert_not_called()

    def test_repeated_plans_create_same_tasks_and_accept_already_exists(self):
        db, client = MagicMock(), MagicMock()
        passes = {'25544': [('pass-one', transit(), 2)]}
        client.queue_path.return_value = 'queue'
        with patch.object(scheduler, 'plan', return_value=True):
            scheduler.schedule_user(db, client, 'test', 'device', {'tzOffset': 0}, 's0000', passes, NOW)
            first = [c.kwargs['task']['name'] for c in client.create_task.call_args_list]
            client.reset_mock()
            client.create_task.side_effect = AlreadyExists('exists')
            scheduler.schedule_user(db, client, 'test', 'device', {'tzOffset': 0}, 's0000', passes, NOW)
        self.assertEqual(first, [c.kwargs['task']['name'] for c in client.create_task.call_args_list])

    def test_outbox_survives_task_creation_failure(self):
        db, client = MagicMock(), MagicMock()
        client.create_task.side_effect = ServiceUnavailable('offline')
        with patch.object(scheduler, 'plan', return_value=True) as plan:
            with self.assertRaises(ServiceUnavailable):
                scheduler.schedule_user(db, client, 'test', 'device', {'tzOffset': 0}, 's0000', {'25544': [('pass', transit(), 2)]}, NOW)
        self.assertEqual(plan.call_args.args[-1]['status'], 'planned')
        db.collection.return_value.document.return_value.collection.return_value.document.return_value.delete.assert_not_called()

    def test_past_notification_is_not_replayed(self):
        db, client = MagicMock(), MagicMock()
        passes = {'25544': [('pass', transit(NOW + dt.timedelta(minutes=2)), 2)]}
        self.assertEqual(scheduler.schedule_user(db, client, 'test', 'device', {'tzOffset': 0}, 's0000', passes, NOW), 0)
        client.create_task.assert_not_called()


class ReceiptTests(unittest.TestCase):
    def test_terminal_superseded_and_concurrent_attempts_do_not_send(self):
        tx, ref = MagicMock(), MagicMock()
        for data, expected in (({'status': 'sent'}, 'done'),
                               ({'task_id': 'newer'}, 'superseded'),
                               ({'lease_until': NOW + dt.timedelta(seconds=30)}, 'busy')):
            ref.get.return_value.to_dict.return_value = data
            self.assertEqual(claim_delivery.to_wrap(tx, ref, 'task', NOW), expected)
        tx.set.assert_not_called()

    def test_expired_lease_is_retryable(self):
        tx, ref = MagicMock(), MagicMock()
        ref.get.return_value.to_dict.return_value = {'status': 'sending', 'lease_until': NOW - dt.timedelta(seconds=1)}
        self.assertEqual(claim_delivery.to_wrap(tx, ref, 'task', NOW), 'claimed')
        self.assertEqual(tx.set.call_args.args[1]['status'], 'sending')

    def test_success_receipt_is_retained(self):
        ref = MagicMock()
        finish_delivery(ref, 'sent', NOW)
        self.assertEqual(ref.set.call_args.args[0]['status'], 'sent')
        self.assertEqual(ref.set.call_args.args[0]['expires_at'], NOW + dt.timedelta(days=7))
        ref.delete.assert_not_called()


if __name__ == '__main__':
    unittest.main()
