# Fargate SandBox: Python on AWS Tutorial App

Development Environment.
1. Remote Ubuntu 20.04 LTS VM running on EC2. Except for IDE everything is installed and running on Ubuntu devbox - Python virtual environments & libraries, Source Code, Git, Docker, AWS CLI, etc.
2. Local machine running Visual Studio Code with Remote SSH extension and Terminal connecting to EC2 VM. Local machine therefore just being used as IDE frontend to remote Ubuntu devbox.

## AWS ECR (Elastic Container Registry)

Docker images for this tutorial are stored on AWS ECR. `AWS CLI` must be installed and configured (`aws configure`) for examples below to work.

One way of pushing images to ECR is to first do a `docker login`. Get the ECR login password with `AWS CLI` and pipe to `docker login`.

```shell
$ aws ecr get-login-password --region {region} | docker login --username AWS --password-stdin {aws_account_id}.dkr.ecr.{region}.amazonaws.com
```

For this tutorial however I'm using the [Amazon ECR Docker Credential Helper](https://github.com/awslabs/amazon-ecr-credential-helper).