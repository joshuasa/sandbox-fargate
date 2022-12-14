# Fargate SandBox: Python on AWS Tutorial App

Python Tutorial Application integrating with various AWS Services. Runs in a Docker Container on **Fargate**. You can run Fargate on either AWS ECS (Elastic Container Service) or AWS EKS (Elastic Kubernetes Service). In this tutorial we'll be using ECS.

### Some of the things we'll be doing:

- Install and configure **AWS CLI**
- Use **AWS ECR** as our container registry
- **Manually run** container on Fargate **passing different commands** using AWS CLI
- Directly interact (login) with our container running on **Fargate** using **Amazon ECS Exec**
- Pass **environment variables** to container using an environment variable file stored in a **S3 Bucket**
- Log container output to **AWS CloudWatch Logs**
- Monitor CloudWatch Logs, sending notifications under certain conditions using **AWS Lambda**
- Schedule running of container using **Amazon EventBridge**

To get a proper understanding of the configuration involved we'll do a setup using the **AWS Console** and/or **AWS CLI**. Later we'll do the same setup using **AWS Copilot** as well as one using **AWS CDK**.

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

Verify installation:

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

### Session Manager plugin for AWS CLI

Required for **Amazon ECS Exec** that we'll be using to directly interact with containers.

Install & Uninstall:

```shell
# download
$ curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"

# install
$ sudo dpkg -i session-manager-plugin.deb

# if you want to uninstall
$ sudo dpkg -r session-manager-plugin
```

Verify installation:

```shell
$ session-manager-plugin
$ session-manager-plugin --version
```

## AWS S3 (Simple Storage Service)

We need a **S3 Bucket** accessable by container. **Access Key** (Access Key ID & Secret Access Key) required by AWS SDK for Python (Boto3) will be injected into container as environment variables. The environment variable (`.env`) file required to do this will be stored in the bucket.

- Create a S3 Bucket using the S3 Console. Select **Buckets** and choose **Create Bucket**.
- Enter **Bucket Name** [`sandbox-fargate`] and select **AWS Region**. Leave the rest as is and choose **Create Bucket**.

## AWS IAM (Identity and Access Management) Roles and Policies

### ECS Task Role

`ecsTaskRole`

Amazon ECS tasks can have an IAM role associated with them. The permissions granted in the IAM role are assumed by the containers running in the task.

**Create IAM Policy for required SSM permissions**

`SSMPermissionsForEcsExec`

The **ECS Exec** feature requires a task IAM role to grant containers the permissions needed for communication between the managed SSM agent and the SSM service.

In the **IAM Console**:

- Choose **Policies** and then **Create Policy**
- Select the **JSON Tab** and paste the following:

```json
{
   "Version": "2012-10-17",
   "Statement": [
       {
       "Effect": "Allow",
       "Action": [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel"
       ],
      "Resource": "*"
      }
   ]
}
```

- Choose **Next: Tags** and then **Next: Review**
- Under **Name** enter `SSMPermissionsForEcsExec` and choose **Create Policy**

**Create IAM Role for Tasks**

`ecsTaskRole`

In the **IAM Console**:

- Choose **Roles** and then **Create Role**
- For **Select Trusted Entity** choose **AWS Service**
- For **Use Case** select **Elastic Container Service** then **Elastic Container Service Task** and then choose **Next**
- Under **Add Permissions** choose the policy we've just created (`SSMPermissionsForEcsExec`) and then **Next**
- On **Step 3** for **Role Name** enter `ecsTaskRole` and choose **Create Role**

### ECS Task Execution Role

`ecsTaskExecutionRole`

The task execution IAM role grants the ECS agent permission to make AWS API calls on your behalf.

To create the task execution role in the **IAM Console**:

- In the console choose **Roles**, **Create Role**
- For **Trusted Entity Type** choose `AWS Service`, **Use Case** `Elastic Container Service Task` then choose Next.
- Under **Permissions Policies** search for `AmazonECSTaskExecutionRolePolicy` and select. Under **Set Permissions Boundary** choose **Create role without a permissions boundary** and then choose Next.
- Under **Role Details**, for Role Name enter `ecsTaskExecutionRole`. Leave the rest as is and choose **Create Role**.

