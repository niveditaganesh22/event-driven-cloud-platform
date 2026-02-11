# Demo

This document shows a simple end-to-end test of the platform using the API Gateway endpoint.

---

## API Gateway test

```powershell

Invoke-RestMethod `
  -Method POST `
  -Uri <api-url>/events `
  -ContentType "application/json" `
  -Body '{"eventType":"demo","message":"hello from apigw"}'

Expected result

HTTP 202 Accepted

Response contains an eventId

Raw event stored in S3 Bronze

Event processed and written to S3 Silver

DynamoDB status updated to PROCESSED