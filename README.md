# Event-Driven Cloud Platform (Serverless Reference Implementation)

A production-style reference implementation of an event-driven platform on AWS using **API Gateway + Lambda (TypeScript) + SQS + EventBridge + S3 + DynamoDB**, provisioned with **Terraform** and validated by CI.

This project is designed to demonstrate platform-grade concerns: **least-privilege IAM, idempotency, retries + DLQ, encryption, observability, and clean deployment workflows**.

## Architecture (High Level)

**Ingest → Persist → Queue → Process → Notify**

1. **API Gateway → Lambda (API)** receives an event and validates it.
2. Payload is stored in **S3 (bronze/raw)** and metadata in **DynamoDB**.
3. A message is enqueued to **SQS** for async processing.
4. **Lambda (Worker)** consumes messages, performs transformations, writes output to **S3 (silver/processed)**.
5. Worker emits a domain event to **EventBridge** for downstream consumers (future integrations).

See: `docs/architecture.md`.

## Repo layout
- `services/api` — API Lambda (TypeScript)
- `services/worker` — async worker Lambda (TypeScript)
- `infra/envs/dev` — Terraform for dev environment
- `docs/` — architecture, decisions (ADRs), demo, runbook
