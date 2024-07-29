terraform {
  backend "s3" {
    bucket         = "jobis-data-ai-stg-tfstate"
    key            = "init.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "jobis-data-ai-stg-terraform-lock"
  }
}
