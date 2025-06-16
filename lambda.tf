resource "aws_iam_role" "lambda_exec_role" {
  name = "EmailTrackerLambdaExecRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name = "EmailTrackerLambdaPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:GetItem"
        ],
        Resource = [
          aws_dynamodb_table.email_tracker_capsules.arn,
          "${aws_dynamodb_table.email_tracker_capsules.arn}/index/UserEmailIndex"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "${aws_s3_bucket.email_tracker_uploads.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}
resource "aws_lambda_function" "fetch_emails" {
  function_name = "FetchEmailsLambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  s3_bucket = "email-tracker-uploads"
  s3_key    = "lambda/fetchEmails/fetchEmails.zip"

  environment {
    variables = {
      AZURE_CLIENT_ID     = var.azure_client_id
      AZURE_CLIENT_SECRET = var.azure_client_secret
      AZURE_TENANT_ID     = var.azure_tenant_id
    }
  }
  layers = [aws_lambda_layer_version.fetch_emails_layer.arn]

}
resource "aws_lambda_layer_version" "fetch_emails_layer" {
  layer_name          = "fetchEmailsDependencies"
  compatible_runtimes = ["nodejs18.x"]

  s3_bucket = aws_s3_bucket.email_tracker_uploads.bucket
  s3_key    = "lambda/layer/layer.zip"

  source_code_hash = filebase64sha256("${path.module}/lambda/layer/layer.zip")
}

