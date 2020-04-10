#!/usr/bin/env bash

export AWS_PROFILE=speedtester
# export AWS_REGION=us-east-1


function manage_log_stream () {
  log_stream_exists=$(aws logs describe-log-streams \
    --log-group-name racerx \
    --log-stream-name-prefix speedtest-results \
    | jq '.logStreams | length')

  if [ "$log_stream_exists" != 1 ]
  then
    aws logs \
      create-log-stream \
      --log-group-name racerx \
      --log-stream-name speedtest-results
  fi
}

function manage_log_group () {
  log_group_exists=$(aws logs describe-log-groups \
    --log-group-name-prefix racerx \
    | jq '.logGroups | length')

  if [ "$log_group_exists" != 1 ]
  then
    aws logs \
      create-log-group \
      --log-group-name racerx
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
  echo "begin sending log to cloudwatch..."
  next_token=$(aws logs describe-log-streams \
    --log-group-name racerx \
    --log-stream-name-prefix "speedtest-results" \
    | jq -r '.logStreams[0].uploadSequenceToken')
  echo "$next_token"

  if [[ "$next_token" != "null" ]]
  # if true
  then
    echo "token is $next_token"
    aws logs \
      put-log-events \
      --log-events file://put-events.log \
      --log-group-name racerx \
      --log-stream-name speedtest-results \
      --sequence-token "$next_token"
  else
    echo "token is null"
    aws logs \
      put-log-events \
      --log-events file://put-events.log \
      --log-group-name racerx \
      --log-stream-name speedtest-results
  fi

  echo "Finished sending logs to cloudwatch"
}

function put_metrics () {
# push metrics to Cloudwatch

upload_speed=$(jq -c '.[0].message| fromjson | .upload.bandwidth' put-events.log) # bits/second
download_speed=$(jq -c '.[0].message| fromjson | .download.bandwidth' put-events.log)

echo "download speed: $download_speed"
echo "upload speed: $upload_speed"

# send results to cloudwatch
aws cloudwatch put-metric-data \
  --namespace racerx \
  --metric-name speedtest \
  --unit Bytes \
  --value "$download_speed" \
  --dimensions Direction=download

aws cloudwatch put-metric-data \
  --namespace racerx \
  --metric-name speedtest \
  --unit Bytes \
  --value "$upload_speed" \
  --dimensions Direction=upload
}

manage_log_group
manage_log_stream
run_speedtest
log_to_cloudwatch
put_metrics
