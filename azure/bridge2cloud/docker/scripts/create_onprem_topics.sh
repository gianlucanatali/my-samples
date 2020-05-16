#!/bin/bash

# Create topics in OnPrem cluster
echo "Creating Topics in on premise cluster"
#topics_to_create="ORDERS_ENRICHED db01.retail.orders db01.retail.orderdetails db01.retail.customers db01.retail.products"
topics_to_create="ORDERS_ENRICHED"
for topic in $topics_to_create
do
    echo "Creating Topic: $topic"
    kafka-topics --bootstrap-server broker:29092 --create --topic $topic --partitions 1 --replication-factor 1 --config retention.ms=3600000
done

topics_to_create="db01.retail.orders db01.retail.orderdetails db01.retail.customers db01.retail.products"
for topic in $topics_to_create
do
    echo "Creating Topic: $topic"
    kafka-topics --bootstrap-server broker:29092 --create --topic $topic --partitions 1 --replication-factor 1 --config retention.ms=3600000
done
