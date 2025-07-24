provider "aws" {
  region     = "us-east-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_instance" "strapi_server" {
  ami                         = "ami-0c55b159cbfafe1f0" # Ubuntu 22.04 LTS (us-east-2)
  instance_type               = "t2.micro"
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install docker.io -y
              sudo systemctl start docker
              sudo docker pull ${var.docker_image}
              sudo docker run -d -p 80:1337 ${var.docker_image}
              EOF

  tags = {
    Name = "strapi-server-dhan"
  }
}
