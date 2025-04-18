import boto3
import configparser
import os

def create_boto3_client(account_alias):
    client = boto3.client(
        'ssm' if resource_type == 'parameter' else 'secretsmanager',
        aws_account_id=os.environ[account_alias + '_AWS_ACCESS_KEY_ID'],
        aws_access_key_id=os.environ[account_alias + '_AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=os.environ[account_alias + '_AWS_SECRET_ACCESS_KEY'],
        aws_session_token=os.environ[account_alias + '_AWS_SESSION_TOKEN']
    )

    return client

def generate_optional_kwargs_from_item(item, fields):
    kwargs = {}

    for field in fields:
        if field in item:
            kwargs[field] = item[field]

    return kwargs

def process_item_list(item_list, exclusion_list):
    write_list = []
    
    for item in item_list:
        add_item = True     

        for substring in exclusion_list:
            if substring in item['Name']:
                add_item = False
                break
        
        if add_item is True:
            write_list.append(item)

    return write_list

def write_items(source_client, target_client, item_list):
    for item in item_list:
        print(item['Name'])

        if config['MISCELLANEOUS']['DRY-RUN'] == 'false':
            match resource_type:
                case 'parameter':
                    response = source_client.get_parameter(
                        Name=item['Name'], 
                        WithDecryption=True
                    )

                    value = response['Parameter']['Value']
                    kwargs = generate_optional_kwargs_from_item(
                        item, 
                        put_parameter_optional_fields
                    )

                    response = target_client.put_parameter(
                        Name=item['Name'],
                        Value=value,
                        Type=item['Type'],
                        **kwargs
                        )
                                        
                case 'secret':
                    response = source_client.get_secret_value(
                        SecretId=item['Name']
                    )

                    kwargs = generate_optional_kwargs_from_item(
                        item,
                        put_secret_optional_fields
                    )

                    if 'SecretBinary' in response:
                        kwargs['SecretBinary'] = response['SecretBinary']

                    if 'SecretString' in response:
                        kwargs['SecretString'] = response['SecretString']

                    response = target_client.create_secret(
                        Name=item['Name'],
                        **kwargs
                    )

config = configparser.ConfigParser()
config.read('settings.ini')
resource_type = config['MISCELLANEOUS']['RESOURCE-TYPE']

print("Creating BCDA account client.")
bcda_client = create_boto3_client("SOURCE")

print("Creating Non-Prod account client.")
non_prod_client = create_boto3_client("NON_PROD")

print("Creating Prod account client.")
prod_client = create_boto3_client("PROD")

non_prod_account_exclude_list = config['PARAMETER_PREFIX_LISTS']['BCDA-NON-PROD-ACCOUNT-EXCLUDE-LIST'].split(' ')
non_prod_account_write_list = []

prod_account_exclude_list = config['PARAMETER_PREFIX_LISTS']['BCDA-PROD-ACCOUNT-EXCLUDE-LIST'].split(' ')
prod_account_write_list = []

put_parameter_optional_fields = [
    'Description',
    'AllowedPattern',
    'Tags',
    'Tier',
    'DataType'
]

put_secret_optional_fields = [
    'Description',
    'Tags'
]

print("Processing AWS BCDA account items into Prod and Non-Prod account write lists.")

next_token = ""

while next_token is not None:
    response = None

    match resource_type:
        case 'parameter':
            response = bcda_client.describe_parameters(MaxResults=50, NextToken=next_token)
        case 'secret':
            kwargs = {'NextToken': next_token} if next_token != "" else {}
            response = bcda_client.list_secrets(MaxResults=1, **kwargs)
        case _:
            raise Exception("A resource-type of either 'parameter' or 'string' must be specified in the settings file.")

    next_token = response['NextToken'] if ('NextToken' in response) else None

    non_prod_account_write_list.extend(
        process_item_list(
            response['Parameters'] if resource_type == 'parameter' else response['SecretList'], 
            non_prod_account_exclude_list
        )
    )

    prod_account_write_list.extend(
        process_item_list(
            response['Parameters'] if resource_type == 'parameter' else response['SecretList'], 
            prod_account_exclude_list
        )
    )

print(f'\nWriting to the AWS Non-Prod account {resource_type} store:\n')

write_items(
    bcda_client, 
    non_prod_client, 
    non_prod_account_write_list
)

print(f'\nWriting to the AWS Prod account {resource_type} store:\n')

write_items(
    bcda_client, 
    prod_client, 
    prod_account_write_list
)
