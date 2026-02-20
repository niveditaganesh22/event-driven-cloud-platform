Event-Driven Cloud Platform

AWS • Serverless • Terraform

This is a small but production-style event-driven platform built on AWS using Terraform and TypeScript.

The goal of this project was to practice and demonstrate common cloud patterns used in real systems: event ingestion, durable storage, asynchronous processing, and infrastructure managed entirely as code.

What this project does

At a high level, the platform accepts an event, stores it safely, and queues it for downstream processing.

Flow:

An API Lambda receives an event payload

The raw payload is stored in S3 (Bronze layer)

Event metadata is written to DynamoDB

The event is pushed to an SQS queue

A worker Lambda (SQS-triggered) processes the event (currently minimal logic)

This mirrors how many real systems decouple ingestion from processing for reliability and scale.

Tech stack

AWS Lambda (TypeScript)

Amazon S3 (Bronze / Silver pattern)

Amazon DynamoDB (event metadata & state)

Amazon SQS + Dead Letter Queue

Terraform (Infrastructure as Code)

GitHub Actions (basic CI)

## Architecture overview

Client → API Lambda → (S3 Bronze + DynamoDB) → SQS → Worker Lambda → DLQ

## Repository structure

infra/ (Terraform) • services/api (Lambda) • services/worker (Lambda) • docs/ • .github/workflows/

## Current status

✅ End-to-end ingestion working (API Gateway → S3/DynamoDB → SQS → Worker)

Prerequisites

Node.js 20+

AWS CLI v2

Terraform 1.6+

AWS credentials configured locally

This project uses an AWS CLI profile named dev.

Verify access:

aws sts get-caller-identity --profile dev

Build and deploy (dev)
Build the API Lambda
cd services/api
npm install
npm run build

Deploy infrastructure
cd ../../infra/envs/dev
terraform init
terraform apply

Testing the platform
1. Invoke the API Lambda directly

This simulates an API Gateway request.

aws lambda invoke \
  --function-name event-driven-cloud-platform-dev-api \
  --cli-binary-format raw-in-base64-out \
  --payload '{"body":"{\"eventType\":\"demo\",\"message\":\"hello\"}"}' \
  --profile dev \
  response.json


View the response:

type response.json


Expected output:

{
  "statusCode": 202,
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"status\":\"accepted\",\"eventId\":\"<uuid>\"}"
}

2. Verify DynamoDB entry
aws dynamodb get-item \
  --table-name event-driven-cloud-platform-dev-events \
  --key '{"pk":{"S":"EVENT#<eventId>"}}' \
  --profile dev


Expected:

eventType = demo

status = ENQUEUED

S3 bucket and object key present

3. Verify SQS
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --profile dev


Expected:

Messages visible or recently processed

4. Verify S3 (Bronze layer)
aws s3 ls s3://<bronze-bucket>/bronze/demo/ --profile dev


Expected:

JSON file containing the raw event payload

Operational notes

SQS decouples ingestion from processing

DynamoDB tracks event lifecycle state

S3 provides durability, replay, and auditability

DLQ captures failed messages for inspection

All infrastructure is reproducible via Terraform

Cleanup

To avoid ongoing AWS costs:

cd infra/envs/dev
terraform destroy


The entire platform can be recreated from code at any time.

Planned enhancements

Expand worker Lambda processing logic

S3 Silver processing layer

EventBridge integration

CloudWatch alarms and log retention

Stronger CI checks
