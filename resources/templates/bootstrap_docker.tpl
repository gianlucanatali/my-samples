#!/bin/bash

# Create dirs for Kafka / ZK data
mkdir -p mounts/data/zk-data
mkdir -p mounts/logs/zk-txn-logs
mkdir -p mounts/data/kafka-data

# Make sure user docker has r/w permissions
chown -R ${dc} mounts/data/zk-data
chown -R ${dc} mounts/logs/zk-txn-logs
chown -R ${dc} mounts/data/kafka-data

cd ~/.workshop/docker
# Create ccloud.properties file
echo "ssl.endpoint.identification.algorithm=https" >> ccloud.properties
echo "sasl.mechanism=PLAIN" >> ccloud.properties
echo "request.timeout.ms=20000" >> ccloud.properties
echo "bootstrap.servers=${ccloud_cluster_endpoint}" >> ccloud.properties
echo "retry.backoff.ms=500" >> ccloud.properties
echo "sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${ccloud_api_key}\" password=\"${ccloud_api_secret}\";" >> ccloud.properties
echo "security.protocol=SASL_SSL" >> ccloud.properties

# Create .env file for Docker
echo "EXT_IP=${ext_ip}" >> .env
echo "CCLOUD_CLUSTER_ENDPOINT=${ccloud_cluster_endpoint}" >> .env
echo "CCLOUD_API_KEY=${ccloud_api_key}" >> .env
echo "CCLOUD_API_SECRET=${ccloud_api_secret}" >> .env
echo "HOSTNAME"=$HOSTNAME >> .env
echo "DC"=${dc} >> .env
echo "CCLOUD_TOPICS"=${ccloud_topics} >> .env
echo "CCLOUD_SR_ENDPOINT=${ccloud_sr_endpoint}" >> .env
echo "CCLOUD_SR_API_KEY=${ccloud_sr_api_key}" >> .env
echo "CCLOUD_SR_API_SECRET=${ccloud_sr_api_secret}" .env
echo "TAG=5.5.0" >> .env

# select the DC correctly in the database simulator script and schema file.
sed -i 's/dcxx/${dc}/g' ~/.workshop/docker/db_transaction_simulator/simulate_dbtrans.py
sed -i 's/dcxx/${dc}/g' ~/.workshop/docker/mysql_schema.sql

# Generate html file for the hosted instructions
cd ~/.workshop/docker/asciidoc
asciidoctor index.adoc -o index.html -a stylesheet=stylesheet.css -a externalip=${ext_ip} -a dc=${dc} -a "feedbackformurl=${feedback_form_url}"

# startup the containers
cd ~/.workshop/docker/
docker-compose up -d

export VAR_CCLOUD_SR_ENDPOINT="${ccloud_sr_endpoint}"
export VAR_CCLOUD_SR_API_KEY="${ccloud_sr_api_key}"
export VAR_CCLOUD_SR_API_SECRET="${ccloud_sr_api_secret}"

#source scripts/start_demo.sh

# cd ~/.workshop/docker/extensions
# for extension in */ ; do
#     if [ -d $extension/docker ]; then
#         cd $extension/docker
#         echo "" >> .env
#         cat ../../../.env >> .env
#         docker-compose -f docker-compose.yaml up -d
#         cd ../../
#     fi
# done
