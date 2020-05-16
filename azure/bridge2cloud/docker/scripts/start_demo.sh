#!/bin/bash
wait-for-url() {
    echo "Testing $1"
    timeout -s TERM 500 bash -c \
    'while [[ "$(curl -s -o /dev/null -L -w ''%{http_code}'' ${0})" != "200" ]];\
    do echo "Waiting for ${0}" && sleep 2;\
    done' ${1}
    echo "OK!"
    curl -I $1
}

wait-for-schema() {
    URL_TO_TEST=$VAR_CCLOUD_SR_ENDPOINT/subjects/${1}-value/versions
    URL_AUTH=$VAR_CCLOUD_SR_API_KEY:$VAR_CCLOUD_SR_API_SECRET
    echo "Testing $URL_TO_TEST"
    timeout -s TERM 500 bash -c \
    'while [[ "$(curl -u ${1} -s -o /dev/null -L -w ''%{http_code}'' ${0})" != "200" ]];\
    do echo "Waiting for ${0}" && sleep 2;\
    done' ${URL_TO_TEST} ${URL_AUTH}
    echo "OK!"
    curl -u $URL_AUTH -I $URL_TO_TEST
}

#wait-for-url http://localhost:18083/connectors/
verify-connect-cluster() {
# Verify Kafka Connect Worker has started within 120 seconds
  MAX_WAIT=500
  CUR_WAIT=0
  CONNECT_DOCKER_NAME=$1
  echo "Waiting up to $MAX_WAIT seconds for Kafka Connect Worker to start"
  while [[ ! $(docker-compose logs $CONNECT_DOCKER_NAME) =~ "Kafka Connect started" ]]; do
    sleep 3
    CUR_WAIT=$(( CUR_WAIT+3 ))
    if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
      echo -e "\nERROR: The logs in Kafka Connect container do not show 'Kafka Connect started'. Please troubleshoot with 'docker-compose ps' and 'docker-compose logs'.\n"
      exit 1
    fi
  done
  echo "Kafka Connect Worker $CONNECT_DOCKER_NAME is up"
}

# Start producing sample transactions on mysql
echo "---Sleep 30..."
sleep 30
echo "---Start Transactions simulator..."
docker exec -dit db-trans-simulator sh -c "python -u /simulate_dbtrans.py > /proc/1/fd/1 2>&1"
echo "---Sleep 50..."
sleep 50
TRANS_COUNT=$(docker logs db-trans-simulator --tail 10 | wc -l)
if [ "$TRANS_COUNT" -lt 3 ]; then
  echo -e "\nERROR: The Transaction simulator doesn't seem to be working.\n"
  exit 1
fi


echo "---Start Transactions simulator..."

# Create the topics manually! TODO with retention one hour

verify-connect-cluster kafka-connect-onprem

# Configure CDC connector
curl -i -X POST -H "Accept:application/json" \
  -H  "Content-Type:application/json" http://localhost:18083/connectors/ \
  -d '{
    "name": "mysql-source-connector",
    "config": {
          "connector.class": "io.debezium.connector.mysql.MySqlConnector",
          "database.hostname": "mysql",
          "database.port": "3306",
          "database.user": "mysqluser",
          "database.password": "mysqlpw",
          "database.server.id": "12345",
          "database.server.name": "dc01",
          "database.whitelist": "orders",
          "table.blacklist": "orders.dc01_out_of_stock_events",
          "database.history.kafka.bootstrap.servers": "broker:29092",
          "database.history.kafka.topic": "debezium_dbhistory" ,
          "include.schema.changes": "true",
          "snapshot.mode": "when_needed",
          "transforms": "unwrap,sourcedc,TopicRename",
          "transforms.unwrap.type": "io.debezium.transforms.UnwrapFromEnvelope",
          "transforms.sourcedc.type":"org.apache.kafka.connect.transforms.InsertField$Value",
          "transforms.sourcedc.static.field":"sourcedc",
          "transforms.sourcedc.static.value":"dc01",
          "transforms.TopicRename.type": "org.apache.kafka.connect.transforms.RegexRouter",
          "transforms.TopicRename.regex": "(.*)\\.(.*)\\.(.*)",
          "transforms.TopicRename.replacement": "$1_$3"
      }
  }'

