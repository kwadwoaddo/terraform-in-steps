#vpc
output "vpc_id" {
  value       = aws_vpc.ecs_vpc.id
  description = "The ID of the main VPC"
}

output "vpc_cidr_block" {
  value       = aws_vpc.ecs_vpc.cidr_block
  description = "The cidr-block of the main VPC"
}

output "instance_tenancy" {
  value       = aws_vpc.ecs_vpc.instance_tenancy
  description = "The instance tenancy of VPC"
}

output "eip" {
  value       = aws_eip.nat_eip.public_ip
  description = "The public Elastic IP assigned to the NAT Gateway"
}

output "public_subnet_ids" {
  value       = [for subnet in aws_subnet.public-subnets : subnet.id]
  description = "List of public subnet IDs"
}

output "nat_gateway_id" {
  value       = aws_nat_gateway.nat.id
  description = "The NAT Gateway ID"
}

output "private_subnet_ids" {
  value       = [for subnet in aws_subnet.private-subnets : subnet.id]
  description = "List of private subnet IDs"

}

output "ecs_task_execution_role_arn" {
  value       = aws_iam_role.ecs_task_execution_role.arn
  description = "IAM role ARN for ECS task execution"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "alb_dns" {
  value = aws_lb.app_alb.dns_name
}



output "private_subnet_azs" {
  value = {
    for key, subnet in aws_subnet.private-subnets :
    key => subnet.availability_zone
  }
}

