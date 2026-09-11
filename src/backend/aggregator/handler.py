"""
ResilientVote Aggregator Lambda Handler

Consumes batches of SQS vote messages, aggregates vote tallies per team
in-memory to eliminate row-level write contention, and writes the batch totals
to DynamoDB using atomic numeric increments (ADD expression).
Supports Partial Batch Response (ReportBatchItemFailures).
"""

import json
import logging
import os
from collections import defaultdict
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

_dynamodb_resource = None
_table = None


def get_dynamodb_table(table_name: Optional[str] = None):
    """Retrieve or initialize the DynamoDB Table resource."""
    global _dynamodb_resource, _table
    if _table is not None and table_name is None:
        return _table

    target_table_name = table_name or os.environ.get("TABLE_NAME", "resilient_votes")
    if _dynamodb_resource is None:
        try:
            import boto3
            _dynamodb_resource = boto3.resource("dynamodb")
        except ImportError:
            logger.warning("boto3 not installed in local environment.")
            return None

    _table = _dynamodb_resource.Table(target_table_name)
    return _table


def set_dynamodb_table(table_mock):
    """Explicitly set the DynamoDB table instance (used for testing/dependency injection)."""
    global _table
    _table = table_mock


def parse_record_body(body_str: str) -> Dict[str, Any]:
    """
    Safely parse record body which may be raw JSON, URL-encoded string,
    or double-encoded from API Gateway.
    """
    if not body_str or not isinstance(body_str, str):
        raise ValueError("Empty or invalid body string")

    parsed = json.loads(body_str)
    if isinstance(parsed, str):
        parsed = json.loads(parsed)
    if not isinstance(parsed, dict):
        raise ValueError("Parsed body is not a JSON object")
    return parsed


def extract_vote_info(payload: Dict[str, Any]) -> tuple[str, int]:
    """
    Extract team/candidate identifier and vote count from payload.
    Supports 'team_id', 'team', or 'candidate_id'.
    Defaults vote count to 1 if not explicitly passed or if invalid.
    """
    team_id = (
        payload.get("team_id")
        or payload.get("team")
        or payload.get("candidate_id")
    )

    if not team_id or not isinstance(team_id, str) or not team_id.strip():
        raise ValueError("Payload missing valid 'team_id' or 'candidate_id'")

    team_id = team_id.strip()

    raw_votes = payload.get("votes", payload.get("count", 1))
    try:
        votes = int(raw_votes)
        if votes <= 0:
            votes = 1
    except (ValueError, TypeError):
        votes = 1

    return team_id, votes


def lambda_handler(event: Dict[str, Any], context: Any = None) -> Dict[str, Any]:
    """
    SQS Event Consumer.
    Aggregates votes in memory and executes atomic increments on DynamoDB.
    Returns partial batch failure report if any record fails.
    """
    records = event.get("Records", [])
    logger.info("Received batch of %d records", len(records))

    if not records:
        return {"batchItemFailures": []}

    batch_item_failures: List[Dict[str, str]] = []
    team_vote_totals: Dict[str, int] = defaultdict(int)
    team_message_ids: Dict[str, List[str]] = defaultdict(list)

    for record in records:
        message_id = record.get("messageId", "unknown")
        body_str = record.get("body", "")

        try:
            payload = parse_record_body(body_str)
            team_id, vote_count = extract_vote_info(payload)
            team_vote_totals[team_id] += vote_count
            team_message_ids[team_id].append(message_id)
        except Exception as err:
            logger.error("Failed to parse record %s: %s", message_id, str(err))
            batch_item_failures.append({"itemIdentifier": message_id})

    table = get_dynamodb_table()
    if table is None:
        logger.error("DynamoDB Table instance not available")
        for record in records:
            msg_id = record.get("messageId", "unknown")
            if not any(f["itemIdentifier"] == msg_id for f in batch_item_failures):
                batch_item_failures.append({"itemIdentifier": msg_id})
        return {"batchItemFailures": batch_item_failures}

    for team_id, aggregated_count in team_vote_totals.items():
        try:
            logger.info("Writing atomic increment: team=%s, count=+%d", team_id, aggregated_count)
            table.update_item(
                Key={"team_id": team_id},
                UpdateExpression="ADD vote_count :val",
                ExpressionAttributeValues={":val": aggregated_count},
                ReturnValues="UPDATED_NEW",
            )
        except Exception as err:
            logger.error(
                "DynamoDB atomic update failed for team %s (+%d): %s",
                team_id,
                aggregated_count,
                str(err),
            )
            for msg_id in team_message_ids[team_id]:
                if not any(f["itemIdentifier"] == msg_id for f in batch_item_failures):
                    batch_item_failures.append({"itemIdentifier": msg_id})

    return {"batchItemFailures": batch_item_failures}
