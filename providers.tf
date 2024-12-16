terraform {
  required_version = ">=1.10.0"
  required_providers {
    # AWS wird benötigt für AWS
    aws = {
      source  = "hashicorp/aws"
      version = "=5.81.0"
    }
    # Random wird benötigt um Zufallsnamen für einen S3-Bucket zu erstellen, damit dieser eindeutig ist
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# ACM Certificate in us-east-1
provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}