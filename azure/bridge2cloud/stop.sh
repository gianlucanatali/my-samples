#!/bin/bash
set -e

THIS_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
RESOURCES_DIR=$THIS_DIR/../../resources
TERRAFORM_DIR=${THIS_DIR}/terraform
STATE_FILE_PATH="${TERRAFORM_DIR}/terraform.tfstate"

function end_demo {
  # Source library
  source $RESOURCES_DIR/utils/scripts/helper.sh
  check_jq || exit 1

  # Destroy Demo Infrastructure using Terraform
  cd $TERRAFORM_DIR
  terraform destroy --auto-approve

  rm -f "${TERRAFORM_DIR}/config.auto.tfvars"

}

end_demo 2>&1 | tee -a zz_demo_destruction.log