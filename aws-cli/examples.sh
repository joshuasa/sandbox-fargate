# run with default command
aws ecs run-task \
    --cluster sandbox-cluster \
    --task-definition sandbox:8 \
    --launch-type="FARGATE" \
    --network-configuration file://network.json

# run with provided overrides & enable-execute-command
aws ecs run-task \
    --cluster sandbox-cluster \
    --task-definition sandbox:8 \
    --launch-type="FARGATE" \
    --network-configuration file://network.json \
    --overrides file://overrides.json \
    --enable-execute-command

# get fargate container command-line prompt
aws ecs execute-command \
      --cluster sandbox-cluster \
      --task 5a74fde3e2414eef97120f6ab41bfe4e \
      --container sandbox-fargate \
      --interactive \
      --command "bash"