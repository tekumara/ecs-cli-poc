# Makefile for deploying

MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := help
.PHONY: *

# we get these from CI environment if available, otherwise from git
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
CLUSTER ?= my-cluster
WORKSPACE ?= $(shell pwd)

tag := branch-$(shell basename $(GIT_BRANCH))

## Display this help message
help:
	@awk '/^##.*$$/,/[a-zA-Z_-]+:/' $(MAKEFILE_LIST) | awk '!(NR%2){print $$0p}{p=$$0}' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' | sort

## Deploy antonginx service to ECS
autonginx:
	cd autonginx &&  ecs-cli compose service up --enable-service-discovery

## Print environment for build debugging
debug:
	@echo WORKSPACE=$(WORKSPACE)
	@echo GIT_COMMIT=$(GIT_COMMIT)
	@echo GIT_BRANCH=$(GIT_BRANCH)
	@echo tag=$(tag)

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


check_var = $(foreach 1,$1,$(__check_var))
__check_var = $(if $(value $1),,\
	$(error Missing $1 $(if $(value 2),$(strip $2))))
