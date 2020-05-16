# Delete topics in Confluent Cloud
echo "Deleting Topics in cluster $CLUSTER_ID"
topics=$(ccloud kafka topic list --cluster $CLUSTER_ID -o json | jq '.[].name' -r)
for topic in $topics
do
  echo "Deleting: $topic"
  ccloud kafka topic delete $topic --cluster $CLUSTER_ID 
done
