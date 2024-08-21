terraform {
  backend "s3" {
    bucket         = "jobis-data-ai-sb-tfstate"
    key            = "services/dp-rdd.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "jobis-data-ai-sb-terraform-lock"
  }
}