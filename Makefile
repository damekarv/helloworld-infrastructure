.PHONY: init plan apply destroy vendor-charts validate

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply

destroy:
	cd terraform && terraform destroy

vendor-charts:
	./scripts/vendor_charts.sh

validate:
	cd terraform && terraform validate

all: vendor-charts init plan
