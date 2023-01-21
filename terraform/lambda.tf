variable region {
    default = "us-east-1"
}

provider aws {
    region = var.region
}

resource "random_id" "id" {
	  byte_length = 8
}

data aws_caller_identity current{}

locals {
    prefix = "reportgen"
    account_id=data.aws_caller_identity.current.account_id
    ecr_repository_name = "${local.prefix}-${random_id.id.hex}-lambda-repository"
    ecr_image_tag = "latest"
    outputfilename = "g7Comparison.png"
}

resource aws_s3_bucket inputlocation {
    bucket = "${local.prefix}-${random_id.id.hex}-in"
    force_destroy = true
}

resource aws_s3_bucket outputlocation {
    bucket = "${local.prefix}-${random_id.id.hex}-out"
    force_destroy = true
}

resource aws_ecr_repository repo {
    name = local.ecr_repository_name
    force_delete = true
}

resource null_resource ecr_image {
    triggers = {
        python_file = md5(file("../app/app.py"))
        docker_file = md5(file("../app/Dockerfile"))
    }

    provisioner "local-exec" {
        command = <<EOF
                    aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${var.region}.amazonaws.com
                    docker build -t ${aws_ecr_repository.repo.repository_url}:${local.ecr_image_tag} ../app
                    docker push ${aws_ecr_repository.repo.repository_url}:${local.ecr_image_tag}
                EOF
         # interpreter = ["pwsh", "-Command"] # For Windows 
        interpreter = ["bash", "-c"] # For Linux/MacOS
        working_dir = "../app"
    }    
}

data aws_ecr_image lambda_image {
    depends_on = [
        null_resource.ecr_image
    ]
    repository_name = local.ecr_repository_name
    image_tag = local.ecr_image_tag
}

resource aws_iam_role lambda {
    name = "${local.prefix}-${random_id.id.hex}-lambda-role"
    assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement":[
            {
                "Action": "sts:AssumeRole",
                "Principal":{
                    "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow"
            }
        ]
    }
    EOF
}

data aws_iam_policy_document lambda_permissions {
    statement {
            actions = [ "logs:CreateLogGroup"]
            resources = ["arn:aws:logs:${var.region}:${local.account_id}:*"]
            }
    statement {
                actions = [
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"]
                resources = [
                    "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/${aws_lambda_function.reportgen.function_name}:*"]
            }
    statement {
                actions= [
                    "s3:Get*",
                    "s3:List*",
                    "s3-object-lambda:Get*",
                    "s3-object-lambda:List*"
                ]
                resources =  ["arn:aws:s3:::${aws_s3_bucket.inputlocation.bucket}/*"]
            }
    statement {
                actions =  [
                    "s3:*",
                    "s3-object-lambda:*"
                ]
                resources = ["arn:aws:s3:::${aws_s3_bucket.outputlocation.bucket}/*"]
            }
}

resource aws_iam_role_policy lambda {
    role     = aws_iam_role.lambda.id
    policy   = data.aws_iam_policy_document.lambda_permissions.json
}

resource aws_lambda_function reportgen {
 depends_on = [
   null_resource.ecr_image
 ]
 function_name = "${local.prefix}-${random_id.id.hex}-function"
 role = aws_iam_role.lambda.arn
 timeout = 300
 image_uri = "${aws_ecr_repository.repo.repository_url}@${data.aws_ecr_image.lambda_image.id}"
 package_type = "Image"
 environment {
    variables = {
      OUTPUT_S3_BUCKET = "${aws_s3_bucket.outputlocation.bucket}"
      OUTPUT_FILENAME = "${local.outputfilename}"
    }
 }
}
 
# Adding S3 bucket as trigger to my lambda and giving the permissions
resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.inputlocation.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.reportgen.arn
    events              = ["s3:ObjectCreated:*"]

  }
}

resource "aws_lambda_permission" "test" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reportgen.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.inputlocation.id}"
}

output "lambda_name" {
 value = aws_lambda_function.reportgen.id
}