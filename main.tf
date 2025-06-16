resource "aws_dynamodb_table" "email_tracker_capsules" {
  name           = "EmailCapsules"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "userEmail"
    type = "S"
  }

  global_secondary_index {
    name            = "UserEmailIndex"
    hash_key        = "userEmail"
    projection_type = "ALL"
  }
}
resource "aws_s3_bucket" "email_tracker_uploads" {
  bucket = "email-tracker-uploads"

  tags = {
    Project = "EmailTracker"
    Environment = "dev"
  }

  force_destroy = true # ⚠️ Destroys bucket even if non-empty (remove in production)
}

# Optional: Block all public access (recommended)
resource "aws_s3_bucket_public_access_block" "email_tracker_uploads_block" {
  bucket = aws_s3_bucket.email_tracker_uploads.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

# Optional: Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "email_tracker_uploads_encryption" {
  bucket = aws_s3_bucket.email_tracker_uploads.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Optional but useful: Versioning
resource "aws_s3_bucket_versioning" "email_tracker_uploads_versioning" {
  bucket = aws_s3_bucket.email_tracker_uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}
# This Terraform configuration sets up an S3 bucket and a DynamoDB table for the Email Tracker project.
//All raw email attachments from your tracked inbox — in a secure, scalable, and cheap way — while your database (DynamoDB) just stores metadata + links.
