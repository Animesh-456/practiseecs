resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.public_subnets.ids

  security_groups = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "app_tg" {
  name        = "app-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.vpc_default.id
  target_type = "ip"

  health_check {
    path = "/health"
    port = "4000"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}