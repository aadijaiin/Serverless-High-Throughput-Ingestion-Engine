"""
ResilientVote Results Lambda Handler

Serves the real-time scoreboard data by querying DynamoDB for current vote totals,
calculating aggregate statistics and percentages, and returning a cached/formatted
JSON payload with full CORS support.
"""

import json
import logging
import os
import time
from decimal import Decimal
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


class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder to serialize DynamoDB Decimal types."""
    def default(self, o: Any):
        if isinstance(o, Decimal):
            if o % 1 == 0:
                return int(o)
            return float(o)
        return super().default(o)


def build_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Format an HTTP response with permissive CORS headers for dashboard polling."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Requested-With",
            "Cache-Control": "no-cache, no-store, must-revalidate",
        },
        "body": json.dumps(body, cls=DecimalEncoder),
    }


def lambda_handler(event: Dict[str, Any], context: Any = None) -> Dict[str, Any]:
    """
    Handle incoming GET /results requests and return aggregated scoreboard data.
    """
    http_method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod", "GET")
    )

    if http_method.upper() == "OPTIONS":
        return build_response(200, {"message": "OK"})

    table = get_dynamodb_table()
    if table is None:
        logger.error("DynamoDB Table instance not available")
        return build_response(500, {"error": "Internal database error"})

    try:
        response = table.scan()
        items = response.get("Items", [])

        while "LastEvaluatedKey" in response:
            response = table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
            items.extend(response.get("Items", []))

        teams: List[Dict[str, Any]] = []
        total_votes = 0

        for item in items:
            team_id = str(item.get("team_id", "Unknown"))
            raw_votes = item.get("vote_count", 0)
            votes = int(raw_votes) if isinstance(raw_votes, (int, Decimal, float)) else 0
            total_votes += votes
            teams.append({
                "team_id": team_id,
                "vote_count": votes,
            })

        teams.sort(key=lambda x: x["vote_count"], reverse=True)
        for t in teams:
            t["percentage"] = (
                round((t["vote_count"] / total_votes) * 100, 2)
                if total_votes > 0
                else 0.0
            )

        leader = teams[0]["team_id"] if teams and total_votes > 0 else None

        result_payload = {
            "status": "success",
            "timestamp": time.time(),
            "total_votes": total_votes,
            "leader": leader,
            "team_count": len(teams),
            "teams": teams,
        }

        return build_response(200, result_payload)

    except Exception as err:
        logger.exception("Error querying scoreboard results: %s", str(err))
        return build_response(500, {"error": "Failed to retrieve scoreboard data", "details": str(err)})