# Configure Replicator
#wait-for-url http://localhost:18084/connectors/

verify-connect-cluster kafka-connect-ccloud


curl -i -X POST -H "Accept:application/json" \
    -H  "Content-Type:application/json" http://localhost:18084/connectors/ \
    -d '{
        "name": "replicator-dc01-to-ccloud",
        "config": {
          "connector.class": "io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "topic.config.sync": false,
          "topic.regex": "dc[0-9][0-9][_].*",
          "topic.blacklist": "dc01_out_of_stock_events",
          "dest.kafka.bootstrap.servers": "${file:/secrets.properties:CCLOUD_CLUSTER_ENDPOINT}",
          "dest.kafka.security.protocol": "SASL_SSL",
          "dest.kafka.sasl.mechanism": "PLAIN",
          "dest.kafka.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${file:/secrets.properties:CCLOUD_API_KEY}\" password=\"${file:/secrets.properties:CCLOUD_API_SECRET}\";",
          "dest.kafka.replication.factor": 3,
          "src.kafka.bootstrap.servers": "broker:29092",
          "src.consumer.group.id": "replicator-dc01-to-ccloud",
          "src.consumer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor",
          "src.consumer.confluent.monitoring.interceptor.bootstrap.servers": "broker:29092",
          "src.kafka.timestamps.producer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor",
          "src.kafka.timestamps.producer.confluent.monitoring.interceptor.bootstrap.servers": "broker:29092",
          "tasks.max": "1"
        }
    }'

# Run KSQL Script
#copy files to root

#curl -sX GET "http://localhost:8088/info"
wait-for-url http://localhost:8088/info

wait-for-schema dc01_sales_orders
wait-for-schema dc01_sales_order_details
wait-for-schema dc01_purchase_orders
wait-for-schema dc01_purchase_order_details
wait-for-schema dc01_products
wait-for-schema dc01_customers
wait-for-schema dc01_suppliers

echo "---Start Running KSQL scripts..."
echo "------KSQL Create Initial Streams..."
docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM sales_orders WITH (KAFKA_TOPIC='dc01_sales_orders', VALUE_FORMAT='AVRO');
CREATE STREAM sales_order_details WITH (KAFKA_TOPIC='dc01_sales_order_details', VALUE_FORMAT='AVRO');
CREATE STREAM purchase_orders WITH (KAFKA_TOPIC='dc01_purchase_orders', VALUE_FORMAT='AVRO');
CREATE STREAM purchase_order_details WITH (KAFKA_TOPIC='dc01_purchase_order_details', VALUE_FORMAT='AVRO');
CREATE STREAM products WITH (KAFKA_TOPIC='dc01_products', VALUE_FORMAT='AVRO');
CREATE STREAM customers WITH (KAFKA_TOPIC='dc01_customers', VALUE_FORMAT='AVRO');
CREATE STREAM suppliers WITH (KAFKA_TOPIC='dc01_suppliers', VALUE_FORMAT='AVRO');
EOF

echo "------KSQL Create Rekeyed Streams..."
docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM customers_rekeyed WITH (KAFKA_TOPIC='dc01_customers_rekeyed', PARTITIONS=1) AS
SELECT * FROM customers
PARTITION BY id;

CREATE STREAM products_rekeyed WITH (KAFKA_TOPIC='dc01_products_rekeyed', PARTITIONS=1) AS
SELECT * FROM products
PARTITION BY id;

CREATE STREAM suppliers_rekeyed WITH (KAFKA_TOPIC='dc01_suppliers_rekeyed', PARTITIONS=1) AS
SELECT * FROM suppliers
PARTITION BY id;
EOF

