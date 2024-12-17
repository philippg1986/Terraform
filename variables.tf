variable "hosted_zone" {
  description = "Hosted Zone, in der die Subdomain angelegt werden soll. Achtung muss zwingend in Route53 verwaltet sein!"
  type        = string
  default     = "yourdomainatroute53.example"
}

variable "subdomain" {
  description = "Subdomain, welche für die CloudFront Distribution verwendet werden soll"
  type        = string
  default     = "www"
}