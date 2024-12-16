/* 

Management der Provider, Provider Versionen und Terraform Version

*/

terraform {
  required_version = ">=1.10.0"
  required_providers {
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

# Festlegen der Region bei der Erstellung von AWS Resourcen
provider "aws" {
  region = "eu-north-1"
}

# Damit das Zertifikat für CloudFront genutzt werden kann, muss dieses in US-EAST-1 erstellt werden.
# "To use an ACM certificate with Amazon CloudFront, you must request or import the certificate in the US East (N. Virginia) region."
# Quelle: https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html (Abschnitt "Supported Regions")
#
# Daher wird hier der AWS Provider mit einem Alias für ACM eingerichtet.
provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}