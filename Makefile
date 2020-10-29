.PHONY: clean build_image generate update-repos open-pull-requests docs

IMAGE_NAME        = infarm-protos-generator
PROTOBUF_DOC_GEN  = docker run --rm -v $(INPUT_DIR):/protos -v $(OUTPUT_DOC):/out pseudomuto/protoc-gen-doc
DATA_MODEL_BRANCH = update-data-model
export DATA_MODEL_BRANCH


UPDATE_TOOL  = $(CURDIR)/tools/update_repos.sh
OPEN_PR_TOOL = $(CURDIR)/tools/gh_pull_request.sh

INPUT_DIR   := $(CURDIR)/protos
TOOLS_DIR	:= $(CURDIR)/tools
MSGUTILS_DIR:= $(CURDIR)/msgutils
OUTPUT_DIR  := $(CURDIR)/output
OUTPUT_C    := $(OUTPUT_DIR)/c
OUTPUT_GO   := $(OUTPUT_DIR)/go
OUTPUT_PY   := $(OUTPUT_DIR)/python
OUTPUT_JS   := $(OUTPUT_DIR)/js
OUTPUT_DOCS := $(CURDIR)/docs
OUTPUT_FRAGS := $(CURDIR)/fragments
OUTPUT_DIRS := $(OUTPUT_GO) $(OUTPUT_PY) $(OUTPUT_JS) $(OUTPUT_FRAGS)/msg_model $(OUTPUT_FRAGS)/msg_model_cloud $(OUTPUT_FRAGS)/msg_model_controller $(OUTPUT_FRAGS)/ctrl_container $(OUTPUT_FRAGS)/cloud_container $(OUTPUT_FRAGS)/serv_container $(OUTPUT_FRAGS)/local_container

all:
	$(MAKE) clean
	$(MAKE) generate

clean: ## clean generated protos
	@rm -rf $(OUTPUT_DIR) ${OUTPUT_FRAGS} ${OUTPUT_DOCS}

generate: build_image clean ## generate protos
	@echo "Entering dir '$(INPUT_DIR)'" # Used to direct vim to the right file if error occurs
	@mkdir -p $(OUTPUT_DIRS)
	@docker run --rm \
		-v $(INPUT_DIR):/protos \
		-v $(TOOLS_DIR):/tools \
		-v $(MSGUTILS_DIR):/msgutils \
		-v $(OUTPUT_C):/output_c \
		-v $(OUTPUT_GO):/output_go \
		-v $(OUTPUT_PY):/output_python \
		-v $(OUTPUT_JS):/output_js \
		-v $(OUTPUT_FRAGS):/output_frags \
		-v $(OUTPUT_DOCS):/output_docs \
		-v $(CURDIR):/go/src/github.com/infarm/iot-data-model \
		$(IMAGE_NAME)
	@echo "Leaving dir"

test:
	go test -v ./msgutils/go

