terraform {
  backend "s3" {
    bucket       = "practiseecs-app-tf-state-12345"
    key          = "environments/nodejs-app-prod.tfstate"
    region       = "ap-south-1"
    use_lockfile = true    # replaces dynamodb_table
    encrypt      = true
  }
}

provider "aws" {
  region = "ap-south-1"
}

data "aws_vpc" "vpc_default" {
  default = true
}