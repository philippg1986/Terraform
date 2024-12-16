/* 

Management der S3 Resourcen

*/

# Hier wird ein String mit 8 Zeichen generiert, da ein S3-Bucket einen Global eindeutigen Namen haben muss
# So ist hier immer ein Zufallswert integriert

resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
  lower   = true
  numeric = true
}

# Ermitteln und festlegen des Quellordners für die Website Dateien
locals {
  folder_path = abspath("${path.module}/website-files")
  files       = fileset(local.folder_path, "**")
}

# Hier wird das Bucket erstellt
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.subdomain}.${data.aws_route53_zone.active_zone.name}-${random_string.random.result}"
}


# Hier wird die Policy mit der Origin Access Identity im Bucket eingepflegt
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Hier werden die Website Files übertragen und die MIME-Types gesetzt
resource "aws_s3_object" "website-files" {
  for_each = {
    for file in local.files : file => file
  }

  bucket = aws_s3_bucket.bucket.id
  key    = each.value
  source = "${local.folder_path}/${each.value}"
  etag   = filemd5("${local.folder_path}/${each.value}") #Vergleich für Änderungen der Datei

  # Definition der gängigsten MIME-Types für statischen Website Content
  content_type = lookup(
    {
      "html" = "text/html",
      "css"  = "text/css",
      "js"   = "application/javascript"
      "png"  = "image/png",
      "jpg"  = "image/jpeg",
      "gif"  = "image/gif"
    },
    split(".", each.value)[length(split(".", each.value)) - 1],
    "application/octet-stream" #Fallback
  )
}