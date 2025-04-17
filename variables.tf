variable "vpc_cidr" {
  description = "Cidr-block for the dev VPC"
  type        = string
  default     = "10.0.0.0/16" # Default value of VPC

}

variable "tenancy" {
  description = "Instance tenancy for VPC"
  type        = string
  default     = "default"

}

variable "vpc_name" {
  description = "name for VPC"
  type        = string
  default     = "ecs_vpc"

}

variable "region" {
  description = "region for VPC"
  type        = string

  default = "us-east-1"
}

#All private subnets in a map

variable "private_subnets" {
  description = "all private subnets"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    private-subnet-1 = {
      cidr = "10.0.10.0/24"
      az   = "us-east-1a"
    }

    private-subnet-2 = {
      cidr = "10.0.11.0/24"
      az   = "us-east-1b"
    }
  }
}

#All public subnets in a map

variable "public_subnets" {
  description = "all public subnets"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    pubic-subnet-1 = {
      cidr = "10.0.1.0/24"
      az   = "us-east-1a"
    }

    public-subnet-2 = {
      cidr = "10.0.2.0/24"
      az   = "us-east-1b"
    }
  }
}

#Security Group
variable "security-group" {
  description = "Map of ingress rules for ECS security group"
  type = map(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = {
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
}

#ACM certificate
variable "certificate_arn" {
  description = "The ARN of the ACM certificate for HTTPS"
  type        = string
}



