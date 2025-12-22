#!/usr/bin/env python3
"""CLI to claim/complete callbacks using the callback-dispatcher Lambda.
Usage:
  python scripts/callback_cli.py claim --callback-id CID --requested-at TS --agent-id AGENT [--region eu-west-2] [--no-outbound] [--no-task]
  python scripts/callback_cli.py complete --callback-id CID --requested-at TS --agent-id AGENT [--result COMPLETED|FAILED|CANCELLED] [--notes "..." ]
"""
import argparse
import json
import sys
import boto3
import os

DEFAULT_REGION = "eu-west-2"
DEFAULT_LAMBDA_NAME = os.environ.get("CALLBACK_DISPATCHER_LAMBDA", "contact-center-callback-dispatcher")


def invoke_lambda(lambda_name: str, payload: dict, region: str):
    client = boto3.client("lambda", region_name=region)
    resp = client.invoke(
        FunctionName=lambda_name,
        InvocationType="RequestResponse",
        Payload=json.dumps(payload).encode("utf-8"),
    )
    body = resp["Payload"].read()
    try:
        return json.loads(body)
    except Exception:
        return {"raw": body.decode("utf-8")}


def build_parser():
    p = argparse.ArgumentParser(description="Callback dispatcher CLI")
    p.add_argument("command", choices=["claim", "complete"], help="Action to perform")
    p.add_argument("--callback-id", required=True)
    p.add_argument("--requested-at", required=True, help="The requested_at sort key value")
    p.add_argument("--agent-id", required=True)
    p.add_argument("--lambda-name", default=DEFAULT_LAMBDA_NAME)
    p.add_argument("--region", default=DEFAULT_REGION)
    p.add_argument("--notes")
    p.add_argument("--result", choices=["COMPLETED", "FAILED", "CANCELLED"], default="COMPLETED")
    p.add_argument("--no-outbound", action="store_true", help="Skip auto outbound call on claim")
    p.add_argument("--no-task", action="store_true", help="Skip task creation on claim")
    return p


def main():
    args = build_parser().parse_args()

    payload = {
        "action": args.command,
        "callback_id": args.callback_id,
        "requested_at": args.requested_at,
        "agent_id": args.agent_id,
    }

    if args.command == "claim":
        payload["start_outbound"] = not args.no_outbound
        payload["create_task"] = not args.no_task
    elif args.command == "complete":
        payload["result"] = args.result
        if args.notes:
            payload["notes"] = args.notes

    resp = invoke_lambda(args.lambda_name, payload, args.region)
    print(json.dumps(resp, indent=2))


if __name__ == "__main__":
    sys.exit(main())
