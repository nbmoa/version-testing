.PHONY: clean build_image generate update-repos open-pull-requests docs

CREATE_TAG_TOOL  = $(CURDIR)/tools/create_tag.sh

all:
	@echo nothing to do here

create-tags: ## update repos with latest data-model
	# Create a new tag
	$(CREATE_TAG_TOOL)


help: ## Display this help screen
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
