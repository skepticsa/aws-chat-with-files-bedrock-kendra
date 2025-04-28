provider "aws" {
  region = var.region
}

# Random ID for unique resource naming
resource "random_id" "id" {
  byte_length = 8
}

# S3 bucket for storing PDFs
resource "aws_s3_bucket" "document_bucket" {
  bucket = "pdf-document-bucket-${random_id.id.hex}"

  tags = {
    Name        = "PDF Document Storage"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 bucket for website hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "pdf-chatbot-website-${random_id.id.hex}"

  tags = {
    Name        = "PDF Chatbot Website"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website_access]
}

# Upload index.html to the S3 website bucket
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<-EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF Document Chatbot</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { padding: 20px; }
        #chat-container { height: 60vh; overflow-y: auto; padding: 15px; border: 1px solid #dee2e6; border-radius: 5px; margin-bottom: 10px; }
        .user-message { background-color: #f0f7ff; padding: 8px 15px; border-radius: 15px; margin-bottom: 10px; max-width: 70%; margin-left: auto; }
        .bot-message { background-color: #f1f1f1; padding: 8px 15px; border-radius: 15px; margin-bottom: 10px; max-width: 70%; }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="mb-4">PDF Document Chatbot</h1>
        <div id="chat-container" class="mb-3"></div>
        <div class="input-group">
            <input type="text" id="user-input" class="form-control" placeholder="Ask a question about your documents...">
            <button id="send-btn" class="btn btn-primary">Send</button>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const chatContainer = document.getElementById('chat-container');
            const userInput = document.getElementById('user-input');
            const sendBtn = document.getElementById('send-btn');
            
            // Add initial message
            addBotMessage("Hello! I'm your PDF document assistant. Ask me anything about your documents.");
            
            // Send message when button is clicked
            sendBtn.addEventListener('click', sendMessage);
            
            // Send message when Enter key is pressed
            userInput.addEventListener('keypress', function(e) {
                if (e.key === 'Enter') {
                    sendMessage();
                }
            });
            
            function sendMessage() {
                const userMessage = userInput.value.trim();
                if (!userMessage) return;
                
                // Display user message
                addUserMessage(userMessage);
                userInput.value = '';
                
                // Show loading indicator
                addBotMessage("Thinking...", "bot-message loading-message");
                
                // Call API with the full API Gateway URL
                fetch('https://${aws_api_gateway_rest_api.chatbot_api.id}.execute-api.${var.region}.amazonaws.com/${var.environment}/chat', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ query: userMessage })
                })
                .then(response => response.json())
                .then(data => {
                    // Remove loading message
                    document.querySelector('.loading-message')?.remove();
                    // Display bot response
                    addBotMessage(data.response);
                })
                .catch(error => {
                    document.querySelector('.loading-message')?.remove();
                    addBotMessage("Sorry, I encountered an error. Please try again.");
                    console.error('Error:', error);
                });
            }
            
            function addUserMessage(message) {
                const messageElement = document.createElement('div');
                messageElement.className = 'user-message';
                messageElement.textContent = message;
                chatContainer.appendChild(messageElement);
                chatContainer.scrollTop = chatContainer.scrollHeight;
            }
            
            function addBotMessage(message, className = 'bot-message') {
                const messageElement = document.createElement('div');
                messageElement.className = className;
                messageElement.textContent = message;
                chatContainer.appendChild(messageElement);
                chatContainer.scrollTop = chatContainer.scrollHeight;
            }
        });
    </script>
</body>
</html>
  EOF
}

# Upload error.html to the S3 website bucket
resource "aws_s3_object" "error_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "error.html"
  content_type = "text/html"
  content      = <<-EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Error - PDF Document Chatbot</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <div class="container mt-5">
        <div class="alert alert-danger" role="alert">
            <h4 class="alert-heading">Oops! Something went wrong.</h4>
            <p>We couldn't find the page you were looking for.</p>
            <hr>
            <p class="mb-0"><a href="index.html">Return to home page</a></p>
        </div>
    </div>
