# Makefile for deploying

MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := help
.PHONY: debug help install-ecs-cli configure create-stack autonginx-up autonginx-down autonginx-ps

AWS_REGION := $(shell aws configure get region)

CLUSTER ?= my-cluster

## Print environment for build debugging
debug:
	@echo CLUSTER=$(CLUSTER)

## Display this help message
help:
	@awk '/^##.*$$/,/^[~\/\.a-zA-Z_-]+:/' $(MAKEFILE_LIST) | awk '!(NR%2){print $$0p}{p=$$0}' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' | sort

## Install ecs-cli from source
install-ecs-cli: /tmp/src/github.com/aws/amazon-ecs-cli
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
configure: ~/.ecs/config

~/.ecs/config:
	ecs-cli configure --cluster "${CLUSTER}" --region "${AWS_REGION}" --config-name "${CLUSTER}" --default-launch-type FARGATE

## create new ecs cluster resources (ie: VPC)
create-stack: configure
	ecs-cli up
	@echo Created stack amazon-ecs-cli-setup-"${CLUSTER}" with the following resources
	@aws cloudformation list-stack-resources --stack-name amazon-ecs-cli-setup-"${CLUSTER}" | jq -r '.StackResourceSummaries[] | [.LogicalResourceId, .PhysicalResourceId, .ResourceType] | @tsv' | column -t

## antonginx service - deploy
autonginx-up: configure
	cd autonginx &&  ecs-cli compose service up --enable-service-discovery --cluster-config "${CLUSTER}"

## antonginx service - terminate
autonginx-down: configure
	cd autonginx &&  ecs-cli compose service down --cluster-config "${CLUSTER}"

## antonginx service - list containers
autonginx-ps: configure
	cd autonginx &&  ecs-cli compose service ps --cluster-config "${CLUSTER}"

