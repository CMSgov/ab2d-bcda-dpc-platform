import boto3
import configparser

def create_boto3_client(config_file_section):
    client = boto3.client(
        'ssm',
        aws_account_id=config[config_file_section]['AWS_ACCOUNT_ID'],
        aws_access_key_id=config[config_file_section]['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=config[config_file_section]['AWS_SECRET_ACCESS_KEY'],
        aws_session_token=config[config_file_section]['AWS_SESSION_TOKEN']
    )

    return client

def generate_optional_kwargs_from_parameter(parameter):
    put_parameter_optional_fields = [
        'Description',
        'AllowedPattern',
        'Tags',
        'Tier',
        'DataType'
    ]

    kwargs = {}

    for field in put_parameter_optional_fields:
        if field in parameter:
            kwargs[field] = parameter[field]

    return kwargs

def process_parameter_list(parameter_list, exclusion_list):
    write_list = []
    
    for parameter in parameter_list:
        add_parameter = True     

        for substring in exclusion_list:
            if substring in parameter['Name']:
                add_parameter = False
                break
        
        if add_parameter is True:
            write_list.append(parameter)

    return write_list

def write_parameters(source_client, target_client, parameter_list):
    for parameter in parameter_list:
        print(parameter['Name'])

        if config['MISCELLANEOUS']['DRY-RUN'] == 'false':
            response = source_client.get_parameter(
                Name=parameter['Name'], 
                WithDecryption=True
            )

            value = response['Parameter']['Value']
            kwargs = generate_optional_kwargs_from_parameter(parameter)

            response = target_client.put_parameter(
                Name=parameter['Name'],
                Value=value,
                Type=parameter['Type'],
                **kwargs
            )

config = configparser.ConfigParser()
config.read('settings.ini')

print("Creating BCDA account client.")
bcda_client = create_boto3_client('SOURCE.ACCOUNT.CREDENTIALS')

print("Creating Non-Prod account client.")
non_prod_client = create_boto3_client('NON-PROD.ACCOUNT.CREDENTIALS')

print("Creating Prod account client.")
prod_client = create_boto3_client('PROD.ACCOUNT.CREDENTIALS')

non_prod_account_exclude_list = config['PARAMETER_PREFIX_LISTS']['BCDA-NON-PROD-ACCOUNT-EXCLUDE-LIST'].split(' ')
non_prod_account_write_list = []

prod_account_exclude_list = config['PARAMETER_PREFIX_LISTS']['BCDA-PROD-ACCOUNT-EXCLUDE-LIST'].split(' ')
prod_account_write_list = []

print("Processing AWS BCDA account parameters into Prod and Non-Prod account write lists.")

next_token = ""

while next_token is not None:
    response = bcda_client.describe_parameters(MaxResults=50, NextToken=next_token)
    next_token = response['NextToken'] if ('NextToken' in response) else None
    
    non_prod_account_write_list.extend(
        process_parameter_list(
            response['Parameters'], 
            non_prod_account_exclude_list
        )
    )

    prod_account_write_list.extend(
        process_parameter_list(
            response['Parameters'], 
            prod_account_exclude_list
        )
    )

print("Writing to the AWS Non-Prod account parameter store:")

write_parameters(
    bcda_client, 
    non_prod_client, 
    non_prod_account_write_list
)

print("Writing to the AWS Prod account parameter store:")

write_parameters(
    bcda_client, 
    prod_client, 
    prod_account_write_list
)