`AmazonECSTaskExecutionRolePolicy` JSON:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
```

### ECS Task Execution Role: Access to S3 Bucket

`S3BucketSandboxFargateRead`

As mentioned when creating the S3 Bucket above, the environment variable file will be pulled from Amazon S3. We need to add permissions to `ecsTaskExecutionRole` to be able to access to this S3 Bucket:

- In the **IAM Console** choose **Roles** and select `ecsTaskExecutionRole`.
- Under **Permissions**, **Add Permissions** select **Create Inline Policy**.
- Select **Choose A Service** and then `S3`. Under **Actions** select `GetObject`. Under **Resources** choose **Specific** and next to **Object** choose **Add ARN**. Enter **Bucket Name** `sandbox-fargate` and for **Object** select **Any**.
- Select **Add Addisional Permissions**.
- Select **Choose A Service** and then `S3`. Under **Actions** select `GetBucketLocation`. Under **Resources** choose **Specific** and next to **Bucket** choose **Add ARN**. Enter **Bucket Name** `sandbox-fargate`.
- Choose **Review Policy**, enter **Name** `S3BucketSandboxFargateRead` and then **Create Policy**.

`S3BucketSandboxFargateRead` JSON:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::sandbox-fargate/*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:GetBucketLocation",
            "Resource": "arn:aws:s3:::sandbox-fargate"
        }
    ]
}
```

### ECS Service-Linked Role

`AWSServiceRoleForECS`

ECS uses a service-linked role for the permissions the service requires to call other AWS services. As the name implies, a service-linked role is a unique type of IAM role that is linked directly to an AWS service.

You don't need to manually create the service-linked role. When you create a new cluster ECS creates the service-linked role for you. In the **IAM Console** under **Roles** you can take a look at the permissions granted by `AWSServiceRoleForECS`.

## AWS ECR (Elastic Container Registry)

Tutorial stores Docker Images on ECR. **AWS CLI** must be installed and configured (`aws configure`) for examples below to work.

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

## AWS Fargate

We'll be setting up AWS ECS (Elastic Container Service) with a **Fargate Launch Type** to run our Docker Container.

### Task Definition

Using the **ECS Console** (new experience):

- Select **Task Definitions** and choose **Create New Task Definition**
- Enter `sandbox` for **Task Definition Family**. Used to group multiple versions, also referred to as revisions, of the same task definition
- Under **Container Details** enter **Name** [`sandbox-fargate`] and <br>**Image URI** [`{aws_account_id}.dkr.ecr.{region}.amazonaws.com/sandbox-fargate:latest`]
- We don't need any **Port Mappings** for this tutorial, you can remove the default port 80 mapping and choose **Next**
- Under **Environment** choose `AWS Fargate` for **App Environment**, `Linux/X86_64` for **Operating System/Architecture**, `.25 vCPU` for **CPU**, `.5 GB` for **Memory**
- Select **Task Role** select `ecsTaskRole` and `ecsTaskExecutionRole` for **Task Execation Role**
- Under **Monitoring and Logging** use the defaults (**Use Log Collection** & `Amazon CloudWatch`) and choose **Next**
- On **Review and Create** page choose **Create**

### Cluster

- Select **Clusters** and choose **Create Cluster**
- Enter `sandbox-cluster` for **Cluster Name** use the defaults for rest and choose **Create**

### Service

- Go to **Clusters** and select `sandbox-cluster` and with **Services** tab selected choose **Deploy**
- Under **Compute Configuration** for **Compute Options** select `Launch Type`, `Fargate` and `Latest`
- Under **Deployment Configuration** for **Application Type** select `Service`, **Family** `sandbox`, **Revision** `latest`, **Service Name** `sandbox-service` and **Desired Tasks** `1`
- For the rest use the defaults and choose **Deploy**

To allow **ECS Exec** to interact with containers run the following **AWS CLI** command on the service:

```shell
$ aws ecs update-service \
      --cluster sandbox-cluster \
      --task-definition sandbox \
      --service sandbox-service \
      --enable-execute-command
```

Note: You can select the service and choose **Edit** to set the **Desired Tasks** to `0` if you're just testing for example and only want to run a container/task as required.

## Amazon ECS Exec

With **Amazon ECS Exec** you can directly interact with containers on **Fargate** without needing to first open inbound ports or manage SSH keys.

ECS Exec makes use of **AWS Systems Manager (SSM) Session Manager** to establish a connection with the running container and uses AWS IAM policies to control access. This is made possible by bind-mounting the necessary SSM agent binaries into the container. The AWS Fargate agent is responsible for starting the SSM core agent inside the container alongside your application code.

The following gives you a command line inside a running Fargate container:

```shell
$ aws ecs execute-command \
      --cluster sandbox-cluster \
      --task {task-id} \
      --container sandbox-fargate \
      --interactive \
      --command "bash"
```

Make sure that the role of the profile used to run the AWS CLI contains a policy that allows the action `ecs:ExecuteCommand`:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "User access to ECS ExecuteCommand",
            "Effect": "Allow",
            "Action": "ecs:ExecuteCommand",
            "Resource": "*"
        }
    ]
}
```