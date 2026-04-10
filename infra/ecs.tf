resource "aws_ecs_cluster" "main" {
  name = "my-ecs-cluster"
}

resource "aws_ecs_task_definition" "app" {
  depends_on = [aws_cloudwatch_log_group.ecs_logs]

  family                   = "my-node-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_exec_role.arn

  container_definitions = jsonencode([
    {
      name      = "node-app"
      image     = "anim45/practiseecs:latest"
      essential = true

      dockerLabels = {
        PROMETHEUS_SCRAPE = "true"
        PROMETHEUS_PORT   = "9090"
        PROMETHEUS_PATH   = "/metrics"
      }

      portMappings = [{
        containerPort = 4000
        hostPort      = 4000
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/my-node-app"
          "awslogs-region"        = "ap-south-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "node-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private_subnets.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "node-app"
    container_port   = 4000
  }

  depends_on = [aws_lb_listener.http]
}