</body>
</html>
  EOF
}

# Create an IP set with your corporate IP ranges for WAF
resource "aws_wafv2_ip_set" "corporate_ips" {
  name               = "corporate-ip-ranges"
  description        = "Corporate IP address ranges"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = [
    "8.36.116.0/24",
    "8.39.144.0/24",
    "31.186.239.0/24",
    "163.116.128.0/17",
    "162.10.0.0/17"
  ]
}

# Create a WAF Web ACL
resource "aws_wafv2_web_acl" "employee_only_acl" {
  name        = "employee-only-access"
  description = "ACL to allow only employee IP ranges"
  scope       = "CLOUDFRONT"

  default_action {
    block {}
  }

  rule {
    name     = "allow-corporate-ips"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.corporate_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowCorporateIPs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EmployeeOnlyACL"
    sampled_requests_enabled   = true
  }
}

# CloudFront distribution for the website with WAF and geographic restrictions
resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website_bucket.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.employee_only_acl.arn

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"] # Add other countries as needed
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "PDF Chatbot Website Distribution"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}_lambda_role_${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "PDF Chatbot Lambda Role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for Lambda function
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}_lambda_policy_${var.environment}"
  description = "Policy for PDF Chatbot Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.document_bucket.arn,
          "${aws_s3_bucket.document_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "kendra:Query",
          "kendra:Retrieve"
        ]
        Effect   = "Allow"
        Resource = aws_kendra_index.document_index.arn
      },
      {
        Action = [
          "bedrock:InvokeModel"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach IAM policy to IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Amazon Kendra for document indexing
resource "aws_kendra_index" "document_index" {
  name        = "${var.project_name}-document-index-${var.environment}"
  description = "Index for PDF documents"
  role_arn    = aws_iam_role.kendra_role.arn
  edition     = var.kendra_edition

  tags = {
    Name        = "PDF Document Index"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for Kendra
resource "aws_iam_role" "kendra_role" {
  name = "${var.project_name}_kendra_role_${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "kendra.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "PDF Chatbot Kendra Role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for Kendra
resource "aws_iam_policy" "kendra_policy" {
  name        = "${var.project_name}_kendra_policy_${var.environment}"
  description = "Policy for PDF Chatbot Kendra service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "AWS/Kendra"
          }
        }
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.document_bucket.arn,
          "${aws_s3_bucket.document_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach IAM policy to Kendra IAM role
resource "aws_iam_role_policy_attachment" "kendra_policy_attachment" {
  role       = aws_iam_role.kendra_role.name
  policy_arn = aws_iam_policy.kendra_policy.arn
}

# Kendra S3 data source
resource "aws_kendra_data_source" "s3_data_source" {
  index_id    = aws_kendra_index.document_index.id
  name        = "${var.project_name}-s3-data-source-${var.environment}"
  description = "S3 bucket containing PDF documents"
  type        = "S3"
  role_arn    = aws_iam_role.kendra_role.arn

  configuration {
    s3_configuration {
      bucket_name = aws_s3_bucket.document_bucket.bucket
    }
  }
}

# Create Lambda deployment package before Lambda function creation
resource "null_resource" "lambda_zip" {
  provisioner "local-exec" {
    command = <<EOT
mkdir -p lambda
cat > lambda/lambda_function.py << 'EOF'
import boto3
import json
import os

# Initialize AWS clients
bedrock_runtime = boto3.client('bedrock-runtime')
kendra = boto3.client('kendra')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Extract user query from the request
    body = json.loads(event.get('body', '{}'))
    query = body.get('query', '')
    
    if not query:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing query parameter'}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            }
        }
    
    # Step 1: Search documents with Kendra
    kendra_index_id = os.environ.get('KENDRA_INDEX_ID')
    try:
        kendra_response = kendra.query(
            QueryText=query,
            IndexId=kendra_index_id
        )
    except Exception as e:
        print(f"Error querying Kendra: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Error searching documents'}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            }
        }
    
    # Step 2: Format context from relevant documents
    context = ""
    for result in kendra_response.get('ResultItems', []):
        if result.get('Type') == 'DOCUMENT':
            document_title = result.get('DocumentTitle', {}).get('Text', 'Unknown Document')
            document_excerpt = result.get('DocumentExcerpt', {}).get('Text', '')
            context += f"Document: {document_title}\nExcerpt: {document_excerpt}\n\n"
    
    if not context:
        context = "No relevant information found in the documents."
    
    # Step 3: Generate response using Amazon Bedrock (Claude)
    try:
        bedrock_model_id = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        request_body = {
            "modelId": bedrock_model_id,
            "contentType": "application/json",
            "accept": "application/json",
            "body": json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1000,
                "temperature": 0.7,
                "messages": [
                    {
                        "role": "user",
                        "content": f"You are a helpful assistant answering questions based on the following document context:\n\n{context}\n\nThe query is: {query}\n\nPlease answer based on the information provided in the context. If the context doesn't contain relevant information to answer the query, please say so."
                    }
                ]
            })
        }
        
        bedrock_response = bedrock_runtime.invoke_model(**request_body)
        response_body = json.loads(bedrock_response.get('body').read())
        assistant_response = response_body.get('content')[0].get('text')
        
        return {
            'statusCode': 200,
            'body': json.dumps({'response': assistant_response}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            }
        }
    except Exception as e:
        print(f"Error generating response with Bedrock: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Error generating response'}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            }
        }
EOF

cd lambda && zip -r ../lambda_function.zip lambda_function.py
cd ..
EOT
  }
}

# Lambda function for the chatbot
resource "aws_lambda_function" "chatbot_lambda" {
  function_name    = "${var.project_name}-lambda-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      KENDRA_INDEX_ID = aws_kendra_index.document_index.id
      S3_BUCKET_NAME  = aws_s3_bucket.document_bucket.bucket
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  }

  tags = {
    Name        = "PDF Chatbot Lambda Function"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment,
    null_resource.lambda_zip
  ]
}

