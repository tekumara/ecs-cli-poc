# Overview

[ecs-cli](https://github.com/aws/amazon-ecs-cli). allows you to deploy and execute docker-compose style commands on an ECS cluster.

This project provides a Makefile and example application. The Makefile uses ecs-cli to create a Fargate ECS cluster including service discovery using a [private hosted zone](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html?#vpc-private-hosted-zones). 

# Example

This example deploys [autonginx](https://github.com/tekumara/autopilotpattern-nginx) with private DNS service discovery. 

Configure (otherwise the defaults in the `Makefile` will be used)
```
export AWS_REGION=$(aws configure get region)
export CLUSTER=my-cluster
export service=autonginx
```

Amazon ECS needs permissions so that your Fargate task can store logs in CloudWatch. This permission is covered by the task execution IAM role. For more information, see [Amazon ECS Task Execution IAM Role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html).
```
make create-iam-role
```

Install and configure ecs-cli. If this is the first time that you are configuring the ECS CLI, these configurations are marked as default.
```
make ecs-cli-install
make ecs-cli-configure
```

Create a VPC for the cluster
```
make create-vpc
```

What does the VPC look like?

```
make describe-vpc
```

Create a security group to allow inbound access on port 80 from 0.0.0.0/0
```
make create-sg
```

Modify [ecs-params.yml](autonginx/ecs-params.yml) and supply the subnets and security group id from the previous commands. (TODO - automatically template this)

Create the service on the cluster using the default launch type (Fargate)
```
make up
```

List services running on the cluster
```
make list-services
```

Inspect the containers running for the service. Each task gets its own ENI with an IP address.
```
make ps                                                      
```

Logs 
```
make logs container=nginx
```

Bring down the service
```
make down
```

Delete the cluster stack (make sure you have deleted the security group created above first)
```
ecs-cli down
```

## Docker-compose support

ecs-cli doesn't support
* minor versions, eg: 2.1 (v1, v2, v3 are supported)
* `build`
* `restart`
* `expose` 
* external volumes aren't supported and will error with `External option is not supported` but volumes can be created and linked to `ecs_params.yml`
* `links` - Links are not supported when networkMode=awsvpc
* `dns` - DNS servers are not supported on container when networkMode=awsvpc

When `networkMode=awsvpc`, the host ports and container ports in port mappings must match.

# Trouble shooting

`No Fargate configuration exists for given values`

Check `mem_limit` and `cpu_limit` are correct, see [valid limits here](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html)

# Reference

[Tutorial: Creating a Cluster with a Fargate Task Using the ECS CLI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_tutorial_fargate.html)
