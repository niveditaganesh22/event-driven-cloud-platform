### API Gateway test (final)
```powershell
Invoke-RestMethod `
  -Method POST `
  -Uri <api-url>/events `
  -ContentType "application/json" `
  -Body '{"eventType":"demo","message":"hello from apigw"}'

### Expected: 202 accepted, eventId returned, data appears in silver S3.


