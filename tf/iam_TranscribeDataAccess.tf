resource "aws_iam_role" "TranscribeDataAccess" {
  name               = "${var.iam_role_prefix}TranscribeDataAccess"
  description        = "signage-app TranscribeDataAccess"
  assume_role_policy = data.aws_iam_policy_document.TranscribeDataAccess-trust.json
}

data "aws_iam_policy_document" "TranscribeDataAccess-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "transcribe.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "TranscribeDataAccess" {
  role   = aws_iam_role.TranscribeDataAccess.name
  policy = data.aws_iam_policy_document.TranscribeDataAccess.json
}

data "aws_iam_policy_document" "TranscribeDataAccess" {
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::rubykaigi-custom-vocabs",
      "arn:aws:s3:::rubykaigi-custom-vocabs/*",
    ]
  }
}

