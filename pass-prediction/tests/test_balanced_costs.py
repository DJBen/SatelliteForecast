"""Cost controls must preserve returning-user alerts and retryable outbox writes."""
import datetime as dt
from pathlib import Path
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'functions'))
from common.activity import eligible_user, LEGACY_GRACE_UNTIL
from common import prediction_pipeline as pipeline
from common import notification_scheduler as scheduler
from test_prediction_refresh import main
from flask import Flask, request
from types import SimpleNamespace

NOW = dt.datetime(2026, 9, 24, tzinfo=dt.timezone.utc)


class ActivityTests(unittest.TestCase):
    def test_thirty_day_boundary_debug_disabled_and_returning_user(self):
        for data, expected in [
            ({'lastAppLaunch': NOW}, True),
            ({'lastAppLaunch': NOW - dt.timedelta(days=30)}, True),
            ({'lastAppLaunch': NOW - dt.timedelta(days=30, seconds=1)}, False),
            ({'lastAppLaunch': NOW, 'appVariant': 'debug'}, True),
            ({'lastAppLaunch': NOW, 'appVariant': 'release'}, True),
            *[({'lastAppLaunch': NOW, 'appVariant': variant}, False)
              for variant in ('test', 'ui-test', 'snapshot', 'preview')],
            ({'lastAppLaunch': NOW, 'notifications_disabled': True}, False),
            ({'lastAppLaunch': NOW + dt.timedelta(days=2)}, False),
            ({'lastAppLaunch': 'broken'}, False),
            ({'lastAppLaunch': NOW.isoformat()}, True),
        ]:
            with self.subTest(data=data):
                self.assertEqual(eligible_user(data, NOW), expected)

    def test_missing_timestamp_has_fixed_grace_not_per_deploy_extension(self):
        self.assertTrue(eligible_user({}, LEGACY_GRACE_UNTIL - dt.timedelta(seconds=1)))
        self.assertFalse(eligible_user({}, LEGACY_GRACE_UNTIL))
        self.assertFalse(eligible_user({'lastAppLaunch': 'bad'}, NOW))


class DispatchTests(unittest.TestCase):
    def test_batch_freshness_handles_unordered_missing_and_changed_satellite(self):
        db = MagicMock()
        fresh = {'schema_version': 2, 'source_hash': 'same', 'generated_at': NOW,
                 'scan_end_time': NOW + dt.timedelta(days=7)}
        def snapshot(key, data):
            result = MagicMock(id=key)
            result.to_dict.return_value = data
            return result
        db.get_all.return_value = [snapshot('48274_fresh', fresh),
                                   snapshot('25544_oldxx', fresh),
                                   snapshot('25544_fresh', fresh),
                                   snapshot('48274_oldxx', {**fresh, 'source_hash': 'old'})]
        result = pipeline.stale_regions(db, ['fresh', 'oldxx', 'missg'],
                                        {sat: {'hash': 'same'} for sat in pipeline.SATELLITES}, NOW)
        self.assertEqual(result, {'oldxx', 'missg'})
        self.assertEqual(len(db.get_all.call_args.args[0]), 6)
        self.assertFalse(pipeline.coverage_is_fresh({'schema_version': 2, 'source_hash': 'same'}, 'same', NOW))

    def test_warm_orbital_cache_expires(self):
        with patch.dict(pipeline._ORBITAL_CACHE, {}, clear=True), \
             patch.object(pipeline, '_load_sources', return_value={'source': 'one'}) as load, \
             patch.object(pipeline.storage, 'Client'), \
             patch.object(pipeline.time, 'monotonic', side_effect=[0, 0, 299, 301, 301]):
            pipeline.orbital_sources()
            pipeline.orbital_sources()
            self.assertEqual(load.call_count, 1)
            pipeline.orbital_sources()
            self.assertEqual(load.call_count, 2)

    def test_fresh_returning_user_schedules_without_worker(self):
        after = MagicMock(exists=True)
        after.to_dict.return_value = {'lat': 0, 'lon': 0, 'geoHash5': '7zzzz', 'lastAppLaunch': NOW}
        before = MagicMock(exists=True)
        before.to_dict.return_value = {**after.to_dict.return_value, 'lastAppLaunch': NOW - dt.timedelta(days=40)}
        event = SimpleNamespace(params={'push_token': 'test'}, data=SimpleNamespace(before=before, after=after))
        with patch.object(main, 'eligible_user', return_value=True), \
             patch.object(main, 'orbital_sources'), patch.object(main, 'stale_regions', return_value=set()), \
             patch.object(main, 'enqueue_region') as enqueue, patch.object(main, 'reconcile_user') as reconcile:
            main.on_user_location_change.__wrapped__(event)
        reconcile.assert_called_once()
        enqueue.assert_not_called()

    def test_internal_geohash_backfill_does_not_trigger_second_dispatch(self):
        before, after = MagicMock(exists=True), MagicMock(exists=True)
        before.to_dict.return_value = {'lat': 0, 'lon': 0, 'lastAppLaunch': NOW}
        after.to_dict.return_value = {**before.to_dict.return_value, 'geoHash5': '7zzzz'}
        with patch.object(main, 'eligible_user', return_value=True), \
             patch.object(main, 'orbital_sources') as sources:
            main.on_user_location_change.__wrapped__(SimpleNamespace(data=SimpleNamespace(before=before, after=after)))
        sources.assert_not_called()

    def test_queued_work_for_inactive_region_does_not_compute(self):
        with Flask(__name__).test_request_context('/', method='POST', json={'region': '7zzzz'}), \
             patch.object(main, 'eligible_region_users', return_value=[]), \
             patch.object(main, 'refresh_region') as refresh:
            self.assertEqual(main.process_prediction_region.__wrapped__(request)[1], 200)
        refresh.assert_not_called()

    def test_worker_reconciles_even_if_prediction_was_already_fresh(self):
        with Flask(__name__).test_request_context('/', method='POST', json={'region': '7zzzz'}), \
             patch.object(main, 'eligible_region_users', return_value=[('test', {})]), \
             patch.object(main, 'refresh_region', return_value=0), \
             patch.object(main, 'reconcile_region', return_value=1) as reconcile:
            self.assertEqual(main.process_prediction_region.__wrapped__(request)[1], 200)
        reconcile.assert_called_once()


