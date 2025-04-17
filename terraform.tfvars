region   = "us-east-1"
vpc_cidr = "10.0.0.0/16"
tenancy  = "default"
vpc_name = "ecs-vpc"

public_subnets = {
  public-subnet-1 = {
    cidr = "10.0.1.0/24"
    az   = "us-east-1a"
  }
  public-subnet-2 = {

    cidr = "10.0.2.0/24"
    az   = "us-east-1b"
  }
}

private_subnets = {
  private-subnet-1 = {
    cidr = "10.0.3.0/24"
    az   = "us-east-1a"
  }
  private-subnet-2 = {
    cidr = "10.0.4.0/24"
    az   = "us-east-1b"
  }
}

security-group = {
  http = {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  },
  https = {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }

}

certificate_arn = "arn:aws:acm:us-east-1:011528297445:certificate/0bd43b67-3078-4273-8dd7-40918c80d6dd"