#!/bin/bash
set -e

THIS_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
RESOURCES_DIR=$THIS_DIR/../../resources
TERRAFORM_DIR=${THIS_DIR}/terraform
DOCKER_DIR=$THIS_DIR/docker
STATE_FILE_PATH="${TERRAFORM_DIR}/terraform.tfstate"



#brew install coreutils



################################################################################
# Overview
################################################################################
#
# See README.md for usage and disclaimers
# origin : https://github.com/confluentinc/examples/blob/5.4.0-post/ccloud/beginner-cloud/start.sh
#
################################################################################

# COUNT=$(timeout 3 ccloud kafka topic consume -b ORDERS_ENRICHED | wc -l); echo "$COUNT"

function welcome_screen {
    local DEMO_IP=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".external_ip_addresses.value[0]" -r)
    local DEMO_SITE="http://${DEMO_IP}"
    local C3_LINK="http://${DEMO_IP}:9021"
    local GRAFANA_LINK="http://${DEMO_IP}:3000/login"
    #REST PROXY 8082

    echo "                                                                                              ";
    echo "**********************************************************************************************";
    echo "                                                                                              ";
    echo "██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗                                ";
    echo "██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝                                ";
    echo "██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗                                  ";
    echo "██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝                                  ";
    echo "╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗                                ";
    echo " ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝                                ";
    echo "████████╗ ██████╗     ████████╗██╗  ██╗███████╗                                               ";
    echo "╚══██╔══╝██╔═══██╗    ╚══██╔══╝██║  ██║██╔════╝                                               ";
    echo "   ██║   ██║   ██║       ██║   ███████║█████╗                                                 ";
    echo "   ██║   ██║   ██║       ██║   ██╔══██║██╔══╝                                                 ";
    echo "   ██║   ╚██████╔╝       ██║   ██║  ██║███████╗                                               ";
    echo "   ╚═╝    ╚═════╝        ╚═╝   ╚═╝  ╚═╝╚══════╝                                               ";
    echo "██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗██████╗      ██████╗██╗      ██████╗ ██╗   ██╗██████╗     ";
    echo "██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║██╔══██╗    ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗    ";
    echo "███████║ ╚████╔╝ ██████╔╝██████╔╝██║██║  ██║    ██║     ██║     ██║   ██║██║   ██║██║  ██║    ";
    echo "██╔══██║  ╚██╔╝  ██╔══██╗██╔══██╗██║██║  ██║    ██║     ██║     ██║   ██║██║   ██║██║  ██║    ";
    echo "██║  ██║   ██║   ██████╔╝██║  ██║██║██████╔╝    ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝    ";
    echo "╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝      ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝     ";
    echo "██████╗ ███████╗███╗   ███╗ ██████╗ ██╗                                                       ";
    echo "██╔══██╗██╔════╝████╗ ████║██╔═══██╗██║                                                       ";
    echo "██║  ██║█████╗  ██╔████╔██║██║   ██║██║                                                       ";
    echo "██║  ██║██╔══╝  ██║╚██╔╝██║██║   ██║╚═╝                                                       ";
    echo "██████╔╝███████╗██║ ╚═╝ ██║╚██████╔╝██╗                                                       ";
    echo "╚═════╝ ╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝                                                       ";
    echo "                                                                                              ";
    echo "**********************************************************************************************";
    echo " ";
    echo " ";
    echo "Handy links: "
    echo " - Demo main page: ${DEMO_SITE} ";
    echo " - Confluent Control Center: ${C3_LINK}";
    echo " - Grafana: ${GRAFANA_LINK}";
}

function create_tfvars_file {
  TERRAFORM_CONFIG="${TERRAFORM_DIR}/config.auto.tfvars"
  echo -e "\n# Create a local configuration file $TERRAFORM_CONFIG with the terraform variables"
  cat <<EOF > $TERRAFORM_CONFIG
name         = $(cat demo_config.json | jq '.demo_name')
ccloud_bootstrap_servers = $(cat demo_config.json | jq '.ccloud.bootstrap_servers')
ccloud_api_key          = $(cat demo_config.json | jq '.ccloud.kafka_api_key')
ccloud_api_secret       = $(cat demo_config.json | jq '.ccloud.kafka_api_secret')
ccloud_topics           = $(cat demo_config.json | jq '.ccloud.topics_to_create')
ccloud_sr_endpoint      = $(cat demo_config.json | jq '.ccloud.sr_endpoint')
ccloud_sr_api_key       = $(cat demo_config.json | jq '.ccloud.sr_api_key')
ccloud_sr_api_secret    = $(cat demo_config.json | jq '.ccloud.sr_api_secret')
vm_password           = $(cat demo_config.json | jq '.azure.vm.password')
vm_type               = $(cat demo_config.json | jq '.azure.vm.type')
azure_subscription_id = $(cat demo_config.json | jq '.azure.subscription_id')
azure_client_id       = $(cat demo_config.json | jq '.azure.client_id')
azure_client_secret   = $(cat demo_config.json | jq '.azure.client_secret')
azure_tenant_id       = $(cat demo_config.json | jq '.azure.tenant_id')
azure_location        = $(cat demo_config.json | jq '.azure.location')
bootstrap_vm_template_path        = "${RESOURCES_DIR}/templates/bootstrap_vm.tpl"
bootstrap_docker_template_path    = "${RESOURCES_DIR}/templates/bootstrap_docker.tpl"
docker_folder_path                = "${DOCKER_DIR}"
EOF
}

function create_infra_with_tf (){
    
    cd ${TERRAFORM_DIR}
    terraform init
    terraform apply --auto-approve

}


function start_demo {

    source $RESOURCES_DIR/utils/scripts/helper.sh

    check_jq || exit 1

    FILE=demo_config.json
    if [ ! -f "$FILE" ]; then
        echo "You are missing the main configuration file! $FILE does not exist"
        exit 1
    fi

    #mkdir -p ../terraform/tmp

    create_tfvars_file

    # Create Demo Infrastructure using Terraform
    create_infra_with_tf

    welcome_screen
}

start_demo 2>&1 | tee -a zz_demo_creation.log


