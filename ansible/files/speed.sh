#!/usr/bin/env bash

function manage_log_stream () {
  log_stream_exists=$(aws logs describe-log-streams \
    --log-group-name racerx \
    --log-stream-name-prefix speedtest-results \
    --profile speedtest \
    | jq '.logStreams | length')

  if [ "$log_stream_exists" != 1 ]
  then
    aws logs \
      create-log-stream \
      --log-group-name racerx \
      --log-stream-name speedtest-results \
      --profile speedtest
  fi
}

function manage_log_group () {
  log_group_exists=$(aws logs describe-log-groups \
    --log-group-name-prefix racerx \
    --profile speedtest \
    | jq '.logGroups | length')
  if [ "$log_group_exists" != 1 ]
  then
    aws logs \
      create-log-group \
      --log-group-name racerx \
      --profile speedtest
  fi
}

function run_speedtest () {
  # run speedtest and capture results
  VERSION=$(speedtest --version | grep Speedtest)
  echo "starting $VERSION"

  results=$(speedtest --format=json)
  echo "$results"
  echo "speedtest completed"

  # cloudwatch agent doesnt run on rpi, so using api to ship results
  timestamp=$(date +"%s000") # must be milliseconds
  string_results=$(echo "$results" | jq tostring)
  log_formatted_result="[{ \"timestamp\": $timestamp, \"message\": $string_results }]"
  echo "$log_formatted_result" > put-events.log
}

function log_to_cloudwatch () {
  next_token=$(aws logs describe-log-streams \
    --log-group-name racerx \
    --log-stream-name-prefix "speedtest-results" \
    --profile speedtest \
    | jq -r '.logStreams[0].uploadSequenceToken')

  if [ "$next_token" == "null" ]
  then
    # echo "token is null"
    aws logs \
      put-log-events \
      --log-events file://put-events.log \
      --log-group-name racerx \
      --log-stream-name speedtest-results \
      --profile speedtest
  else
    # echo "token is $next_token"
    aws logs \
      put-log-events \
      --log-events file://put-events.log \
      --log-group-name racerx \
      --log-stream-name speedtest-results \
      --profile speedtest \
      --sequence-token "$next_token"
  fi
}

manage_log_group
manage_log_stream
run_speedtest
log_to_cloudwatch


# push metric to Cloudwatch
# download_speed=$(echo $results | jq '.download.bandwidth') # bits/second
# upload_speed=$(echo $results | jq '.upload.bandwidth')

# send results to cloudwatch
# aws cloudwatch put-metric-data \
#   --region us-east-1 \
#   --namespace racerx \
#   --metric-name speedtest \
#   --unit Bytes \
#   --value 101 \
#   --dimensions Direction=download
