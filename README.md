# Developing an AWS Lambda container in Python and deploying via Terraform

## Introduction
One of the use cases for Lambda I am intrigued about is report and chart generation. For example one could think of a scenario where groups familiar with Python and other reporting tools may want generate reports and charts for the executive audience. If they can be provided some training on developing the python code as Lambda and pushing it to the repository tied to the CI/CD pipeline, then it frees them up to focus on what they do best and reduce dependency on the IT team to deploy artifacts that provide critical business insights. IT or the web team can just provide the cloud locations for these reports and the Lambda developer will ensure that the code they write is configured with that target location. The ultimate destination like the web site or portal will just render the reports from these locations within the web layout already familiar to the target audience.

This blog post shows how to implement a non-trivial python lambda that generates a chart from a public data source. Since the chart library dependencies caused unzipped deployment package size to exceed the file size limit of 250Mb, I had to implement it as a python lambda container. The python code in question is the same as my [previous post](https://www.know2drive.com/blog/charting/) showcasing some of python's charting capabilities.
It is fairly straightforward to take python code written using Jupyter notebook and modify it to work as a AWS Lambda function. But the unfamiliar nuances for a developer are all around packaging and deployment. This blog will also walk you through the Terraform script to build and deploy the Lambda as a container to AWS. If you implement this code in your AWS account you may incur some minimal charges when you run the Lambda. 
If you are also interested in other cloud serverless implementations like Azure Function and Google Cloud Function, your learning exercise can be to take this code and modify it to work on those platforms as well.  

## Implementing existing python code as AWS Lambda
I combined the code from charting.ipynb and dataAnalysis.ipynb to a single .py file for better readability.I added the handler code to implement the Lambda.
The lambda will be triggered when the source CSV file is uploaded to a S3 location. This S3 location is specified as a resource **inputlocation** [terraform/lambda.tf](https://github.com/madhuvanesh/python_lambda_container/blob/main/terraform/lambda.tf).
The Lambda will process the CSV and generate the chart in an output location which is specified as **outputlocation** in terraform/lambda.tf. The chart is a .png file defined in **locals.outputfilename** in terraform/lambda.tf.
See the code on [Github](https://github.com/madhuvanesh/python_lambda_container) for more details.

## The Docker file that describes what goes into the container
Here is what the [Docker](https://github.com/madhuvanesh/python_lambda_container/blob/main/app/Dockerfile) file describes:
1. Copy the requirements.txt with the list of dependent libraries onto the container's current directory.
2. Install the libraries on the root folder as defined by the AWS reserved variable LAMBDA_TASK_ROOT.
3. The matplotlib library uses a folder defined in the environment variable MPLCONFIGDIR to store some caches to improve performance. The Lambda execution environment provides a file system for our code to use at /tmp. So the Docker file has commands to create a /tmp/matplotlib folder and set the environment variable to it.  
4. Finally the CMD is set to app.handler function - The handler() function in the app.py file.

## The Terraform code to package the Lambda and deploy it
Install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-cli).
The terraform code in <location where you cloned the repository from Github>/terraform/lambda.tf does the following:
1. Creates the input and output s3 locations.
2. Creates the ECR repository such that it can be deleted when terraform destroy is called.
4. Creates the docker image and pushes the same to the ECR repository. 
5. Creates the AWS IAM role that allows the AWS Lambda service to execute the Lambda function.
6. Creates the IAM policy and assigns it to the role. The IAM policy will allow the creation of Cloudwatch log group and log stream, 
provide read access on the input s3 location and write access on the output s3 location.
7. Creates the lambda function and assigns the AWS IAM role to it. Also, adds the environment variable for the output s3 bucket and the output filename.
8. Finally creates the trigger for the Lambda which is upload of a file to the input s3 location.

The terraform script has been tested on Linux subsystem in Windows. Also, this was tested using Docker Desktop on Windows. 
So if you are on Windows:
1. Install Docker desktop from [here](https://www.docker.com/products/docker-desktop/).
2. Run Docker Desktop.
2. Please enable the Linux subsystem. See these [instructions](https://learn.microsoft.com/en-us/windows/wsl/install).
3. Launch the bash terminal and execute these:
### cd <location where you cloned the repository from Github>/terraform
### terraform init
### terraform plan -out=./plan.txt
### terraform apply ./plan.txt
If you see no errors from the above commands , you should see the Lambda deployed in your AWS account as 
**reportgen-<randomId>-function**
Upload the CSV file [cost_of_living_v2.csv](https://github.com/madhuvanesh/python_lambda_container/blob/main/test_input/cost-of-living_v2.csv). You will see the output .png file generated in the output S3 location.

Once you have tested, cleanup using:
### terraform destroy
so that you do not incur charges.
  
