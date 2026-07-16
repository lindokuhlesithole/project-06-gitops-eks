resource "aws_iam_role" "lambda" {
  name = "${var.app_name}-portal-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.app_name}-portal-lambda" }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "portal" {
  function_name = "${var.app_name}-portal"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 10

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  tags = { Name = "${var.app_name}-portal" }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic]
}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source {
    content  = <<-EOF
import json

def handler(event, context):
    method = event.get("httpMethod", "GET")
    path = event.get("path", "/")

    if path == "/api/namespaces" and method == "GET":
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({
                "namespaces": [
                    {"name": "team-alpha", "status": "active", "quota": "20 CPU / 40Gi"},
                    {"name": "team-beta", "status": "active", "quota": "10 CPU / 20Gi"}
                ]
            })
        }

    if path == "/api/health":
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"status": "healthy", "service": "developer-portal"})
        }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps({
            "message": "GitOps EKS Developer Portal",
            "endpoints": ["/api/namespaces", "/api/health"]
        })
    }
EOF
    filename = "index.py"
  }
}

resource "aws_api_gateway_rest_api" "portal" {
  name = "${var.app_name}-portal"
  tags = { Name = "${var.app_name}-portal" }
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  parent_id   = aws_api_gateway_rest_api.portal.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "namespaces" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "namespaces"
}

resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "health"
}

resource "aws_api_gateway_method" "namespaces_get" {
  rest_api_id   = aws_api_gateway_rest_api.portal.id
  resource_id   = aws_api_gateway_resource.namespaces.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.portal.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "namespaces" {
  rest_api_id             = aws_api_gateway_rest_api.portal.id
  resource_id             = aws_api_gateway_resource.namespaces.id
  http_method             = aws_api_gateway_method.namespaces_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.portal.invoke_arn
}

resource "aws_api_gateway_integration" "health" {
  rest_api_id             = aws_api_gateway_rest_api.portal.id
  resource_id             = aws_api_gateway_resource.health.id
  http_method             = aws_api_gateway_method.health_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.portal.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.portal.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.portal.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "portal" {
  depends_on = [
    aws_api_gateway_integration.namespaces,
    aws_api_gateway_integration.health,
  ]

  rest_api_id = aws_api_gateway_rest_api.portal.id
  stage_name  = "prod"

  lifecycle {
    create_before_destroy = true
  }
}
