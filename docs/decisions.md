# Decisions

This file captures a few intentional choices made while building the platform.

---

### Event-driven design

The platform uses an event-driven flow to separate ingestion from processing.  
This keeps the API fast and avoids tight coupling between components.

---

### SQS between API and worker

SQS is used instead of directly invoking the worker Lambda.

This allows retries, buffering, and failure isolation without adding complexity to the API layer.

---

### Raw events stored in S3

Incoming events are written to S3 before any processing.

This provides a simple audit trail and makes it possible to replay events if needed.

---

### DynamoDB for event tracking

DynamoDB is used only for metadata and state tracking, not for storing payloads.

This keeps reads cheap and avoids overloading the database.

---

### Terraform for infrastructure

All infrastructure is defined using Terraform to keep the setup reproducible and versioned.

Manual console changes are intentionally avoided.
