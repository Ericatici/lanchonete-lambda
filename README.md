# Lanchonete Lambda Function

This repository contains an AWS Lambda function, likely serving as a microservice or an authentication gateway, for the "Lanchonete Na Comanda" system. The function is developed in Python and its deployment is managed using Terraform.

## Project Structure

*   `lambda_function.py`: The main Python code for the AWS Lambda function.
*   `requirements.txt`: Lists the Python dependencies required by the Lambda function.
*   `main.tf`: Terraform configuration for defining and deploying the AWS Lambda function, including its IAM role, triggers, and associated resources.
*   `terraform.tfvars`: (Optional) Contains default or environment-specific variable values for Terraform.
*   `package/`: Directory containing the zipped deployment package for the Lambda function, including `lambda_function.py` and its dependencies.

## Technologies Used

*   **AWS Lambda**: Serverless compute service that runs code in response to events.
*   **Python**: The programming language used for the Lambda function.
*   **Terraform**: Infrastructure as Code (IaC) tool for provisioning and managing the AWS Lambda function and its related infrastructure.
*   **AWS IAM**: Identity and Access Management for defining roles and permissions for the Lambda function.

## Setup and Deployment

### Prerequisites

*   Terraform CLI installed.
*   AWS CLI configured with appropriate credentials.
*   Python 3.x and `pip` installed.

### Local Development

1.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt -t package/
    ```
    This command installs all dependencies into the `package/` directory, preparing them for Lambda deployment.

2.  **Develop `lambda_function.py`**:
    Write or modify your Lambda function logic in `lambda_function.py`.

### Deployment Steps

1.  **Prepare Deployment Package**:
    Ensure all Python dependencies are in the `package/` directory alongside `lambda_function.py`.
    ```bash
    # If you made changes to lambda_function.py or requirements.txt, re-run:
    rm -rf package/* # Clear previous package
    pip install -r requirements.txt -t package/
    cp lambda_function.py package/
    cd package
    zip -r ../lambda_function.zip .
    cd ..
    ```

2.  **Initialize Terraform**:
    ```bash
    terraform init
    ```

3.  **Review the Plan**:
    ```bash
    terraform plan
    ```
    This command shows what actions Terraform will take to create or modify your Lambda function.

4.  **Apply the Configuration**:
    ```bash
    terraform apply
    ```
    Confirm the actions by typing `yes` when prompted. This will deploy or update the AWS Lambda function in your AWS account.

## Usage

Once deployed, the Lambda function can be invoked by its configured triggers (e.g., API Gateway, SQS, S3 events) or directly via the AWS CLI or AWS Management Console.
