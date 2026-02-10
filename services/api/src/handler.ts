import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import crypto from "crypto";

const s3 = new S3Client({});
const sqs = new SQSClient({});
const ddbDoc = DynamoDBDocumentClient.from(new DynamoDBClient({}));

function jsonResponse(statusCode: number, body: unknown) {
  return {
    statusCode,
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  };
}

export const handler = async (event: any) => {
  try {
    const BRONZE_BUCKET = process.env.BRONZE_BUCKET!;
    const EVENTS_TABLE = process.env.EVENTS_TABLE!;
    const QUEUE_URL = process.env.QUEUE_URL!;

    if (!BRONZE_BUCKET || !EVENTS_TABLE || !QUEUE_URL) {
      return jsonResponse(500, {
        error: "Missing required environment variables",
      });
    }

    const rawBody = event?.body ?? "{}";
    const payload = typeof rawBody === "string" ? JSON.parse(rawBody) : rawBody;

    // Simple validation: require eventType
    if (!payload?.eventType || typeof payload.eventType !== "string") {
      return jsonResponse(400, { error: "eventType is required (string)" });
    }

    const eventId = crypto.randomUUID();
    const nowIso = new Date().toISOString();

    const s3Key = `bronze/${payload.eventType}/${eventId}.json`;

    // 1) Store raw payload in S3 (bronze)
    await s3.send(
      new PutObjectCommand({
        Bucket: BRONZE_BUCKET,
        Key: s3Key,
        Body: JSON.stringify(payload),
        ContentType: "application/json",
      })
    );

    // 2) Store metadata in DynamoDB
    await ddbDoc.send(
      new PutCommand({
        TableName: EVENTS_TABLE,
        Item: {
          pk: `EVENT#${eventId}`,
          eventId,
          eventType: payload.eventType,
          s3Bucket: BRONZE_BUCKET,
          s3Key,
          status: "ENQUEUED",
          createdAt: nowIso,
        },
      })
    );

    // 3) Enqueue work item to SQS
    await sqs.send(
      new SendMessageCommand({
        QueueUrl: QUEUE_URL,
        MessageBody: JSON.stringify({
          eventId,
          eventType: payload.eventType,
          s3Bucket: BRONZE_BUCKET,
          s3Key,
        }),
      })
    );

    console.log(
      JSON.stringify(
        {
          msg: "event accepted",
          eventId,
          eventType: payload.eventType,
          s3Key,
        },
        null,
        2
      )
    );

    return jsonResponse(202, { status: "accepted", eventId });
  } catch (err: any) {
    console.error("error handling request", err);
    return jsonResponse(500, { error: "Internal error" });
  }
};
