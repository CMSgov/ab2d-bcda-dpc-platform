"""
Receives messages from CloudWatch alarms via SQS subscription to SNS.
Forwards the alarms to Slack, with an emoji that says good or bad.
"""

from datetime import datetime, timezone
import json
from json.decoder import JSONDecodeError
import os
from urllib import request
from urllib.error import URLError

def lambda_handler(event, _):
    """ Entry point for lambda """
    for record in event['Records']:
        message = enriched_cloudwatch_message(record)
        if message:
            send_message_to_slack(message, record.get('messageId'))
    return {
        'statusCode': 200,
        'body': f'Processed {len(event["Records"])} messages'
    }

def cloudwatch_message(record):
    """
    Parses the SQS record for the CloudWatch Alarm json.
    Returns None if it can't find it.
    """
    try:
        body_s = record['body']
        body = json.loads(body_s)
        message_s = body['Message']
        message = json.loads(message_s)

        if message.get('OldStateValue'):
            return message
    except JSONDecodeError:
        log({'messageId': record.get('messageId'),
             'msg': 'Did not receive an SNS Cloudwatch payload',})
    return None

def enriched_cloudwatch_message(record):
    """
    Logs the CloudWatch message (if it exists).
    Enriches the message with an emoji for display.
    """
    message = cloudwatch_message(record)
    if message:
        log({'messageId': record.get('messageId'),
             'AlarmName': message.get('AlarmName'),
             'NewStateValue': message.get('NewStateValue'),
             'OldStateValue': message.get('OldStateValue'),
             'StateChangeTime': message.get('StateChangeTime'),
             'msg': 'Received CloudWatch Alarm',
            })
        if message['NewStateValue'] == 'OK':
            if os.environ.get('IGNORE_OK') == 'true':
                return None
            message['Emoji'] = ':checked:'
        else:
            message['Emoji'] = ':anger:'
    return message

def send_message_to_slack(message, message_id):
    """
    Calls the webhook with the message. Returns success.
    """
    webhook = os.environ.get('SLACK_WEBHOOK_URL')
    if not webhook:
        log({'messageId': message_id,
             'msg': 'Unable to send to Slack as SLACK_WEBHOOK_URL not set'})
        return False
    jsondata = json.dumps(message)
    jsondataasbytes = jsondata.encode('utf-8')
    req = request.Request(webhook)
    req.add_header('Content-Type', 'application/json; charset=utf-8')
    req.add_header('Content-Length', len(jsondataasbytes))
    try:
        with request.urlopen(req, jsondataasbytes) as resp:
            if resp.status == 200:
                log({'messageId': message_id,
                     'msg': 'Successfullly sent message to Slack'})
                return True
            log({'messageId': message_id,
                 'msg': f'Unsuccessful attempt to send message to slack ({resp.status})'})
            return False
    except URLError as e:
        log({'messageId': message_id,
             'msg': f'Unsuccessful attempt to send message to slack ({e.reason})'})
        return False

def log(data):
    """
    Enriches the log message with the time.
    Prints the data to standard out
    """
    data['time'] = datetime.now().astimezone(tz=timezone.utc).isoformat()
    print(json.dumps(data))
