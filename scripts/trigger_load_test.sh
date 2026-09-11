#!/usr/bin/env bash
# ==============================================================================
# Trigger Distributed Load Test Across EC2 Fleet via AWS Systems Manager (SSM)
# ==============================================================================

set -euo pipefail

VUS="${1:-250}"
DURATION="${2:-60s}"

echo "==> Triggering distributed k6 load test via AWS Systems Manager..."
echo "==> Target VUs per node: ${VUS}, Duration: ${DURATION}"

aws ssm send-command \
  --targets "Key=tag:Role,Values=load-generator" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"k6 run --vus ${VUS} --duration ${DURATION} /home/ubuntu/load_test.js\"]"

echo "==> SSM command sent to all load-generator fleet nodes."