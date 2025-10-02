provider "aws" {
  region = "us-east-2" # This should match the region of your RDS instance
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lanchonete-cpf-verifier-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_vpc_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "lanchonete-cpf-verifier-lambda-logging-policy"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

data "aws_vpc" "selected_vpc" {
  id = "vpc-0e1ce630f1b244174" # Replace with your actual VPC ID from lanchonete-db-infra/variables.tf
}

data "aws_subnets" "selected_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected_vpc.id]
  }
  # Removed tags filter to broaden subnet search
}

data "aws_security_group" "lanchonete_db_sg" {
  name = "lanchonete-db-sg"
  vpc_id = data.aws_vpc.selected_vpc.id
}

resource "aws_lambda_function" "cpf_verifier_lambda" {
  function_name    = "lanchonete-cpf-verifier"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 30

  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")

  vpc_config {
    subnet_ids         = data.aws_subnets.selected_subnets.ids
    security_group_ids = [data.aws_security_group.lanchonete_db_sg.id]
  }

  environment {
    variables = {
      DB_HOST     = var.db_endpoint
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
    }
  }
}

resource "aws_api_gateway_rest_api" "lanchonete_api" {
  name        = "LanchoneteCPFVerifierAPI"
  description = "API Gateway for CPF verification"
}

resource "aws_api_gateway_resource" "login_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "login"
}

resource "aws_api_gateway_resource" "cpf_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.login_resource.id
  path_part   = "cpf"
}

resource "aws_api_gateway_method" "cpf_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.cpf_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id             = aws_api_gateway_resource.cpf_resource.id
  http_method             = aws_api_gateway_method.cpf_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.cpf_verifier_lambda.invoke_arn
}

resource "aws_lambda_permission" "apigateway_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cpf_verifier_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.cpf_post_method,
  ]

  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  # Note: Terraform will redeploy the API Gateway if any of the resources it depends on change.
  # To force a redeployment on every `terraform apply`, you can use a timestamp:
  # triggers = {
  #   redeployment = timestamp()
  # }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  stage_name    = "dev"
}

output "api_gateway_invoke_url" {
  value       = "${aws_api_gateway_rest_api.lanchonete_api.execution_arn}/${aws_api_gateway_stage.dev_stage.stage_name}/login/cpf"
  description = "The invoke URL for the API Gateway"
}

variable "db_endpoint" {
  description = "The endpoint of the RDS instance"
  type        = string
}

variable "db_name" {
  description = "The name of the database"
  type        = string
}

variable "db_username" {
  description = "The username for the database"
  type        = string
}

variable "db_password" {
  description = "The password for the database"
  type        = string
}