wait-for-schema dc01_customers_rekeyed
wait-for-schema dc01_products_rekeyed
wait-for-schema dc01_suppliers_rekeyed

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE TABLE customers_tbl WITH (KAFKA_TOPIC='dc01_customers_rekeyed', VALUE_FORMAT='AVRO', key='id');
CREATE TABLE products_tbl WITH (KAFKA_TOPIC='dc01_products_rekeyed', VALUE_FORMAT='AVRO', key='id');
CREATE TABLE suppliers_tbl WITH (KAFKA_TOPIC='dc01_suppliers_rekeyed', VALUE_FORMAT='AVRO', key='id');
EOF

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM sales_enriched_01 WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_sales_enriched_01') AS SELECT
    o.id order_id,
    od.id order_details_id,
    o.order_date,
    o.customer_id,
    od.product_id,
    od.quantity,
    od.price
FROM sales_orders o
INNER JOIN sales_order_details od WITHIN 1 SECONDS ON (o.id = od.sales_order_id);
EOF

wait-for-schema dc01_sales_enriched_01

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM sales_enriched_02 WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_sales_enriched_02') AS SELECT
    se.order_id,
    se.order_details_id,
    se.order_date,
    se.customer_id,
    se.product_id,
    se.quantity,
    se.price,
    ct.first_name,
    ct.last_name,
    ct.email,
    ct.city,
    ct.country
FROM sales_enriched_01 se
INNER JOIN customers_tbl ct ON (se.customer_id = ct.id);
EOF

wait-for-schema dc01_sales_enriched_02

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM sales_enriched WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_sales_enriched') AS SELECT
    se.order_id,
    se.order_details_id,
    se.order_date,
    se.product_id product_id,
    pt.name product_name,
    pt.description product_desc,
    se.price product_price,
    se.quantity product_qty,
    se.customer_id customer_id,
    se.first_name customer_fname,
    se.last_name customer_lname,
    se.email customer_email,
    se.city customer_city,
    se.country customer_country
FROM sales_enriched_02 se
INNER JOIN products_tbl pt ON (se.product_id = pt.id);
EOF

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM purchases_enriched_01 WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_purchases_enriched_01') AS SELECT
    o.id order_id,
    od.id order_details_id,
    o.order_date,
    o.supplier_id,
    od.product_id,
    od.quantity,
    od.cost
FROM purchase_orders o
INNER JOIN purchase_order_details od WITHIN 1 SECONDS ON (o.id = od.purchase_order_id);
EOF

wait-for-schema dc01_purchases_enriched_01

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM purchases_enriched_02 WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_purchases_enriched_02') AS SELECT
    pe.order_id,
    pe.order_details_id,
    pe.order_date,
    pe.supplier_id,
    pe.product_id,
    pe.quantity,
    pe.cost,
    st.name,
    st.email,
    st.city,
    st.country
FROM purchases_enriched_01 pe
INNER JOIN suppliers_tbl st ON (pe.supplier_id = st.id);
EOF

wait-for-schema dc01_purchases_enriched_02

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM purchases_enriched WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_purchases_enriched') AS SELECT
    pe.order_id,
    pe.order_details_id,
    pe.order_date,
    pe.product_id product_id,
    pt.name product_name,
    pt.description product_desc,
    pe.cost product_cost,
    pe.quantity product_qty,
    pe.supplier_id supplier_id,
    pe.name supplier_name,
    pe.email supplier_email,
    pe.city supplier_city,
    pe.country supplier_country
FROM purchases_enriched_02 pe
INNER JOIN products_tbl pt ON (pe.product_id = pt.id);
EOF

wait-for-schema dc01_sales_enriched

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
SET 'auto.offset.reset'='earliest';
CREATE STREAM product_supply_and_demand WITH (PARTITIONS=1, KAFKA_TOPIC='dc01_product_supply_and_demand') AS SELECT
  product_id,
  product_qty * -1 "QUANTITY"
FROM sales_enriched;
EOF

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
INSERT INTO product_supply_and_demand
  SELECT  product_id,
          product_qty "QUANTITY"
  FROM    purchases_enriched;
EOF

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE TABLE current_stock WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_current_stock') AS SELECT
      product_id
    , SUM(quantity) "STOCK_LEVEL"
