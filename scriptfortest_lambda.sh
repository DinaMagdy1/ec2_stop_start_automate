#!/bin/bash

# Define variables
LAMBDA_NAME="test"
REGION="eu-west-1"
ROLE_ARN="arn:aws:iam::851725518898:role/Lambda_EC2_StartStop_Role"
INSTANCE_IDS="i-05cbefd3accf76616"

# Create a Python script for the Lambda function
cat <<EOF > lambda_function.py
import boto3
import os

# AWS region
REGION = "$REGION"

# List of EC2 Instance IDs to start/stop
INSTANCE_IDS = ["$INSTANCE_IDS"]

# Get EC2 client
ec2 = boto3.client("ec2", region_name=REGION)

def lambda_handler(event, context):
    action = event.get("action", "")

    if action == "start":
        ec2.start_instances(InstanceIds=INSTANCE_IDS)
        return f"Started EC2 instances: {INSTANCE_IDS}"

    elif action == "stop":
        ec2.stop_instances(InstanceIds=INSTANCE_IDS)
        return f"Stopped EC2 instances: {INSTANCE_IDS}"

    return "No action performed."
EOF

# Create a deployment package (zip the python file)
zip function.zip lambda_function.py > /dev/null 2>&1

# Create the Lambda function
aws lambda create-function \
    --function-name $LAMBDA_NAME \
    --runtime python3.9 \
    --role $ROLE_ARN \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --region $REGION > /dev/null 2>&1

# Clean up by removing the zip file and Python script
rm lambda_function.py function.zip > /dev/null 2>&1

echo "Lambda function '$LAMBDA_NAME' has been created and deployed successfully." > /dev/null 2>&1

# Set variables for EventBridge and Lambda
LAMBDA_ARN="arn:aws:lambda:$REGION:851725518898:function:$LAMBDA_NAME"
START_CRON="47 14 ? * * *"  # Cron expression for start (10:00 AM Cairo time)
STOP_CRON="50 14 ? * * *"   # Cron expression for stop (10:10 AM Cairo time)
TIMESTAMP=$(date +%s)  # Get the current timestamp for unique statement-id

# Create EventBridge rule for Start EC2
aws events put-rule \
    --name "StartEC2Ruleee" \
    --schedule-expression "cron($START_CRON)" \
    --region $REGION > /dev/null 2>&1

# Create EventBridge rule for Stop EC2
aws events put-rule \
    --name "StopEC2Ruleee" \
    --schedule-expression "cron($STOP_CRON)" \
    --region $REGION > /dev/null 2>&1

# Wait a moment to make sure the rules are created
sleep 5

# Add permissions for EventBridge to invoke Lambda for Start EC2
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --principal events.amazonaws.com \
    --statement-id "StartEC2Permission-$TIMESTAMP" \
    --action "lambda:InvokeFunction" \
    --region $REGION > /dev/null 2>&1

# Add permissions for EventBridge to invoke Lambda for Stop EC2
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --principal events.amazonaws.com \
    --statement-id "StopEC2Permission-$TIMESTAMP" \
    --action "lambda:InvokeFunction" \
    --region $REGION > /dev/null 2>&1

# Wait a moment to make sure permissions are added
sleep 5

# Associate the EventBridge rule for Start EC2 with Lambda function
aws events put-targets \
    --rule "StartEC2Ruleee" \
    --targets "Id=1,Arn=$LAMBDA_ARN,Input='{\"action\":\"start\"}'" \
    --region $REGION > /dev/null 2>&1

# Associate the EventBridge rule for Stop EC2 with Lambda function
aws events put-targets \
    --rule "StopEC2Ruleee" \
    --targets "Id=1,Arn=$LAMBDA_ARN,Input='{\"action\":\"stop\"}'" \
    --region $REGION > /dev/null 2>&1

echo "EventBridge rules and permissions successfully set up!" > /dev/null 2>&1
