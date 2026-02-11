import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import {
  EventBridgeClient,
  PutEventsCommand,
} from "@aws-sdk/client-eventbridge";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const s3 = new S3Client({});
const eb = new EventBridgeClient({});
const ddbDoc = DynamoDBDocumentClient.from(new DynamoDBClient({}));

async function streamToString(body: any): Promise<string> {
  // AWS SDK v3 GetObjectCommand returns a stream in Node
  return await new Promise((resolve, reject) => {
    const chunks: any[] = [];
    body.on("data", (chunk: any) => chunks.push(chunk));
    body.on("error", reject);
    body.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
  });
}

export const handler = async (event: any) => {
  const SILVER_BUCKET = process.env.SILVER_BUCKET!;
  const EVENTS_TABLE = process.env.EVENTS_TABLE!;
  const EVENT_BUS_NAME = process.env.EVENT_BUS_NAME || "default";

  if (!SILVER_BUCKET || !EVENTS_TABLE) {
    throw new Error("Missing required env vars: SILVER_BUCKET or EVENTS_TABLE");
  }

  const records = event?.Records ?? [];
  console.log(
    JSON.stringify({ msg: "worker invoked", recordCount: records.length })
  );

  for (const record of records) {
    const msgBody = record?.body;
    if (!msgBody) {
      console.warn("Skipping record with empty body");
      continue;
    }

    const workItem = JSON.parse(msgBody);
    const { eventId, eventType, s3Bucket, s3Key } = workItem;

    if (!eventId || !eventType || !s3Bucket || !s3Key) {
      throw new Error(`Invalid work item: ${msgBody}`);
    }

    // 1) Read from S3 Bronze
    const obj = await s3.send(
      new GetObjectCommand({ Bucket: s3Bucket, Key: s3Key })
    );
    const raw = await streamToString(obj.Body);

    const payload = JSON.parse(raw);
    const processedAt = new Date().toISOString();

    // 2) “Process” (simple enrichment for v1)
    const processed = {
      ...payload,
      eventId,
      eventType,
      processedAt,
      source: "worker",
    };

    // 3) Write to S3 Silver
    const silverKey = `silver/${eventType}/${eventId}.json`;

    await s3.send(
      new PutObjectCommand({
        Bucket: SILVER_BUCKET,
        Key: silverKey,
        Body: JSON.stringify(processed),
        ContentType: "application/json",
      })
    );

    // 4) Update DynamoDB status
    await ddbDoc.send(
      new UpdateCommand({
        TableName: EVENTS_TABLE,
        Key: { pk: `EVENT#${eventId}` },
        UpdateExpression:
          "SET #status = :s, processedAt = :p, silverBucket = :b, silverKey = :k",
        ExpressionAttributeNames: { "#status": "status" },
        ExpressionAttributeValues: {
          ":s": "PROCESSED",
          ":p": processedAt,
          ":b": SILVER_BUCKET,
          ":k": silverKey,
        },
      })
    );

    // 5) Emit EventBridge event
    await eb.send(
      new PutEventsCommand({
        Entries: [
          {
            EventBusName: EVENT_BUS_NAME,
            Source: "edcp.worker",
            DetailType: "EventProcessed",
            Detail: JSON.stringify({
              eventId,
              eventType,
              bronze: { bucket: s3Bucket, key: s3Key },
              silver: { bucket: SILVER_BUCKET, key: silverKey },
              processedAt,
            }),
          },
        ],
      })
    );

    console.log(
      JSON.stringify({
        msg: "processed",
        eventId,
        eventType,
        s3Key,
        silverKey,
      })
    );
  }

  return { ok: true };
};
