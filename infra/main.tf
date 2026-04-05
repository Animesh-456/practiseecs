# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 6.0"
#     }
#   }
# }

# # Configure the AWS Provider
# provider "aws" {
#   region = "ap-south-1"
# }

# data "aws_vpc" "vpc_default" {
#   default = true
# }


# resource "aws_iam_role" "ecs_task_exec_role" {
#   name = "ecsTaskExecRole"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "ecs-tasks.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# data "aws_subnets" "private_subnets" {
#   filter {
#     name   = "tag:Name"
#     values = ["private*"] # insert values here
#   }
# }


# data "aws_subnets" "public_subnets" {
#   filter {
#     name   = "tag:Name"
#     values = ["public*"] # insert values here
#   }
# }


# # Create Elastic IP for NAT Gateway
# resource "aws_eip" "nat_eip" {
#   domain = "vpc"

#   tags = {
#     Name = "nat-gateway-eip"
#   }
# }

# # Create NAT Gateway
# resource "aws_nat_gateway" "nat_gateway" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = data.aws_subnets.public_subnets.ids[0] # Use the first subnet for NAT Gateway

#   tags = {
#     Name = "nat-gateway"
#   }
# }

# data "aws_route_table" "private_route_table" {
#   filter {
#     name   = "tag:Name"
#     values = ["private*"] # insert values here
#   }
# }

# resource "aws_route" "r" {
#   route_table_id            = data.aws_route_table.private_route_table.id
#   destination_cidr_block    = "0.0.0.0/0"
#   nat_gateway_id           = aws_nat_gateway.nat_gateway.id
# }



# resource "aws_ecs_cluster" "main" {
#   name = "my-ecs-cluster"
# }

# resource "aws_security_group" "alb_sg" {
#   name        = "alb-security-group"
#   description = "Allow HTTP traffic to ALB"
#   vpc_id      = data.aws_vpc.vpc_default.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }


# resource "aws_security_group" "ecs_sg" {
#   name   = "ecs-security-group"
#   vpc_id = data.aws_vpc.vpc_default.id

#   ingress {
#     from_port       = 4000
#     to_port         = 4000
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id] # allow ALB -> ECS
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }


# resource "aws_cloudwatch_log_group" "ecs_logs" {
#   name = "/ecs/my-node-app"
# }

# resource "aws_ecs_task_definition" "app" {
#   depends_on = [aws_cloudwatch_log_group.ecs_logs]
#   family                   = "my-node-app"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = "256" // 0.25 vCPU
#   memory                   = "512" // 512 MiB memory

#   execution_role_arn = aws_iam_role.ecs_task_exec_role.arn // ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.

#   container_definitions = jsonencode([
#     {
#       name      = "node-app"
#       image     = "anim45/practiseecs:latest"
#       essential = true

#       portMappings = [
#         {
#           containerPort = 4000
#           hostPort      = 4000
#         }
#       ]

#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           "awslogs-group"         = "/ecs/my-node-app"
#           "awslogs-region"        = "ap-south-1"
#           "awslogs-stream-prefix" = "ecs"
#         }
#       }
#     }
#   ])
# }



# resource "aws_lb" "app_alb" {
#   name               = "app-alb"
#   internal           = false
#   load_balancer_type = "application"
#   subnets            = data.aws_subnets.public_subnets.ids

#   security_groups = [aws_security_group.alb_sg.id]
# }


# resource "aws_lb_target_group" "app_tg" {
#   name        = "app-tg"
#   port        = 4000
#   protocol    = "HTTP"
#   vpc_id      = data.aws_vpc.vpc_default.id
#   target_type = "ip"

#   health_check {
#     path = "/health"
#     port = "4000"
#   }
# }

# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.app_alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }

# resource "aws_ecs_service" "app" {
#   name            = "node-app-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.app.arn
#   desired_count   = 2
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = data.aws_subnets.private_subnets.ids
#     security_groups  = [aws_security_group.ecs_sg.id]
#     assign_public_ip = false
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.app_tg.arn
#     container_name   = "node-app"
#     container_port   = 4000
#   }

#   depends_on = [aws_lb_listener.http]
# }


# resource "aws_appautoscaling_target" "ecs_target" {
#   max_capacity       = 5
#   min_capacity       = 1
#   resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
# }

# resource "aws_appautoscaling_policy" "cpu_policy" {
#   name               = "cpu-scaling-policy"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.ecs_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

#   target_tracking_scaling_policy_configuration {
#     target_value = 70

#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageCPUUtilization"
#     }

#     scale_in_cooldown  = 60
#     scale_out_cooldown = 60
#   }
# }



# resource "aws_iam_role_policy_attachment" "ecs_policy" {
#   role       = aws_iam_role.ecs_task_exec_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# output "alb_dns" {
#   value = aws_lb.app_alb.dns_name
# }


terraform {
  backend "s3" {
    bucket         = "practiseecs-app-tf-state-12345"
    key            = "environments/nodejs-app-prod.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-locks"  # Correct option for state locking
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-south-1"
}

data "aws_vpc" "vpc_default" {
  default = true
}
