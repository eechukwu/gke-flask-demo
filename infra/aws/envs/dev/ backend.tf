terraform {
  backend "s3" {
    bucket  = "devops-interview-lab-tfstate"
    key     = "aws/dev/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}