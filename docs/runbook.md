# Runbook

This document describes common operational tasks and checks for the platform.

---

## Verify platform health

### 1. API availability
- Send a POST request to the API Gateway endpoint
- Expect HTTP 202 response

### 2. Lambda execution
- Check CloudWatch logs for API and Worker Lambdas
- Ensure no unhandled runtime errors

### 3. DynamoDB
- Confirm event records exist
- Verify `status` field transitions as expected

### 4. SQS
- Check ApproximateNumberOfMessages
- Ensure messages are being consumed
- Inspect DLQ if failures occur

### 5. S3
- Confirm raw events are written to Bronze
- Confirm processed output (if enabled) appears in Silver

---

## Common issues

### Messages stuck in SQS
- Check worker Lambda permissions
- Verify event source mapping is enabled
- Inspect CloudWatch logs

### Events not appearing in DynamoDB
- Check API Lambda IAM role
- Confirm table name and environment variables

### Lambda errors
- Review CloudWatch logs
- Verify handler paths and build artifacts

---

## Cleanup

To tear down all resources:

```bash
terraform destroy
