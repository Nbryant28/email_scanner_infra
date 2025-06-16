// index.js
const AWS = require("aws-sdk");
const fetch = require("node-fetch");
const { ConfidentialClientApplication } = require("@azure/msal-node");

const s3 = new AWS.S3();
const dynamo = new AWS.DynamoDB.DocumentClient();

const msalConfig = {
  auth: {
    clientId: process.env.AZURE_CLIENT_ID,
    authority: `https://login.microsoftonline.com/${process.env.AZURE_TENANT_ID}`,
    clientSecret: process.env.AZURE_CLIENT_SECRET,
  },
};

const msalClient = new ConfidentialClientApplication(msalConfig);

async function getAccessToken() {
  const tokenRequest = {
    scopes: ["https://graph.microsoft.com/.default"],
  };

  const result = await msalClient.acquireTokenByClientCredential(tokenRequest);
  console.log("🔑 Access token acquired");
  return result.accessToken;
}

async function fetchEmails(token) {
  const userId = process.env.MSFT_USER_ID; // NEW: Explicit user ID
  const res = await fetch(`https://graph.microsoft.com/v1.0/users/${userId}/messages?$top=5`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  const data = await res.json();
  console.log("📨 Raw email fetch result:", JSON.stringify(data, null, 2));
  return data.value || [];
}

async function fetchAttachments(token, messageId) {
  const userId = process.env.MSFT_USER_ID;
  const res = await fetch(`https://graph.microsoft.com/v1.0/users/${userId}/messages/${messageId}/attachments`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  const data = await res.json();
  console.log(`📎 Attachments for message ${messageId}:`, JSON.stringify(data, null, 2));
  return data.value || [];
}

async function uploadToS3AndSaveMetadata(attachment, message) {
  const decoded = Buffer.from(attachment.contentBytes, "base64");
  const s3Key = `attachments/${message.id}/${attachment.name}`;

  console.log(`📤 Uploading to S3: ${s3Key}`);

  await s3
    .putObject({
      Bucket: process.env.S3_BUCKET,
      Key: s3Key,
      Body: decoded,
      ContentType: attachment.contentType,
    })
    .promise();

  console.log(`💾 Writing to DynamoDB for attachment: ${attachment.name}`);

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
  console.log("📬 Lambda triggered to fetch emails");

  try {
    const accessToken = await getAccessToken();
    const messages = await fetchEmails(accessToken);
    console.log("📥 Messages fetched:", JSON.stringify(messages, null, 2));

    for (const message of messages) {
      console.log(`📩 Subject: ${message.subject} | hasAttachments: ${message.hasAttachments}`);
      if (message.hasAttachments) {
        const attachments = await fetchAttachments(accessToken, message.id);
        for (const attachment of attachments) {
          await uploadToS3AndSaveMetadata(attachment, message);
        }
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Emails processed ✅" }),
    };
  } catch (err) {
    console.error("❌ Error:", err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "Processing failed" }),
    };
  }
};