debug-bin:
	mkdir debug
	cd protos && protoc --debug_out=".:." */*.proto */*/*.proto


update-repos: generate ## update repos with latest data-model
	# Create a new tag
	$(CREATE_TAG_TOOL)

	# update-repo clones the repository specified with -r pulling only the branch -b, it then performs a merge of the branch -p
	# creates a new branch specified with -n and copy the protos files (-s) into the folder -d
	# if you don't have any complex repository system (master is not your default branch) and you work mainly on master you can keep -b and -p as master
	# $(UPDATE_TOOL) -r iot-farm-controller -b $(DATA_MODEL_BRANCH) -p develop -t source -s $(OUTPUT_C)/ctrl_container/. -d protobuf_api/protos
	$(UPDATE_TOOL) -r aratrum -b master -p master -n $(DATA_MODEL_BRANCH) -t source -s $(OUTPUT_PY)/. -d src/aratrum/protos
	$(UPDATE_TOOL) -r fake2 -b master -p master -n $(DATA_MODEL_BRANCH) -t source -s $(OUTPUT_PY)/. -d src/fake2/protos
	$(UPDATE_TOOL) -r pachamama -b master -p master -n $(DATA_MODEL_BRANCH) -t source -s $(OUTPUT_PY)/. -d src/monitoring_platform/protos
	$(UPDATE_TOOL) -r gen2-dashboards -b master -p master -n $(DATA_MODEL_BRANCH) -t source -s $(OUTPUT_PY)/. -d src/dashboards/protos
	# update the iot-... repos
	$(UPDATE_TOOL) -r iot-go-common -b $(CIRCLECI_BRANCH) -p $(CIRCLECI_BRANCH) -n $(DATA_MODEL_BRANCH) -t version
	$(UPDATE_TOOL) -r iot-farm-cloud-service -b $(CIRCLECI_BRANCH) -p $(CIRCLECI_BRANCH) -n $(DATA_MODEL_BRANCH) -t version
	$(UPDATE_TOOL) -r iot-farm-local-service -b $(CIRCLECI_BRANCH) -p $(CIRCLECI_BRANCH) -n $(DATA_MODEL_BRANCH) -t version
	$(UPDATE_TOOL) -r iot-farm-growing-service -b $(CIRCLECI_BRANCH) -p $(CIRCLECI_BRANCH) -n $(DATA_MODEL_BRANCH) -t version
	$(UPDATE_TOOL) -r iot-farm-update-service -b $(CIRCLECI_BRANCH) -p $(CIRCLECI_BRANCH) -n $(DATA_MODEL_BRANCH) -t version
	$(UPDATE_TOOL) -r iot-farm-cellular-service -b $(CIRCLECI_BRANCH) -p $(CIRCLECI_BRANCH) -n $(DATA_MODEL_BRANCH) -t version
	$(UPDATE_TOOL) -r iot-farm-testing-service -b $(CIRCLECI_BRANCH) -p $(CIRCLECI_BRANCH) -n $(DATA_MODEL_BRANCH) -t version

open-pull-requests: update-repos ## open pull-requests on repos that use data-model
	# $(OPEN_PR_TOOL) -r iot-farm-controller -b develop -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	# -r is the remote repository, -b is branch of the remote repository you want to use as a base
	# -h is the branch you would to merge (in our case the one with the new protos)
	$(OPEN_PR_TOOL) -r aratrum -b master -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	$(OPEN_PR_TOOL) -r fake2 -b master -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	$(OPEN_PR_TOOL) -r pachamama -b master -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	$(OPEN_PR_TOOL) -r gen2-dashboards -b master -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	# create PR for the iot-... repos
	$(OPEN_PR_TOOL) -r iot-go-common -b $(CIRCLECI_BRANCH) -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	$(OPEN_PR_TOOL) -r iot-farm-cloud-service -b ${CIRCLECI_BRANCH} -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN) 
	$(OPEN_PR_TOOL) -r iot-farm-local-service -b ${CIRCLECI_BRANCH} -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN) 
	$(OPEN_PR_TOOL) -r iot-farm-growing-service -b ${CIRCLECI_BRANCH} -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	$(OPEN_PR_TOOL) -r iot-farm-update-service -b ${CIRCLECI_BRANCH} -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	$(OPEN_PR_TOOL) -r iot-farm-cellular-service -b ${CIRCLECI_BRANCH} -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN)
	$(OPEN_PR_TOOL) -r iot-farm-testing-service -b ${CIRCLECI_BRANCH} -h $(DATA_MODEL_BRANCH) -t $(GITHUB_TOKEN) 

build_image: ## build docker image
	@docker build -t $(IMAGE_NAME) --build-arg USER_ID=$(shell id -u) .

acre-2stage-farm-config-helper: ## build the farm-config-helper-acre-2stage and prints the config in base64
	@go run ./helpers/farm-config-helper-acre-2stage

acre-3stage-farm-config-helper: ## build the farm-config-helper-acre-3stage and prints the config in base64
	@go run ./helpers/farm-config-helper-acre-3stage

instore-farm-config-helper: ## build the farm-config-helper-instore and prints the config in base64
	@go run ./helpers/farm-config-helper-instore

help: ## Display this help screen
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
