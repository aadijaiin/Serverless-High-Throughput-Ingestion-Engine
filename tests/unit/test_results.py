"""
Unit Test Suite for Results Lambda Handler
"""

import json
import os
import sys
import unittest
import importlib.util
from decimal import Decimal
from unittest.mock import MagicMock

results_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../src/backend/results/handler.py"))
spec = importlib.util.spec_from_file_location("results_handler", results_path)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


class TestResultsHandler(unittest.TestCase):
    def setUp(self):
        self.mock_table = MagicMock()
        handler.set_dynamodb_table(self.mock_table)

    def tearDown(self):
        handler.set_dynamodb_table(None)

    def test_cors_options_preflight(self):
        event = {"httpMethod": "OPTIONS"}
        response = handler.lambda_handler(event)

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(response["headers"]["Access-Control-Allow-Origin"], "*")
        self.assertIn("GET", response["headers"]["Access-Control-Allow-Methods"])

    def test_empty_scoreboard(self):
        self.mock_table.scan.return_value = {"Items": []}

        event = {"httpMethod": "GET"}
        response = handler.lambda_handler(event)

        self.assertEqual(response["statusCode"], 200)
        body = json.loads(response["body"])
        self.assertEqual(body["status"], "success")
        self.assertEqual(body["total_votes"], 0)
        self.assertIsNone(body["leader"])
        self.assertEqual(body["teams"], [])

    def test_populated_scoreboard_ranking_and_percentages(self):
        self.mock_table.scan.return_value = {
            "Items": [
                {"team_id": "Team Beta", "vote_count": Decimal("300")},
                {"team_id": "Team Alpha", "vote_count": Decimal("600")},
                {"team_id": "Team Gamma", "vote_count": Decimal("100")},
            ]
        }

        event = {"httpMethod": "GET"}
        response = handler.lambda_handler(event)

        self.assertEqual(response["statusCode"], 200)
        body = json.loads(response["body"])

        self.assertEqual(body["total_votes"], 1000)
        self.assertEqual(body["leader"], "Team Alpha")
        self.assertEqual(len(body["teams"]), 3)

        self.assertEqual(body["teams"][0]["team_id"], "Team Alpha")
        self.assertEqual(body["teams"][0]["vote_count"], 600)
        self.assertEqual(body["teams"][0]["percentage"], 60.0)

        self.assertEqual(body["teams"][1]["team_id"], "Team Beta")
        self.assertEqual(body["teams"][1]["vote_count"], 300)
        self.assertEqual(body["teams"][1]["percentage"], 30.0)

        self.assertEqual(body["teams"][2]["team_id"], "Team Gamma")
        self.assertEqual(body["teams"][2]["vote_count"], 100)
        self.assertEqual(body["teams"][2]["percentage"], 10.0)

    def test_pagination_handling(self):
        self.mock_table.scan.side_effect = [
            {
                "Items": [{"team_id": "Team One", "vote_count": Decimal("10")}],
                "LastEvaluatedKey": {"team_id": "Team One"},
            },
            {
                "Items": [{"team_id": "Team Two", "vote_count": Decimal("20")}],
            },
        ]

        event = {"httpMethod": "GET"}
        response = handler.lambda_handler(event)

        self.assertEqual(response["statusCode"], 200)
        body = json.loads(response["body"])
        self.assertEqual(body["total_votes"], 30)
        self.assertEqual(body["team_count"], 2)
        self.assertEqual(self.mock_table.scan.call_count, 2)

    def test_error_handling_on_scan_failure(self):
        self.mock_table.scan.side_effect = Exception("DynamoDB Read Throttle")

        event = {"httpMethod": "GET"}
        response = handler.lambda_handler(event)

        self.assertEqual(response["statusCode"], 500)
        body = json.loads(response["body"])
        self.assertIn("error", body)


if __name__ == "__main__":
    unittest.main()
