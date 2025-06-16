resource "aws_iam_role" "app_execution_role" {
  name = "EmailTrackerAppRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com" # can leave for future workflows
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "app_policy" {
  name = "EmailTrackerAppPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:DeleteItem"
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
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "${aws_s3_bucket.email_tracker_uploads.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_attachment" {
  role       = aws_iam_role.app_execution_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}
output "iam_role_arn" {
  value = aws_iam_role.app_execution_role.arn
}
