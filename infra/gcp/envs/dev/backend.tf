terraform {
  backend "gcs" {
    bucket = "k8s-interview-lab-tfstate"
    prefix = "gcp/dev"
  }
}