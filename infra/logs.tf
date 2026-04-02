resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/my-node-app"
}