# Fargate SandBox: Python on AWS Tutorial App

This Python Tutorial Application integrates with various AWS Services and runs in a Docker Container on Fargate on AWS ECS (Elastic Container Service).

## Development Environment

1. Remote Ubuntu 20.04 LTS VM running on EC2. Except for IDE everything is installed and running on **Ubuntu DevBox** - Python virtual environments & libraries, Source Code, Git, Docker, AWS CLI, etc.
2. Local machine running Visual Studio Code with Remote SSH extension and Terminal connecting to EC2 VM. Local machine therefore just being used as IDE frontend to remote Ubuntu DevBox.

## AWS CLI (Command Line Interface)

[AWS CLI v2](https://github.com/aws/aws-cli/tree/v2)

Install & Update:

```shell
$ curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
$ unzip awscliv2.zip
$ sudo ./aws/install

# update
$ sudo ./aws/install --update
```

Test:

```shell
$ aws --version
```

Before setting up and using **AWS CLI** you need to create an **Access Key** (**Access Key ID** & **Secret Access Key**) for the **AWS IAM** account you will be using. Go to the IAM console, select the user/account and then under **Security Credentials** choose **Create Access Key**.

Use the Access Key Credentials to configure:

```shell
# default profile
$ aws configure

# to config a named profile
$ aws configure --profile joshua
```

Configuration details are stored in `~/.aws/config` & `~/.aws/credentials`

## AWS IAM (Identity and Access Management)

### ECS Task Execution IAM Role

`ecsTaskExecutionRole`

The task execution role grants the Amazon ECS container and Fargate agents permission to make AWS API calls.

To create the task execution role in the **IAM Console**:

- In the console choose **Roles**, **Create Role**
- For **Trusted Entity Type** choose `AWS Service`, **Use Case** `Elastic Container Service Task` then choose Next.
- Under **Permissions Policies** search for `AmazonECSTaskExecutionRolePolicy` and select. Under **Set Permissions Boundary** choose **Create role without a permissions boundary** and then choose Next.
- Under **Role Details**, for Role Name use `ecsTaskExecutionRole`. Leave the rest as is and choose **Create Role**.

## AWS ECR (Elastic Container Registry)

This tutorial stores Docker Images on ECR. **AWS CLI** must be installed and configured (`aws configure`) for examples below to work.

One way of pushing images to ECR is to first do a `docker login`. Get the ECR login password with AWS CLI and pipe to `docker login`:

```shell
$ aws ecr get-login-password \
      --region {region} | \
  docker login \
      --username AWS \
      --password-stdin {aws_account_id}.dkr.ecr.{region}.amazonaws.com
```

For this tutorial however we're using the [Amazon ECR Docker Credential Helper](https://github.com/awslabs/amazon-ecr-credential-helper).

Install:

```shell
$ sudo apt install amazon-ecr-credential-helper
```

Add to `~/.docker/config.json`:

```json
{
    "credsStore": "ecr-login"
}
```

Create ECR repository using either the console or **AWS CLI**:

```shell
aws ecr create-repository \
    --repository-name sandbox-fargate \
    --image-scanning-configuration scanOnPush=true \
    --region {region}
```

Now you can appropriately tag and push your image. No need for `docker login`, credentials are retrieved from `~/.aws/credentials` as created by `aws configure`.

```shell
# tag
$ docker tag sandbox-fargate {aws_account_id}.dkr.ecr.{region}.amazonaws.com/sandbox-fargate

# push
$ docker push {aws_account_id}.dkr.ecr.{region}.amazonaws.com/sandbox-fargate
```

## AWS Fargate: Task Definition

We'll be setting up AWS ECS (Elastic Container Service) with a **Fargate Launch Type** to run our Docker Container. To get a proper understanding of everything involved we'll do a setup using the **ECS Console** and/or **AWS CLI**. Later we'll do the same setup using **AWS Copilot** as well as one using **AWS CDK**.

- Create a Task Definition using the **ECS Console** (new experience) and selecting **Task Definitions**. Choose **Create New Task Definition**.

- Specify **Task Definition Family** [`sandbox`]. Used to group multiple versions, also referred to as revisions, of the same task definition.

- Under **Container Details** secify **Name** [`sandbox-fargate`] and <br>**Image URI** [`{aws_account_id}.dkr.ecr.{region}.amazonaws.com/sandbox-fargate:latest`]