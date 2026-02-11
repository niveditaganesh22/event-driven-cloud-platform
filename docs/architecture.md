# Architecture

This document describes the architecture of the Event-Driven Cloud Platform and the reasoning behind the overall design.

The system follows a simple event-driven pattern commonly used in production environments to decouple ingestion from processing.

---

## High-level flow

1. A client sends an event payload via API Gateway
2. API Lambda receives the request
3. Raw payload is stored in S3 (Bronze layer)
4. Event metadata is written to DynamoDB
5. Event ID is pushed to SQS
6. Worker Lambda consumes messages from SQS and processes the event

---

## Components

### API Gateway
- Acts as the public entry point
- Accepts HTTP POST requests
- Proxies requests to the API Lambda

### API Lambda
- Performs basic validation
- Generates a unique event ID
- Stores raw payload in S3
- Writes event metadata to DynamoDB
- Enqueues event to SQS
- Returns `202 Accepted` to the caller

### DynamoDB
- Stores event metadata and lifecycle state
- Partition key format: `EVENT#<eventId>`
- Used to track processing status

### S3 (Bronze / Silver)
- Bronze bucket stores raw incoming events
- Silver bucket is reserved for processed output
- Enables replayability and auditing

### SQS + DLQ
- Decouples ingestion from processing
- Provides retry handling
- DLQ captures poison messages

### Worker Lambda
- Triggered by SQS
- Processes events asynchronously
- Updates DynamoDB and writes output to S3 Silver

---

## Design principles

- Loose coupling between ingestion and processing
- Durable storage before async processing
- Infrastructure fully managed via Terraform
- Minimal logic per component
