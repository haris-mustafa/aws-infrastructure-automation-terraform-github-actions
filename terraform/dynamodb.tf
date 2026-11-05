# ---------------------------------------------------------------------------
# dynamodb.tf -- tiny NoSQL table that stores the visitor counter
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "visits" {
  name         = "${var.project_name}-visits"
  billing_mode = "PAY_PER_REQUEST" # no capacity planning, you pay per request
  hash_key     = "id"              # primary key (we only ever use id = "visits")

  attribute {
    name = "id"
    type = "S" # S = string
  }
}
