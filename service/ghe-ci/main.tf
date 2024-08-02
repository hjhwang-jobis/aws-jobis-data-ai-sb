resource "aws_iam_role" "github-runner-tfwork-role" {
  name = "github-runner-tfwork-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "arn:aws:iam::185236431346:role/ghe-ci-linux-x64-tfwork/ghe-ci-linux-x64-tfwork-runner-role"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "tfwork_deny_policy" {
  statement {
    effect = "Deny"

    # actions = [
    #   "*",
    # ]
    not_actions = [
      "kms:Decrypt",
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "StringNotLike"
      variable = "aws:userAgent"
      values = [
        "*Terraform/*",
        "*OpenTofu/*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "tfwork_deny_policy" {
  name = "deny_not_terraform_policy"
  role = aws_iam_role.github-runner-tfwork-role.id

  policy = data.aws_iam_policy_document.tfwork_deny_policy.json
}

resource "aws_iam_role_policy_attachment" "tfwork_administrator_attach" {
  role       = aws_iam_role.github-runner-tfwork-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
