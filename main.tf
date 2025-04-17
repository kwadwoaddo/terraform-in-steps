resource "aws_vpc" "ecs_vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = var.tenancy

  tags = {
    Name = var.vpc_name
  }
}

# Public subnets for vpc
resource "aws_subnet" "public-subnets" {
  for_each          = var.public_subnets # Loops through the map
  vpc_id            = aws_vpc.ecs_vpc.id
  cidr_block        = each.value.cidr # Each subnet gets a CIDR block from the list
  availability_zone = each.value.az

  tags = {
    Name = each.key
  }
}

# Private subnets for vpc
resource "aws_subnet" "private-subnets" {
  for_each   = var.private_subnets # Loops through the map
  vpc_id     = aws_vpc.ecs_vpc.id
  cidr_block = each.value.cidr # Each subnet gets a CIDR block from the list

  tags = {
    Name = each.key
  }
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecs_vpc.id

  tags = {
    Name = "ecs-igw"
  }
}

# Public Route Table
resource "aws_route_table" "ecs-rt" {
  vpc_id = aws_vpc.ecs_vpc.id

  tags = {
    Name = "public-route-table"
  }
}

# Route for Internet Access
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.ecs-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Public subnet association with Route table
resource "aws_route_table_association" "public-rt-association" {
  for_each       = aws_subnet.public-subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.ecs-rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.ecs_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

#Nat Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public-subnets["public-subnet-1"].id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}
resource "aws_route_table_association" "private-rt-association" {
  for_each       = aws_subnet.private-subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route" "private_nat_gateway_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

#Security Groups
resource "aws_security_group" "ecs-sg" {
  name        = "ecs-sg"
  description = "Allow Port 80 and 443"
  vpc_id      = aws_vpc.ecs_vpc.id

  dynamic "ingress" {
    for_each = var.security-group
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg"
  }
}

#
resource "aws_key_pair" "ecs_key" {
  key_name   = "ecs-key"
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
    Name = "ecs-key"
  }
}
#key_name = aws_key_pair.ecs_key.key_name

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#ECR
resource "aws_ecr_repository" "nginx_repo" {
  name                 = "nginx-ecr-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  lifecycle {
    # prevent_destroy = true
  }

  tags = {
    Name        = "nginx-ecr-repo"
    Environment = terraform.workspace
  }
}

#Ecs
resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster-${terraform.workspace}"

  tags = {
    Name = "ecs-cluster-${terraform.workspace}"
  }
}

resource "aws_ecs_task_definition" "nginx_task" {
  family                   = "nginx-task-${terraform.workspace}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "011528297445.dkr.ecr.us-east-1.amazonaws.com/nginx-ecr-repo:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/nginx"
          awslogs-region        = "us-west-1"
          awslogs-stream-prefix = "nginx"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service-${terraform.workspace}"
  cluster         = aws_ecs_cluster.main.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.nginx_task.arn
  desired_count   = 1

  network_configuration {
    subnets          = [for subnet in aws_subnet.private-subnets : subnet.id]
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs-sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx_tg.arn
    container_name   = "nginx" # must match your task definition
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https

  ]

  tags = {
    Name = "nginx-service-${terraform.workspace}"
  }
}
resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/nginx"
  retention_in_days = 7
}

#ALB security group
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS traffic"
  vpc_id      = aws_vpc.ecs_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

#Create ALB
resource "aws_lb" "app_alb" {
  name               = "nginx-alb-${terraform.workspace}"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for subnet in aws_subnet.public-subnets : subnet.id]

  tags = {
    Name = "nginx-alb-${terraform.workspace}"
  }
}

# Create Target Group
resource "aws_lb_target_group" "nginx_tg" {
  name        = "nginx-tg-${terraform.workspace}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ecs_vpc.id
  target_type = "ip" # for Fargate

  health_check {
    path                = "/index.html"
    protocol            = "HTTP"
    matcher             = "200-499" # temporarily allow broader range
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "nginx-tg-${terraform.workspace}"
  }
}

#Create Listener port (80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }
}

#route53
resource "aws_route53_record" "studyhuts_root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "studyhuts.com"
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}


resource "aws_route53_record" "studyhuts_www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.studyhuts.com"
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_zone" "primary" {
  name = "studyhuts.com"
}

#ACM DNS Validation Records (Terraform)
resource "aws_route53_record" "acm_validation_studyhuts_root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "_c37fb746abe78219222a301aedc4b021.studyhuts.com"
  type    = "CNAME"
  ttl     = 300
  records = ["_3b4d0da07794ca3e0eb0a3b735dbe860.zfyfvmchrl.acm-validations.aws."]
}

#resource "aws_route53_record" "acm_validation_studyhuts" {
#zone_id = aws_route53_zone.primary.zone_id
#name    = "_c37fb746abe78219222a301aedc4b021.studyhuts.com"
#type    = "CNAME"
#ttl     = 300
#records = ["_3b4d0da07794ca3e0eb0a3b735dbe860.zfyfvmchrl.acm-validations.aws."]
#}