class OutboxTests(unittest.TestCase):
    def test_debug_device_is_scheduled_but_test_variants_do_not_create_tasks(self):
        transits = {'25544': [('pass', {
            'culmination': {'time': (NOW + dt.timedelta(hours=1)).isoformat()},
            'visible_culmination_elev': 44}, 2)]}
        for variant in ('debug', 'test', 'ui-test', 'snapshot', 'preview'):
            with self.subTest(variant=variant):
                db, client = MagicMock(), MagicMock()
                with patch.object(scheduler, 'plan', return_value=True), \
                     patch.object(scheduler, 'mark_task_created'):
                    count = scheduler.schedule_user(db, client, 'test', 'device',
                        {'lastAppLaunch': NOW, 'tzOffset': 0, 'appVariant': variant},
                        '7zzzz', transits, NOW)
                self.assertEqual(count, 1 if variant == 'debug' else 0)
                self.assertEqual(client.create_task.call_count, count)

    def test_confirmed_unchanged_task_has_no_write(self):
        tx, ref = MagicMock(), MagicMock()
        ref.get.return_value.to_dict.return_value = {'task_id': 'same', 'scheduler_version': 2,
                                                    'status': 'planned', 'task_created': True}
        self.assertFalse(scheduler.plan.to_wrap(tx, ref, {'task_id': 'same'}))
        tx.set.assert_not_called()

    def test_incomplete_creation_retries_and_changed_task_resets_marker(self):
        for old_task, confirmed in [('same', False), ('different', True)]:
            tx, ref = MagicMock(), MagicMock()
            ref.get.return_value.to_dict.return_value = {'task_id': old_task, 'scheduler_version': 2,
                                                        'status': 'planned', 'task_created': confirmed}
            self.assertTrue(scheduler.plan.to_wrap(tx, ref, {'task_id': 'same'}))
            self.assertFalse(tx.set.call_args.args[1]['task_created'])

    def test_late_creation_confirmation_cannot_mark_newer_task(self):
        tx, ref = MagicMock(), MagicMock()
        ref.get.return_value.to_dict.return_value = {'task_id': 'new', 'task_created': False}
        scheduler.mark_task_created.to_wrap(tx, ref, 'old')
        tx.update.assert_not_called()
        scheduler.mark_task_created.to_wrap(tx, ref, 'new')
        tx.update.assert_called_once_with(ref, {'task_created': True})

    def test_creation_failure_never_marks_receipt_confirmed(self):
        from google.api_core.exceptions import ServiceUnavailable
        db, client = MagicMock(), MagicMock()
        client.create_task.side_effect = ServiceUnavailable('offline')
        peak = NOW + dt.timedelta(hours=1)
        transits = {'25544': [('pass', {'culmination': {'time': peak.isoformat()},
                                      'visible_culmination_elev': 25}, 2)]}
        with patch.object(scheduler, 'plan', return_value=True), \
             patch.object(scheduler, 'mark_task_created') as mark:
            with self.assertRaises(ServiceUnavailable):
                scheduler.schedule_user(db, client, 'test', 'device',
                                        {'lastAppLaunch': NOW, 'tzOffset': 0}, '7zzzz', transits, NOW)
        mark.assert_not_called()

    def test_already_created_task_repairs_missing_confirmation(self):
        from google.api_core.exceptions import AlreadyExists
        db, client = MagicMock(), MagicMock()
        client.create_task.side_effect = AlreadyExists('exists')
        peak = NOW + dt.timedelta(hours=1)
        transits = {'25544': [('pass', {'culmination': {'time': peak.isoformat()},
                                      'visible_culmination_elev': 25}, 2)]}
        with patch.object(scheduler, 'plan', return_value=True), \
             patch.object(scheduler, 'mark_task_created') as mark:
            scheduler.schedule_user(db, client, 'test', 'device',
                                    {'lastAppLaunch': NOW, 'tzOffset': 0}, '7zzzz', transits, NOW)
        mark.assert_called_once()

    def test_inactive_users_cannot_schedule(self):
        db, client = MagicMock(), MagicMock()
        self.assertEqual(scheduler.schedule_user(db, client, 'test', 'device',
                         {'lastAppLaunch': NOW - dt.timedelta(days=31)}, '7zzzz', {}, NOW), 0)
        db.collection.assert_not_called()
        client.create_task.assert_not_called()
