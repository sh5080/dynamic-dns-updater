import boto3
import os
import requests

INSTANCE_ID = os.environ['INSTANCE_ID']
HOSTED_ZONE_ID = os.environ['HOSTED_ZONE_ID']
RECORD_NAMES = [name.strip() for name in os.environ['RECORD_NAME'].split(',')]
WEBHOOK_URL = os.environ['WEBHOOK_URL']

ec2 = boto3.client('ec2')
route53 = boto3.client('route53')

def get_public_ip(instance_id):
    response = ec2.describe_instances(InstanceIds=[instance_id])
    return response['Reservations'][0]['Instances'][0]['PublicIpAddress']

def get_current_record_ip(record_name):
    response = route53.list_resource_record_sets(
        HostedZoneId=HOSTED_ZONE_ID,
        StartRecordName=record_name,
        StartRecordType='A',
        MaxItems='1'
    )
    record_sets = response['ResourceRecordSets']
    if record_sets and record_sets[0]['Name'] == record_name and record_sets[0]['Type'] == 'A':
        return record_sets[0]['ResourceRecords'][0]['Value']
    return None

def update_dns_record(record_name, ip):
    return route53.change_resource_record_sets(
        HostedZoneId=HOSTED_ZONE_ID,
        ChangeBatch={
            'Comment': 'Auto-updated by Lambda',
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': record_name,
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
    update_results = []
    updated = False
    
    for record_name in RECORD_NAMES:
        record_ip = get_current_record_ip(record_name)
        
        if current_ip == record_ip:
            update_results.append({
                'record_name': record_name,
                'status': 'skipped',
                'message': f'IP unchanged: {current_ip}'
            })
            continue
            
        try:
            update_dns_record(record_name, current_ip)
            message = f"✅ [UPDATED] `{record_name}` IP changed: `{record_ip}` ➜ `{current_ip}`"
            print(message)
            send_webhook_notification(message)
            update_results.append({
                'record_name': record_name,
                'status': 'updated',
                'old_ip': record_ip,
                'new_ip': current_ip
            })
            updated = True
        except Exception as e:
            error_message = f"❌ [FAILED] `{record_name}` update to `{current_ip}` failed:\n```{str(e)}```"
            print(error_message)
            send_webhook_notification(error_message)
            update_results.append({
                'record_name': record_name,
                'status': 'error',
                'message': str(e)
            })
    
    if not updated:
        return {
            'status': 'skipped_all',
            'message': f'No DNS records updated. All IPs matching: {current_ip}',
            'details': update_results
        }
    
    return {
        'status': 'updated_some',
        'current_ip': current_ip,
        'details': update_results
    }
