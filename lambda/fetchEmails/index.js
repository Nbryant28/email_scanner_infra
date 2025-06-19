// index.js
const AWS = require("aws-sdk");
const fetch = require("node-fetch");

const s3 = new AWS.S3();
const dynamo = new AWS.DynamoDB.DocumentClient();

async function fetchEmails(token) {
  const res = await fetch("https://graph.microsoft.com/v1.0/me/messages?$top=5", {
    headers: { Authorization: `Bearer ${token}` },
  });

  const data = await res.json();
  console.log("📨 Fetched emails:", JSON.stringify(data, null, 2));
  return data.value || [];
}

async function fetchAttachments(token, messageId) {
  const res = await fetch(`https://graph.microsoft.com/v1.0/me/messages/${messageId}/attachments`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  const data = await res.json();
  console.log(`📎 Attachments for ${messageId}:`, JSON.stringify(data, null, 2));
  return data.value || [];
}

async function uploadToS3AndSaveMetadata(attachment, message) {
  const decoded = Buffer.from(attachment.contentBytes, "base64");
  const s3Key = `attachments/${message.id}/${attachment.name}`;

  await s3
    .putObject({
      Bucket: process.env.S3_BUCKET,
      Key: s3Key,
      Body: decoded,
      ContentType: attachment.contentType,
    })
    .promise();

  await dynamo
    .put({
      TableName: process.env.DYNAMODB_TABLE,
      Item: {
        id: `${message.id}-${attachment.id}`,
        userEmail: message.sender?.emailAddress?.address || "unknown",
        subject: message.subject,
        attachmentName: attachment.name,
        s3Key,
        timestamp: new Date().toISOString(),
      },
    })
    .promise();
}

exports.handler = async (event) => {
  console.log("📬 Lambda triggered");

  try {
    const body = JSON.parse(event.body || "{}");
    const token = body.accessToken;

    if (!token) {
      throw new Error("Missing access token");
    }

    const messages = await fetchEmails(token);

    for (const message of messages) {
      if (message.hasAttachments) {
        const attachments = await fetchAttachments(token, message.id);
        for (const attachment of attachments) {
          await uploadToS3AndSaveMetadata(attachment, message);
        }
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Emails processed ✅", emails: messages }),
    };
  } catch (err) {
    console.error("❌ Error:", err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message || "Processing failed" }),
    };
  }
};
