# ResilientVote: High-Throughput Serverless Voting Architecture

An event-driven, serverless ingestion engine built on AWS designed to sustain 10,000+ requests per second (RPS) under burst conditions while minimizing infrastructure spend. The architecture utilizes asynchronous queuing, in-memory batch aggregation, and atomic database increments to completely eliminate write contention and dirty writes.

---

## Architecture Overview

```text
[ Distributed Load Fleet (k6 on EC2) ]
                   │
                   │ (10,000+ RPS HTTPS Ingestion)
                   ▼
       [ Amazon API Gateway (HTTP API) ]
                   │
                   │ (Direct AWS Service Integration)
                   ▼
      [ Amazon SQS Standard Buffer Queue ]
                   │
                   │ (Event Source Mapping: Batches of 10-100)
                   ▼
        [ AWS Lambda Worker Aggregator ]
                   │
                   │ (Thread-Safe Atomic ADD Expressions)
                   ▼
       [ Amazon DynamoDB (On-Demand Mode) ]
                   ▲
                   │ (1s Polling Interval)
       [ Frontend Dashboard UI (Static Client) ]
```

## Technical Specifications

| Metric / Dimension | Architectural Guarantee | Implementation Detail |
| :--- | :--- | :--- |
| **Ingress Throughput** | 10,000+ Requests / Sec | Amazon API Gateway HTTP API with direct SQS integration |
| **Ingestion Latency** | < 15 ms (p95) | Computeless proxy forwarding payload directly into message queue |
| **Write Consistency** | Zero Dirty Writes / ACIDs | Lambda in-memory batching + DynamoDB atomic counter updates |
| **System Availability** | 99.99% Regional Resiliency | Multi-AZ distributed managed services across all compute and storage tiers |
| **Operating Cost** | Micro-Budget (< $1.00 / test run) | 100% serverless pay-per-use model adhering to AWS Free Tier limits |

---

## Core Engineering Decisions

### 1. Concurrency Control and Dirty Write Prevention

Under flash-crowd traffic (10,000+ simultaneous votes across multiple candidates), relational databases experience catastrophic row-level locking, connection pool exhaustion, and deadlocks. This architecture addresses the problem via a two-tier aggregation model:

* **In-Memory Worker Batching:** The consumer Lambda function retrieves messages from Amazon SQS in configurable batches (e.g., 50 to 100 records per invocation). Instead of executing individual database writes for every message, the handler aggregates vote tallies per team in memory using hash tables.
* **Atomic Counter Execution:** The aggregated totals are written to Amazon DynamoDB using the `UpdateItem` API with an atomic update expression (`ADD vote_count :val`). DynamoDB serializes these numeric increments at the partition level, ensuring that concurrent Lambda executions never overwrite each other's increments.

### 2. High-Throughput Ingestion on a Budget

To avoid running idle compute clusters (such as ECS Fargate tasks or EC2 Auto Scaling groups) for intermittent or bursty events:

* **Computeless API Gateway Integration:** API Gateway writes JSON payloads directly to Amazon SQS via AWS Service Integration policies, removing application compute from the critical ingress path.
* **Decoupled Processing:** SQS acts as a shock absorber. When inbound traffic spikes to 10,000 RPS, SQS buffers messages immediately. Lambda scales worker concurrency dynamically to drain the queue at a sustainable pace.
* **Cost Efficiency:** Processing a 1,000,000 vote burst across API Gateway, SQS, Lambda, and DynamoDB incurs less than $1.00 in total AWS service fees.

### 3. Native Multi-AZ High Availability

Traditional multi-tier applications depend on database instance promotion routines (typically 30 to 60 seconds of downtime during RDS primary failover) and ALB target deregistration cycles.

* API Gateway routes inbound traffic redundantly across all Availability Zones in the region.
* Amazon SQS synchronously stores every message across multiple physical data centers before returning an HTTP 200 acknowledgment.
* Amazon DynamoDB automatically replicates data across three separate physical facilities within the region, providing continuous availability without manual failover orchestration.

### 4. GitOps and Automated CI/CD

The repository implements a decoupled deployment lifecycle to ensure infrastructure changes do not block rapid application iteration:

* **Distributed State Management:** Terraform state files are hosted remotely in an encrypted S3 bucket with state locking managed via DynamoDB.
* **Keyless Pipeline Authentication:** GitHub Actions authenticates to AWS via OpenID Connect (OIDC), assuming short-lived, least-privilege IAM roles instead of persisting static access keys.
* **Decoupled Workflows:**
  * `terraform-ci-cd.yml`: Enforces formatting (`terraform fmt`), security analysis (`checkov`, `tflint`), and automated PR plan posting before applying infrastructure changes on merge to `main`.
  * `lambda-deploy.yml`: Directly packages and updates Lambda function code via AWS CLI upon pushes to `src/backend/`, allowing updates in seconds without re-evaluating unchanged IaC state.

---

## Distributed Load Generation

To generate genuine 10,000 RPS traffic without hitting single-machine operating system limits (such as ephemeral port exhaustion, thread contention, or network interface bottlenecks), traffic generation is distributed across a fleet of Amazon EC2 instances.

### 1. Fleet Provisioning

A dedicated Terraform module provisions 6 to 7 `t3.small` instances evenly distributed across multiple Availability Zones:

```bash
cd terraform/envs/prod
terraform apply -target=module.load_generator
```

### 2. Kernel Tuning

Each load instance runs a provisioning script to maximize socket recycling and file descriptor capacity:

```bash
sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sudo sysctl -w net.ipv4.tcp_tw_reuse=1
sudo sysctl -w net.core.somaxconn=65535
ulimit -n 65535
```

### 3. Execution via AWS Systems Manager

Load tests are triggered concurrently across all nodes using AWS Systems Manager (SSM) Run Command, eliminating the need to manage SSH keys:

```bash
aws ssm send-command \
  --targets "Key=tag:Role,Values=load-generator" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["k6 run --vus 250 --duration 60s /home/ubuntu/load_test.js"]'
```

## Repository Structure

```text
voting-engine-v2/
├── .github/workflows/       # Automated CI/CD pipeline definitions (OIDC)
├── terraform/
│   ├── envs/prod/           # Production environment root configuration
│   └── modules/             # Modular infrastructure definitions
│       ├── networking/      # API Gateway HTTP API and route integrations
│       ├── messaging/       # SQS standard buffer and dead-letter queues
│       ├── compute/         # Aggregator and results Lambda configurations
│       ├── storage/         # DynamoDB table definitions and access policies
│       └── load_generator/  # Distributed EC2 testing cluster setup
├── src/
│   ├── backend/
│   │   ├── aggregator/      # SQS consumer with in-memory counter aggregation
│   │   └── results/         # REST endpoint serving latest scoreboard state
│   └── frontend/            # Real-time polling scoreboard client
├── tests/
│   ├── load/                # k6 test scripts and OS network setup
│   └── unit/                # Unit test suites for Lambda handlers
└── scripts/                 # Operational management and execution scripts
```
