# Python + Confluent Cloud 
From Example: https://github.com/confluentinc/examples/tree/latest/clients/cloud/python

## Start the demo
1. Create file librdkafka.config using the librdkafka.config.example as template
1. docker-compose up -d

## Produce
1. docker exec -dit confluentpython sh -c "python -u ./producer.py -f librdkafka.config -t test1> /proc/1/fd/1"

1. docker logs -f confluentpython

## Consume
1. docker exec -dit confluentpython sh -c "python -u ./consumer.py -f librdkafka.config -t test1> /proc/1/fd/1"
1. docker logs -f confluentpython