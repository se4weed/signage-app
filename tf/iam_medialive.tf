resource "aws_iam_role" "Medialive" {
  name                 = "${var.iam_role_prefix}Medialive"
  description          = "signage-app Medialive"
  assume_role_policy   = data.aws_iam_policy_document.Medialive-trust.json
  max_session_duration = 43200
}

data "aws_iam_policy_document" "Medialive-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "medialive.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "Medialive" {
  role   = aws_iam_role.Medialive.name
  policy = data.aws_iam_policy_document.Medialive.json
}

data "aws_iam_policy_document" "Medialive" {
  statement {
    effect = "Allow"
    actions = [
      "mediastore:ListContainers",
      "mediastore:PutObject",
      "mediastore:GetObject",
      "mediastore:DeleteObject",
      "mediastore:DescribeObject",
      "mediapackage:DescribeChannel",
      "mediaconnect:ManagedDescribeFlow",
      "mediaconnect:ManagedAddOutput",
      "mediaconnect:ManagedRemoveOutput",
      "ec2:DescribeSubnets",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteNetworkInterfacePermission",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeAddresses",
      "ec2:AssociateAddress",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.captioner_params.medialive_s3_bucket}", "arn:aws:s3:::${var.captioner_params.medialive_s3_bucket}/${var.captioner_params.medialive_s3_prefix}*"]
  }
}

# kore iru?
resource "aws_iam_role_policy_attachment" "Medialive-ssm" {
  role       = aws_iam_role.Medialive.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}
