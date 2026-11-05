"""
visitor_counter.py  --  Lambda function behind  POST /visit

What it does:
  1. Atomically adds +1 to a counter stored in DynamoDB.
  2. Every MILESTONE visits (default 10) it publishes an SNS alert (email).
  3. Returns the new count as JSON to the website.

Services used: API Gateway (trigger) -> Lambda -> DynamoDB + SNS
"""
import json
import os

import boto3

# Clients are created OUTSIDE the handler so Lambda re-uses them between
# invocations (faster "warm" starts).
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

# These values are injected by Terraform (see terraform/lambda.tf).
table = dynamodb.Table(os.environ["TABLE_NAME"])
TOPIC_ARN = os.environ["TOPIC_ARN"]
MILESTONE = int(os.environ.get("MILESTONE", "10"))


def _response(status, body):
    """Build the response shape API Gateway (HTTP API v2) expects."""
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    # ADD is an atomic increment: safe even if 100 people visit at once.
    result = table.update_item(
        Key={"id": "visits"},
        UpdateExpression="ADD hits :inc",
        ExpressionAttributeValues={":inc": 1},
        ReturnValues="UPDATED_NEW",
    )
    count = int(result["Attributes"]["hits"])

    # Send an SNS alert on every milestone (10, 20, 30, ...).
    if count % MILESTONE == 0:
        sns.publish(
            TopicArn=TOPIC_ARN,
            Subject="Visitor milestone reached!",
            Message=f"Your site just reached {count} visits.",
        )

    return _response(200, {"visits": count})
