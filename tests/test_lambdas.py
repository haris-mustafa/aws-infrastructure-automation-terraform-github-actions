"""
Unit tests for both Lambda functions.
They use mocks, so they run on your laptop / in GitHub Actions WITHOUT
touching real AWS (no credentials, no cost).

Run:  pytest -v
"""
import json
import os
import sys
from unittest.mock import MagicMock, patch

# Fake environment so the modules can be imported without AWS.
os.environ.update(
    AWS_DEFAULT_REGION="ap-south-1",
    AWS_REGION="ap-south-1",
    AWS_ACCESS_KEY_ID="test",
    AWS_SECRET_ACCESS_KEY="test",
    TABLE_NAME="test-table",
    TOPIC_ARN="arn:aws:sns:ap-south-1:123456789012:test-topic",
    BUCKET_NAME="test-bucket",
    MILESTONE="10",
)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app", "lambda"))

import upload_url  # noqa: E402
import visitor_counter  # noqa: E402


def _counter_returns(n):
    return {"Attributes": {"hits": n}}


def test_counter_increments_and_returns_count():
    with patch.object(visitor_counter, "table") as table, patch.object(visitor_counter, "sns") as sns:
        table.update_item.return_value = _counter_returns(3)
        resp = visitor_counter.handler({}, None)
    assert resp["statusCode"] == 200
    assert json.loads(resp["body"]) == {"visits": 3}
    sns.publish.assert_not_called()  # 3 is not a milestone


def test_counter_sends_sns_alert_on_milestone():
    with patch.object(visitor_counter, "table") as table, patch.object(visitor_counter, "sns") as sns:
        table.update_item.return_value = _counter_returns(10)
        visitor_counter.handler({}, None)
    sns.publish.assert_called_once()


def test_upload_requires_filename():
    resp = upload_url.handler({"queryStringParameters": None}, None)
    assert resp["statusCode"] == 400


def test_upload_returns_presigned_url_and_sanitizes_name():
    fake_s3 = MagicMock()
    fake_s3.generate_presigned_url.return_value = "https://example.com/signed"
    with patch.object(upload_url, "s3", fake_s3):
        resp = upload_url.handler({"queryStringParameters": {"filename": "../my file.png"}}, None)
    body = json.loads(resp["body"])
    assert resp["statusCode"] == 200
    assert body["uploadUrl"] == "https://example.com/signed"
    assert body["key"].startswith("uploads/")
    assert ".." not in body["key"] and " " not in body["key"]
