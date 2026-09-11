#!/usr/bin/env bash
# ==============================================================================
# Seed Initial Standings / Teams into DynamoDB
# ==============================================================================

set -euo pipefail

TABLE_NAME="${1:-resilient_votes}"
AWS_REGION="${2:-us-east-1}"

echo "==> Seeding initial teams into DynamoDB table: ${TABLE_NAME} in region ${AWS_REGION}..."

TEAMS=("Team Alpha" "Team Beta" "Team Gamma" "Team Delta")

for TEAM in "${TEAMS[@]}"; do
  echo "Seeding ${TEAM}..."
  aws dynamodb put-item \
    --table-name "${TABLE_NAME}" \
    --region "${AWS_REGION}" \
    --item "{\"team_id\": {\"S\": \"${TEAM}\"}, \"vote_count\": {\"N\": \"0\"}}"
done

echo "==> Initial candidate standings successfully initialized."