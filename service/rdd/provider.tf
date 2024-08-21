provider "aws" {
  default_tags {
    tags = {
      Application = "scar"
      Environment = "sb"
      Owner       = "data"
      Project     = "scar"
      Service     = "data"
      Team        = "data"
    }
  }
}