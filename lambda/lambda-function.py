import boto3
import os
import requests

INSTANCE_ID = os.environ['INSTANCE_ID']
HOSTED_ZONE_ID = os.environ['HOSTED_ZONE_ID']
RECORD_NAME = os.environ['RECORD_NAME']
WEBHOOK_URL = os.environ['WEBHOOK_URL']

ec2 = boto3.client('ec2')
route53 = boto3.client('route53')

def get_public_ip(instance_id):
    response = ec2.describe_instances(InstanceIds=[instance_id])
    return response['Reservations'][0]['Instances'][0]['PublicIpAddress']

def get_current_record_ip():
    response = route53.list_resource_record_sets(
        HostedZoneId=HOSTED_ZONE_ID,
        StartRecordName=RECORD_NAME,
        StartRecordType='A',
        MaxItems='1'
    )
    record_sets = response['ResourceRecordSets']
    if record_sets and record_sets[0]['Name'] == RECORD_NAME and record_sets[0]['Type'] == 'A':
        return record_sets[0]['ResourceRecords'][0]['Value']
    return None

def update_dns_record(ip):
    return route53.change_resource_record_sets(
        HostedZoneId=HOSTED_ZONE_ID,
        ChangeBatch={
            'Comment': 'Auto-updated by Lambda',
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': RECORD_NAME,
                        'Type': 'A',
                        'TTL': 300,
                        'ResourceRecords': [{'Value': ip}],
                    }
                }
            ]
        }
    )

def send_webhook_notification(message: str):
    try:
        requests.post(WEBHOOK_URL, json={"content": message})
    except Exception as e:
        print(f"[ERROR] Webhook failed: {str(e)}")

def lambda_handler(event, context):
    current_ip = get_public_ip(INSTANCE_ID)
    record_ip = get_current_record_ip()

    if current_ip == record_ip:
        return {
            'status': 'skipped',
            'message': f'IP unchanged: {current_ip}'
        }

    try:
        update_dns_record(current_ip)
        message = f"✅ [UPDATED] `{RECORD_NAME}` IP changed: `{record_ip}` ➜ `{current_ip}`"
        print(message)
        send_webhook_notification(message)
        return {
            'status': 'updated',
            'old_ip': record_ip,
            'new_ip': current_ip
        }
    except Exception as e:
        message = f"❌ [FAILED] `{RECORD_NAME}` update to `{current_ip}` failed:\n```{str(e)}```"
        print(message)
        send_webhook_notification(message)
        return {
            'status': 'error',
            'message': str(e)
        }
