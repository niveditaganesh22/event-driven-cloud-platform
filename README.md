# Event-Driven Cloud Platform

**AWS • Serverless • Terraform • TypeScript**

This project is a small but production-style event-driven platform built on AWS.  
I built it to model how real systems handle ingestion, durability, and asynchronous processing — with infrastructure managed entirely as code.

The focus here is not just a Lambda demo, but a system that mirrors real-world event-driven design patterns.

---

## What This Project Does

At a high level, the platform accepts an event, stores it safely, and queues it for downstream processing.

### Flow

1. An **API Lambda** receives an event payload  
2. The raw payload is stored in **Amazon S3 (Bronze layer)**  
3. Event metadata is written to **DynamoDB**  
4. The event is pushed to an **SQS queue**  
5. A **Worker Lambda (SQS-triggered)** processes the event  

This reflects how production systems decouple ingestion from processing for reliability and scalability.

---

## Tech Stack

- **AWS Lambda** (TypeScript)
- **Amazon S3** (Bronze / future Silver layering)
- **Amazon DynamoDB** (event metadata & lifecycle state)
- **Amazon SQS + Dead Letter Queue**
- **Terraform** (Infrastructure as Code)
- **GitHub Actions** (basic CI)

---

## Architecture Overview


Client
↓
API Lambda
├── S3 (Bronze – raw events)
├── DynamoDB (event metadata)
└── SQS Queue
├── Worker Lambda
└── Dead Letter Queue


**Pipeline summary:**  
Ingest → Persist → Queue → Process

---

## Repository Structure


.
├── infra/
│ └── envs/dev/ # Terraform (dev environment)
├── services/
│ ├── api/ # API Lambda (TypeScript)
│ └── worker/ # Worker Lambda
├── docs/ # Architecture notes & demo steps
├── .github/workflows/ # CI
└── README.md


---

## Prerequisites

- Node.js 20+
- AWS CLI v2
- Terraform 1.6+
- AWS credentials configured locally

This project uses an AWS CLI profile named `dev`.

Verify access:

```bash```
aws sts get-caller-identity --profile dev

## Build and Deploy (dev)

### 1. Build the API Lambda

```bash```
cd services/api
npm install
npm run build

### 2. Deploy Infrastructure
```bash```
cd ../../infra/envs/dev
terraform init
terraform apply

## Testing the Platform
### 1. Invoke the API Lambda

This simulates an API Gateway request.
```bash```
aws lambda invoke \
  --function-name event-driven-cloud-platform-dev-api \
  --cli-binary-format raw-in-base64-out \
  --payload '{"body":"{\"eventType\":\"demo\",\"message\":\"hello\"}"}' \
  --profile dev \
  response.json

View the response:
```bash```
type response.json

Expected output:

```JSON```
{
  "statusCode": 202,
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"status\":\"accepted\",\"eventId\":\"<uuid>\"}"
}
### 2. Verify DynamoDB Entry
```bash```
aws dynamodb get-item \
  --table-name event-driven-cloud-platform-dev-events \
  --key '{"pk":{"S":"EVENT#<eventId>"}}' \
  --profile dev

Expected:

eventType = demo

status = ENQUEUED

S3 bucket and object key present

### 3. Verify SQS
```bash```
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --profile dev

Expected:

Messages visible or recently processed

### 4. Verify S3 (Bronze Layer)
aws s3 ls s3://<bronze-bucket>/bronze/demo/ --profile dev

Expected:

JSON file containing the raw event payload

## Operational Notes

SQS decouples ingestion from processing

DynamoDB tracks event lifecycle state

S3 provides durability, replay, and auditability

DLQ captures failed messages for inspection

All infrastructure is reproducible via Terraform

## Cleanup

To avoid ongoing AWS costs:
```bash```
cd infra/envs/dev
terraform destroy

The entire platform can be recreated from code at any time.

### Planned Enhancements

Expand worker Lambda processing logic

Introduce S3 Silver processing layer

EventBridge integration

CloudWatch alarms and log retention policies

Stronger CI validation checks


---