FROM product_supply_and_demand
GROUP BY product_id;
EOF

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE TABLE product_demand_last_3mins_tbl WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_product_demand_last_3mins')
AS SELECT
      timestamptostring(WINDOWSTART,'HH:mm:ss') "WINDOW_START_TIME"
    , timestamptostring(WINDOWEND,'HH:mm:ss') "WINDOW_END_TIME"
    , product_id
    , SUM(product_qty) "DEMAND_LAST_3MINS"
FROM sales_enriched
WINDOW HOPPING (SIZE 3 MINUTES, ADVANCE BY 1 MINUTE)
GROUP BY product_id EMIT CHANGES;
EOF


echo "------KSQL POLL QUERY USING REST API..."
curl -s -X "POST" "http://localhost:8088/query" -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d $'{ "ksql": "select product_id, stock_level from current_stock where rowkey=\'1\';" }'| jq .


docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM product_demand_last_3mins WITH (KAFKA_TOPIC='dc01_product_demand_last_3mins', VALUE_FORMAT='AVRO');
EOF

wait-for-schema dc01_product_demand_last_3mins

docker-compose exec -T ksql-cli ksql http://ksql-server-ccloud:8088 << EOF
SET 'auto.offset.reset' = 'earliest';
SET 'auto.offset.reset' = 'latest';
CREATE STREAM out_of_stock_events WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc01_out_of_stock_events')
AS SELECT
  cs.product_id "PRODUCT_ID",
  pd.window_start_time,
  pd.window_end_time,
  cs.stock_level,
  pd.demand_last_3mins,
  (cs.stock_level * -1) + pd.DEMAND_LAST_3MINS "QUANTITY_TO_PURCHASE"
FROM product_demand_last_3mins pd
INNER JOIN current_stock cs ON pd.product_id = cs.product_id
WHERE stock_level <= 0;
EOF

wait-for-schema dc01_out_of_stock_events

curl -i -X POST -H "Accept:application/json" \
    -H  "Content-Type:application/json" http://localhost:18083/connectors/ \
    -d '{
        "name": "replicator-ccloud-to-dc01",
        "config": {
          "connector.class": "io.confluent.connect.replicator.ReplicatorSourceConnector",
          "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
          "topic.config.sync": "false",
          "topic.whitelist": "dc01_out_of_stock_events",
          "dest.kafka.bootstrap.servers": "broker:29092",
          "dest.kafka.replication.factor": 1,
          "src.kafka.bootstrap.servers": "${file:/secrets.properties:CCLOUD_CLUSTER_ENDPOINT}",
          "src.kafka.security.protocol": "SASL_SSL",
          "src.kafka.sasl.mechanism": "PLAIN",
          "src.kafka.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${file:/secrets.properties:CCLOUD_API_KEY}\" password=\"${file:/secrets.properties:CCLOUD_API_SECRET}\";",
          "src.consumer.group.id": "replicator-ccloud-to-dc01",
          "src.consumer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor",
          "src.consumer.confluent.monitoring.interceptor.bootstrap.servers": "${file:/secrets.properties:CCLOUD_CLUSTER_ENDPOINT}",
          "src.kafka.timestamps.producer.interceptor.classes": "io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor",
          "src.kafka.timestamps.producer.confluent.monitoring.interceptor.bootstrap.servers": "${file:/secrets.properties:CCLOUD_CLUSTER_ENDPOINT}",
          "tasks.max": "1"
        }
    }'

curl -i -X POST -H "Accept:application/json" \
    -H  "Content-Type:application/json" http://localhost:18083/connectors/ \
    -d '{
        "name": "jdbc-mysql-sink",
        "config": {
          "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
          "topics": "dc01_out_of_stock_events",
          "connection.url": "jdbc:mysql://mysql:3306/orders",
          "connection.user": "mysqluser",
          "connection.password": "mysqlpw",
          "insert.mode": "INSERT",
          "batch.size": "3000",
          "auto.create": "true",
          "key.converter": "org.apache.kafka.connect.storage.StringConverter"
       }
    }'