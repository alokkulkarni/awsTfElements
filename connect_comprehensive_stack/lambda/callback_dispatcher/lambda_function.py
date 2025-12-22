"""Callback dispatcher: claim/complete callback requests with race-free locking.
Supports optional outbound call trigger and task creation in Connect.
"""
import json
import logging
import os
from datetime import datetime

import boto3
from botocore.exceptions import ClientError

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO))
logger = logging.getLogger(__name__)

# Env
REGION = os.environ.get("AWS_REGION", "eu-west-2")
TABLE_NAME = os.environ.get("CALLBACK_TABLE_NAME", "")
INSTANCE_ID = os.environ.get("INSTANCE_ID", "")
OUTBOUND_QUEUE_ID = os.environ.get("OUTBOUND_QUEUE_ID", "")
OUTBOUND_CONTACT_FLOW_ID = os.environ.get("OUTBOUND_CONTACT_FLOW_ID", "")
OUTBOUND_SOURCE_PHONE = os.environ.get("OUTBOUND_SOURCE_PHONE", "")
TASK_CONTACT_FLOW_ID = os.environ.get("TASK_CONTACT_FLOW_ID", "")

if not TABLE_NAME:
    raise RuntimeError("CALLBACK_TABLE_NAME is required")
if not INSTANCE_ID:
    raise RuntimeError("INSTANCE_ID is required")

_dynamo = boto3.resource("dynamodb", region_name=REGION)
_table = _dynamo.Table(TABLE_NAME)
_connect = boto3.client("connect", region_name=REGION)


def _now_iso():
    return datetime.utcnow().isoformat() + "Z"


def _start_outbound(destination_phone: str, callback_id: str):
    if not (OUTBOUND_CONTACT_FLOW_ID and OUTBOUND_QUEUE_ID):
        logger.info("Outbound contact flow/queue not configured; skipping outbound dial")
        return None

    params = {
        "InstanceId": INSTANCE_ID,
        "ContactFlowId": OUTBOUND_CONTACT_FLOW_ID,
        "DestinationPhoneNumber": destination_phone,
        "QueueId": OUTBOUND_QUEUE_ID,
        "Attributes": {
            "callback_id": callback_id,
            "purpose": "callback"
        }
    }
    if OUTBOUND_SOURCE_PHONE:
        params["SourcePhoneNumber"] = OUTBOUND_SOURCE_PHONE

    resp = _connect.start_outbound_voice_contact(**params)
    contact_id = resp.get("ContactId")
    logger.info(f"Outbound voice contact started for callback {callback_id}: {contact_id}")
    return contact_id


def _start_task(callback_id: str, customer_phone: str, claimed_by: str):
    if not TASK_CONTACT_FLOW_ID:
        logger.info("Task contact flow not configured; skipping task creation")
        return None

    name = f"Callback - {customer_phone}"
    attrs = {
        "callback_id": callback_id,
        "customer_phone": customer_phone,
        "claimed_by": claimed_by,
        "purpose": "callback"
    }

    resp = _connect.start_task_contact(
        InstanceId=INSTANCE_ID,
        ContactFlowId=TASK_CONTACT_FLOW_ID,
        Name=name,
        Attributes=attrs
    )
    task_id = resp.get("ContactId")
    logger.info(f"Task contact created for callback {callback_id}: {task_id}")
    return task_id


def _claim(payload):
    callback_id = payload.get("callback_id")
    requested_at = payload.get("requested_at")
    agent_id = payload.get("agent_id")
    start_outbound = bool(payload.get("start_outbound", True))
    create_task = bool(payload.get("create_task", True))

    if not (callback_id and requested_at and agent_id):
        return {"statusCode": 400, "message": "callback_id, requested_at, agent_id are required"}

    try:
        resp = _table.update_item(
            Key={"callback_id": callback_id, "requested_at": requested_at},
            ConditionExpression="#s = :pending",
            UpdateExpression="SET #s = :in_progress, claimed_by = :a, claimed_at = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":pending": "PENDING",
                ":in_progress": "IN_PROGRESS",
                ":a": agent_id,
                ":t": _now_iso()
            },
            ReturnValues="ALL_NEW"
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return {"statusCode": 409, "claimed": False, "message": "Already claimed or missing"}
        logger.error("Claim failed", exc_info=True)
        return {"statusCode": 500, "claimed": False, "message": str(e)}

    item = resp.get("Attributes", {})
    customer_phone = item.get("customer_phone")
    outbound_contact_id = None
    task_contact_id = None

    if start_outbound and customer_phone:
        outbound_contact_id = _start_outbound(customer_phone, callback_id)

    if create_task and customer_phone:
        task_contact_id = _start_task(callback_id, customer_phone, agent_id)

    return {
        "statusCode": 200,
        "claimed": True,
        "callback": item,
        "outbound_contact_id": outbound_contact_id,
        "task_contact_id": task_contact_id
    }


def _complete(payload):
    callback_id = payload.get("callback_id")
    requested_at = payload.get("requested_at")
    agent_id = payload.get("agent_id")
    result = payload.get("result", "COMPLETED")
    notes = payload.get("notes")

    if result not in {"COMPLETED", "FAILED", "CANCELLED"}:
        return {"statusCode": 400, "message": "result must be COMPLETED|FAILED|CANCELLED"}

    if not (callback_id and requested_at and agent_id):
        return {"statusCode": 400, "message": "callback_id, requested_at, agent_id are required"}

    update_expr = "SET #s = :s, completed_at = :t"
    expr_vals = {":s": result, ":t": _now_iso(), ":agent": agent_id}
    expr_names = {"#s": "status"}

    if notes:
        update_expr += ", notes = :n"
        expr_vals[":n"] = notes

    try:
        resp = _table.update_item(
            Key={"callback_id": callback_id, "requested_at": requested_at},
            ConditionExpression="#s = :in_progress AND claimed_by = :agent",
            UpdateExpression=update_expr,
            ExpressionAttributeNames=expr_names,
            ExpressionAttributeValues=expr_vals,
            ReturnValues="ALL_NEW"
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return {"statusCode": 409, "completed": False, "message": "Not in progress or not owned by agent"}
        logger.error("Complete failed", exc_info=True)
        return {"statusCode": 500, "completed": False, "message": str(e)}

    return {"statusCode": 200, "completed": True, "callback": resp.get("Attributes", {})}


def lambda_handler(event, context):
    logger.info(f"Received payload: {json.dumps(event)}")

    action = (event.get("action") or "").lower()
    if action == "claim":
        return _claim(event)
    if action == "complete":
        return _complete(event)

    return {"statusCode": 400, "message": "action must be claim or complete"}
