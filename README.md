### Readme file of Automation script for controling running EC2 instances on AWS.

##### This is automation script to schedule the start/stop of ec2 instances based on requirements. That help in decreasing cost and control resources.
- We create Lambda function with the right permissions then create 2 EventBridge rules that will trigger lambda according to a schedule first rule to trigger lambda to start EC2 instance in specific time and the second EventBridge Rule used to trigger lambda again to stop the EC2 instance. 


### Requirments
- AWS account
- AWS CLI

### Steps

##### 1- Create a Lambda function with Python code runtime.
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

##### 2- Create EventBridge rule for Start EC2.
        aws events put-rule \
            --name "StartEC2Ruleee" \
            --schedule-expression "cron($START_CRON)" \
            --region $REGION > /dev/null 2>&1

##### 3- Create EventBridge rule for Stop EC2.
        aws events put-rule \
            --name "StopEC2Ruleee" \
            --schedule-expression "cron($STOP_CRON)" \
            --region $REGION > /dev/null 2>&1

##### 4- Add permissions for EventBridge to invoke Lambda for Start EC2.

        aws lambda add-permission \
            --function-name $LAMBDA_NAME \
            --principal events.amazonaws.com \
            --statement-id "StartEC2Permission-$TIMESTAMP" \
            --action "lambda:InvokeFunction" \
            --region $REGION > /dev/null 2>&1
##### 5- Add permissions for EventBridge to invoke Lambda for Stop EC2.

        aws lambda add-permission \
            --function-name $LAMBDA_NAME \
            --principal events.amazonaws.com \
            --statement-id "StopEC2Permission-$TIMESTAMP" \
            --action "lambda:InvokeFunction" \
            --region $REGION > /dev/null 2>&1
##### 6- Associate the EventBridge rule for Start EC2 with Lambda function.
        aws events put-targets \
            --rule "StartEC2Ruleee" \
            --targets "Id=1,Arn=$LAMBDA_ARN,Input='{\"action\":\"start\"}'" \
            --region $REGION > /dev/null 2>&1

##### 7- Associate the EventBridge rule for Stop EC2 with Lambda function.

        aws events put-targets \
            --rule "StopEC2Ruleee" \
            --targets "Id=1,Arn=$LAMBDA_ARN,Input='{\"action\":\"stop\"}'" \
            --region $REGION > /dev/null 2>&1



##### 8- Test on AWS account.
