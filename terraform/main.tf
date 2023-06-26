terraform {
  backend "s3" {
    bucket         = "lol-counter-source-state"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "lol-counter-source-state-lock"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.4"
    }
  }
  required_version = "~> 1.5"
}


provider "aws" {
  region = "us-east-1"  # Replace with your desired AWS region
}

resource "aws_iam_role" "lambda_role" {
  name = "my-lambda-role-${terraform.workspace}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role" "cloudwatch" {
  name = "api_gateway_cloudwatch_global-${terraform.workspace}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "default-${terraform.workspace}"
  role = "${aws_iam_role.cloudwatch.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_api_gateway_account" "gateway_account" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

resource "aws_lambda_function" "example" {
  function_name = "counter-source-${terraform.workspace}"
  runtime       = "nodejs18.x"
  handler       = "./src/index.handler"
  filename      = "../counterLambda.zip"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash =  filebase64sha256("../counterLambda.zip")
  environment {
    variables = {
      BASE_COUNTER_URL = var.BASE_COUNTER_URL
    }
  }

}

resource "aws_api_gateway_rest_api" "counter_source" {
  name = "counter-source-${terraform.workspace}"
}

resource "aws_api_gateway_resource" "counter_path" {
  rest_api_id = aws_api_gateway_rest_api.counter_source.id
  parent_id   = aws_api_gateway_rest_api.counter_source.root_resource_id
  path_part   = "source"
}

resource "aws_api_gateway_method" "counter_method" {
  rest_api_id   = aws_api_gateway_rest_api.counter_source.id
  resource_id   = aws_api_gateway_resource.counter_path.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "counter_integration" {
  rest_api_id             = aws_api_gateway_rest_api.counter_source.id
  resource_id             = aws_api_gateway_resource.counter_path.id
  http_method             = aws_api_gateway_method.counter_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.example.invoke_arn
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowMyAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "apigateway.amazonaws.com"

  # The /* part allows invocation from any stage, method and resource path
  # within API Gateway.
  source_arn = "${aws_api_gateway_rest_api.counter_source.execution_arn}/*"
}

resource "aws_api_gateway_deployment" "counter_deployment" {
  depends_on = [aws_api_gateway_integration.counter_integration]
  rest_api_id = aws_api_gateway_rest_api.counter_source.id
  stage_name  = "prod"
  triggers = {

    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.counter_path.id,
      aws_api_gateway_method.counter_method.id,
      aws_api_gateway_integration.counter_integration.id,
    ]))
  }
}

resource "aws_api_gateway_method_settings" "general_settings" {
  rest_api_id = "${aws_api_gateway_rest_api.counter_source.id}"
  stage_name  = "${aws_api_gateway_deployment.counter_deployment.stage_name}"
  method_path = "*/*"

  settings {
    # Enable CloudWatch logging and metrics
    metrics_enabled        = true
    data_trace_enabled     = true
    logging_level          = "INFO"

    # Limit the rate of calls to prevent abuse and unwanted charges
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
  }
}



