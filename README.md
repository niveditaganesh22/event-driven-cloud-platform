Event-Driven Cloud Platform (AWS | Serverless | Terraform)

A production-style event-driven serverless platform built on AWS using Terraform and TypeScript.

This project demonstrates reliable event ingestion, durable persistence, and asynchronous processing using managed AWS services — mirroring real-world cloud platform patterns used in large-scale systems.

Tech Stack

AWS Lambda (TypeScript)

Amazon S3 (Bronze / Silver pattern)

Amazon DynamoDB (event metadata)

Amazon SQS + Dead Letter Queue (asynchronous processing)

Terraform (Infrastructure as Code)

GitHub Actions (CI)

Architecture Overview

Ingest → Persist → Queue → Process

API Lambda receives an event payload

Raw payload is stored in S3 Bronze

Event metadata is written to DynamoDB

Event is enqueued to SQS

(Planned) Worker Lambda processes the event and writes to S3 Silver

flowchart LR
  A[Client] --> L1[API Lambda]
  L1 --> B[S3 Bronze]
  L1 --> D[DynamoDB Events Table]
  L1 --> Q[SQS Queue]
  Q --> L2[Worker Lambda (planned)]
  L2 --> S[S3 Silver (planned)]
  Q --> DLQ[SQS Dead Letter Queue]

Repository Structure
.
├── infra/
│   └── envs/dev/          # Terraform (dev environment)
├── services/
│   ├── api/               # API Lambda (TypeScript)
│   └── worker/            # Worker Lambda (planned)
├── docs/                  # Architecture & runbooks
├── .github/workflows/     # CI
└── README.md

Current Status

✅ Infrastructure provisioned using Terraform

✅ API Lambda deployed

✅ End-to-end ingestion verified:

Lambda → S3 → DynamoDB → SQS

⏳ Worker Lambda (next)

⏳ API Gateway (next)

Prerequisites

Node.js 20+

AWS CLI v2

Terraform 1.6+

AWS credentials configured locally
(AWS CLI profile used: dev)

Verify AWS access:

aws sts get-caller-identity --profile dev

Build and Deploy (Dev)
Build API Lambda
cd services\api
npm install
npm run bundle

Deploy Infrastructure
cd ..\..\infra\envs\dev
terraform init
terraform apply

Test the Platform (Direct Lambda Invocation)

This simulates an API Gateway-style request.

Invoke API Lambda
aws lambda invoke `
  --function-name event-driven-cloud-platform-dev-api `
  --cli-binary-format raw-in-base64-out `
  --payload '{"body":"{\"eventType\":\"demo\",\"message\":\"hello\"}"}' `
  --profile dev `
  response.json

View Response
type response.json

Expected Result
{
  "statusCode": 202,
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"status\":\"accepted\",\"eventId\":\"<uuid>\"}"
}

Verify Data Flow
DynamoDB (Event Metadata)
aws dynamodb get-item `
  --table-name event-driven-cloud-platform-dev-events `
  --key '{"pk":{"S":"EVENT#<eventId>"}}' `
  --profile dev


Expected:

eventType = demo

status = ENQUEUED

s3Bucket and s3Key populated

SQS (Asynchronous Queue)
aws sqs get-queue-attributes `
  --queue-url <queue-url> `
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible `
  --profile dev


Expected:

{
  "ApproximateNumberOfMessages": "1",
  "ApproximateNumberOfMessagesNotVisible": "0"
}

S3 Bronze Layer
aws s3 ls s3://<bronze-bucket>/bronze/demo/ --profile dev


Expected:

JSON file containing the raw event payload

Operational Notes

SQS decouples ingestion from downstream processing

DynamoDB tracks event lifecycle state

S3 enables replayability and auditability

DLQ captures poison messages

All infrastructure is provisioned and tagged using Terraform

Cleanup

To avoid ongoing AWS costs:

cd infra\envs\dev
terraform destroy


The platform is fully reproducible from code after cleanup.

Planned Enhancements

Worker Lambda (SQS-triggered)

S3 Silver processing layer

EventBridge event publishing

API Gateway HTTP endpoint

CloudWatch alarms and log retention