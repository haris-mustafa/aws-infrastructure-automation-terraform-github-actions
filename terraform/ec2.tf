# ---------------------------------------------------------------------------
# ec2.tf -- the web server that hosts the static website (nginx)
# ---------------------------------------------------------------------------

# Always use the latest Amazon Linux 2023 image (AWS publishes the ID in SSM).
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# IAM role so the server can be managed with AWS Systems Manager (no SSH keys!)
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

locals {
  # Take app/web/index.html and swap the placeholder for the real API URL.
  index_html = replace(
    file("${path.module}/../app/web/index.html"),
    "__API_URL__",
    aws_apigatewayv2_api.http.api_endpoint
  )
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # user_data runs ONCE at first boot: installs nginx and writes the website.
  # The HTML is base64-encoded so quotes/special characters can't break the script.
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    echo '${base64encode(local.index_html)}' | base64 -d > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  # If the website HTML changes, replace the server so the new page is installed.
  # (Fine for a demo. In production you would deploy via S3/CodeDeploy/SSM instead.)
  user_data_replace_on_change = true

  # Require IMDSv2 (a security best practice)
  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "${var.project_name}-web" }
}
