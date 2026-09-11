"""
Unit Test Suite for Aggregator Lambda Handler
"""

import json
import os
import sys
import unittest
import importlib.util
from unittest.mock import MagicMock

aggregator_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../src/backend/aggregator/handler.py"))
spec = importlib.util.spec_from_file_location("aggregator_handler", aggregator_path)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


class TestAggregatorHandler(unittest.TestCase):
    def setUp(self):
        self.mock_table = MagicMock()
        handler.set_dynamodb_table(self.mock_table)

    def tearDown(self):
        handler.set_dynamodb_table(None)

    def test_empty_records_batch(self):
        event = {"Records": []}
        result = handler.lambda_handler(event)
        self.assertEqual(result, {"batchItemFailures": []})
        self.mock_table.update_item.assert_not_called()

    def test_in_memory_aggregation_and_atomic_update(self):
        event = {
            "Records": [
                {
                    "messageId": "msg-001",
                    "body": json.dumps({"team_id": "Team Alpha", "votes": 1}),
                },
                {
                    "messageId": "msg-002",
                    "body": json.dumps({"team_id": "Team Beta", "votes": 5}),
                },
                {
                    "messageId": "msg-003",
                    "body": json.dumps({"team_id": "Team Alpha", "votes": 2}),
                },
                {
                    "messageId": "msg-004",
                    "body": json.dumps({"team_id": "Team Beta", "votes": 1}),
                },
            ]
        }

        result = handler.lambda_handler(event)
        self.assertEqual(result, {"batchItemFailures": []})
        self.assertEqual(self.mock_table.update_item.call_count, 2)

        called_updates = {}
        for call_args in self.mock_table.update_item.call_args_list:
            kwargs = call_args[1]
            team = kwargs["Key"]["team_id"]
            val = kwargs["ExpressionAttributeValues"][":val"]
            expr = kwargs["UpdateExpression"]
            self.assertEqual(expr, "ADD vote_count :val")
            called_updates[team] = val

        self.assertEqual(called_updates["Team Alpha"], 3)
        self.assertEqual(called_updates["Team Beta"], 6)

    def test_partial_batch_failure_on_malformed_json(self):
        event = {
            "Records": [
                {
                    "messageId": "valid-msg",
                    "body": json.dumps({"team_id": "Team Gamma", "votes": 10}),
                },
                {
                    "messageId": "broken-msg",
                    "body": "NOT_VALID_JSON{:::}",
                },
            ]
        }

        result = handler.lambda_handler(event)
        self.assertEqual(result["batchItemFailures"], [{"itemIdentifier": "broken-msg"}])
        self.mock_table.update_item.assert_called_once()
        call_kwargs = self.mock_table.update_item.call_args[1]
        self.assertEqual(call_kwargs["Key"]["team_id"], "Team Gamma")
        self.assertEqual(call_kwargs["ExpressionAttributeValues"][":val"], 10)

    def test_missing_team_id_reported_as_failure(self):
        event = {
            "Records": [
                {
                    "messageId": "missing-team",
                    "body": json.dumps({"votes": 5}),
                }
            ]
        }

        result = handler.lambda_handler(event)
        self.assertEqual(result["batchItemFailures"], [{"itemIdentifier": "missing-team"}])
        self.mock_table.update_item.assert_not_called()

    def test_dynamodb_exception_fails_associated_messages(self):
        self.mock_table.update_item.side_effect = Exception("DynamoDB Service Unavailable")

        event = {
            "Records": [
                {
                    "messageId": "msg-delta-1",
                    "body": json.dumps({"team_id": "Team Delta", "votes": 1}),
                },
                {
                    "messageId": "msg-delta-2",
                    "body": json.dumps({"team_id": "Team Delta", "votes": 2}),
                },
            ]
        }

        result = handler.lambda_handler(event)
        failed_ids = [item["itemIdentifier"] for item in result["batchItemFailures"]]
        self.assertIn("msg-delta-1", failed_ids)
        self.assertIn("msg-delta-2", failed_ids)

    def test_double_stringified_json_parsing(self):
        event = {
            "Records": [
                {
                    "messageId": "double-encoded-msg",
                    "body": json.dumps(json.dumps({"team_id": "Team Epsilon", "votes": 4})),
                }
            ]
        }

        result = handler.lambda_handler(event)
        self.assertEqual(result, {"batchItemFailures": []})
        self.mock_table.update_item.assert_called_once()
        kwargs = self.mock_table.update_item.call_args[1]
        self.assertEqual(kwargs["Key"]["team_id"], "Team Epsilon")
        self.assertEqual(kwargs["ExpressionAttributeValues"][":val"], 4)


if __name__ == "__main__":
    unittest.main()
