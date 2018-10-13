# Makefile for deploying

MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := help
.PHONY: debug help install-ecs-cli configure create-stack describe-vpc autonginx-up autonginx-down autonginx-ps

AWS_REGION ?= $(shell aws configure get region)
CLUSTER ?= my-cluster
DEFAULT_LAUNCH_TYPE ?= FARGATE
service = autonginx

## print environment for build debugging
debug:
	@echo AWS_REGION=$(AWS_REGION)
	@echo CLUSTER=$(CLUSTER)
	@echo DEFAULT_LAUNCH_TYPE=$(DEFAULT_LAUNCH_TYPE)
	@echo service=$(service)

## display this help message
help:
	@awk '/^##.*$$/,/^[~\/\.a-zA-Z_-]+:/' $(MAKEFILE_LIST) | awk '!(NR%2){print $$0p}{p=$$0}' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' | sort

## install ecs-cli from source
ecs-cli-install: /tmp/src/github.com/aws/amazon-ecs-cli
	# we need the servicediscovery branch so build from source
	export GOPATH=/tmp && cd /tmp/src/github.com/aws/amazon-ecs-cli && git checkout servicediscovery && make
	cp /tmp/src/github.com/aws/amazon-ecs-cli/bin/local/ecs-cli /usr/local/bin/ecs-cli

# Install ecs-cli stable (MacOS X)
#install-mac:
	# latest version
	# brew install amazon-ecs-cli

/tmp/src/github.com/aws/amazon-ecs-cli:
	git clone git@github.com:aws/amazon-ecs-cli.git /tmp/src/github.com/aws/amazon-ecs-cli

## configure ecs cli (creates ~/.ecs/config)
ecs-cli-configure: ~/.ecs/config

~/.ecs/config:
	ecs-cli configure --cluster "${CLUSTER}" --region "${AWS_REGION}" --config-name "${CLUSTER}" --default-launch-type "${DEFAULT_LAUNCH_TYPE}"

## create ecs task execution iam role
create-iam-role:
	aws iam --region "${AWS_REGION}" create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://task-execution-assume-role.json
	aws iam --region "${AWS_REGION}" attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

## create a secruity group with port 80 access from anywhere
create-sg:
	$(eval VPC_ID = $(call fetch_vpc_id))
	$(eval SECURITY_GROUP_ID = $(shell aws ec2 create-security-group --group-name "${CLUSTER}" --description "${CLUSTER}" --vpc-id "${VPC_ID}" | jq -r '.GroupId'))
	aws ec2 authorize-security-group-ingress --group-id "${SECURITY_GROUP_ID}" --protocol tcp --port 80 --cidr 0.0.0.0/0

## create ecs cluster vpc resources
create-vpc: ecs-cli-configure
	ecs-cli up
	@echo Created stack amazon-ecs-cli-setup-"${CLUSTER}" with the following resources
	@aws cloudformation list-stack-resources --stack-name amazon-ecs-cli-setup-"${CLUSTER}" | jq -r '.StackResourceSummaries[] | [.LogicalResourceId, .PhysicalResourceId, .ResourceType] | @tsv' | column -t

## describe ecs cluster vpc
describe-vpc:
	$(eval VPC_ID = $(call fetch_vpc_id))
	@aws ec2 describe-vpcs --vpc-ids "${VPC_ID}" | jq -r '.Vpcs[0] | [.VpcId, .CidrBlock] | @tsv' | column -t
	@aws ec2 describe-subnets --filter Name=vpc-id,Values="${VPC_ID}" | jq -r '.Subnets[] | [.SubnetId, .AvailabilityZone, .CidrBlock, .MapPublicIpOnLaunch] | @tsv' | column -t

## list services running on the cluster
list-services:
	@aws ecs list-services --cluster "${CLUSTER}" | jq -r '.serviceArns[]'

## logs for the specified container, eg: container=nginx
logs:
	$(eval TASK_ID = $(shell aws ecs list-tasks --cluster "${CLUSTER}" --service-name "${service}" | jq -r '.taskArns[]' | grep -o '/.*' | tail -c +2))
	ecs-cli logs --task-id "${TASK_ID}" --container-name "${container}" --follow

## service - deploy
up: ecs-cli-configure
	@cd "${service}" &&  ecs-cli compose service up --cluster-config "${CLUSTER}" --enable-service-discovery --private-dns-namespace cluster --vpc $(call fetch_vpc_id)

## service - terminate
down: ecs-cli-configure
	@cd "${service}" &&  ecs-cli compose service down --cluster-config "${CLUSTER}"

## service - list containers
ps: ecs-cli-configure
	@cd "${service}" &&  ecs-cli compose service ps --cluster-config "${CLUSTER}"


fetch_vpc_id = $(shell aws cloudformation list-stack-resources --stack-name amazon-ecs-cli-setup-"${CLUSTER}" | jq -r '.StackResourceSummaries[] | select(.LogicalResourceId == "Vpc") | .PhysicalResourceId')