# API Gateway
resource "aws_api_gateway_rest_api" "chatbot_api" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "API for PDF Chatbot"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway resource
resource "aws_api_gateway_resource" "chat_resource" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  path_part   = "chat"
}

# API Gateway method - POST
resource "aws_api_gateway_method" "chat_method" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.chat_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway integration
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chatbot_api.id
  resource_id             = aws_api_gateway_resource.chat_resource.id
  http_method             = aws_api_gateway_method.chat_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.chatbot_lambda.invoke_arn
}

# Add response method for POST with CORS headers
resource "aws_api_gateway_method_response" "chat_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_method.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# API Gateway CORS - OPTIONS method
resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.chat_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway CORS - OPTIONS integration
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# API Gateway CORS - OPTIONS method response
resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway CORS - OPTIONS integration response
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# API Gateway IP restriction policy
resource "aws_api_gateway_rest_api_policy" "api_ip_policy" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = [
              "8.36.116.0/24",
              "8.39.144.0/24",
              "31.186.239.0/24",
              "163.116.128.0/17",
              "162.10.0.0/17"
            ]
          }
        }
      },
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*/*"
        Condition = {
          NotIpAddress = {
            "aws:SourceIp" = [
              "8.36.116.0/24",
              "8.39.144.0/24",
              "31.186.239.0/24",
              "163.116.128.0/17",
              "162.10.0.0/17"
            ]
          }
        }
      }
    ]
  })
}

# API Gateway deployment - No stage name (using separate stage resource)
resource "aws_api_gateway_deployment" "chatbot_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_method_response.chat_method_response_200,
    aws_api_gateway_integration_response.options_integration_response,
    aws_api_gateway_rest_api_policy.api_ip_policy
  ]

  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  # Remove stage_name from here to avoid deprecation warning
}

# API Gateway stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.chatbot_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  stage_name    = var.environment
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatbot_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*"
}