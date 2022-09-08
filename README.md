# Fargate SandBox: Python on AWS Tutorial App

This Python Tutorial Application integrates with various AWS Services and runs in a Docker Container on Fargate on AWS ECS (Elastic Container Service).

## Development Environment.

1. Remote Ubuntu 20.04 LTS VM running on EC2. Except for IDE everything is installed and running on `Ubuntu DevBox` - Python virtual environments & libraries, Source Code, Git, Docker, AWS CLI, etc.
2. Local machine running Visual Studio Code with Remote SSH extension and Terminal connecting to EC2 VM. Local machine therefore just being used as IDE frontend to remote Ubuntu DevBox.

## AWS ECR (Elastic Container Registry)

Docker images for this tutorial are stored on AWS ECR. `AWS CLI` must be installed and configured (`aws configure`) for examples below to work.

One way of pushing images to ECR is to first do a `docker login`. Get the ECR login password with `AWS CLI` and pipe to `docker login`:

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

Create ECR repository using either the concole or `AWS CLI`:

```shell
aws ecr create-repository \
    --repository-name sandbox-fargate \
    --image-scanning-configuration scanOnPush=true \
    --region {region}
```

Now you can appropriately tag and push your image. No need for `docker login`, credentials are retrieved from `~/.aws/credentials` as created by `aws configure`.

```shell
$ docker tag sandbox-fargate {aws_account_id}.dkr.ecr.{region}.amazonaws.com/sandbox-fargate
$ docker push {aws_account_id}.dkr.ecr.{region}.amazonaws.com/sandbox-fargate
```