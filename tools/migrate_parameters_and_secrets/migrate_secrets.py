import boto3
import configparser

def create_boto3_client(config_file_section):
    client = boto3.client(
        'secretsmanager',
        aws_account_id=config[config_file_section]['AWS_ACCOUNT_ID'],
        aws_access_key_id=config[config_file_section]['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=config[config_file_section]['AWS_SECRET_ACCESS_KEY'],
        aws_session_token=config[config_file_section]['AWS_SESSION_TOKEN']
    )

    return client

def generate_optional_kwargs_from_secret(secret):
    put_secret_optional_fields = [
        'Description',
        'Tags'
    ]

    kwargs = {}

    for field in put_secret_optional_fields:
        if field in secret:
            kwargs[field] = secret[field]

    return kwargs

def process_secret_list(secret_list, exclusion_list):
    write_list = []
    
    for secret in secret_list:
        add_secret = True     

        for substring in exclusion_list:
            if substring in secret['Name']:
                add_secret = False
                break
        
        if add_secret is True:
            write_list.append(secret)

    return write_list

def write_parameters(source_client, target_client, secret_list):
    for secret in secret_list:
        print(secret['Name'])

        if config['MISCELLANEOUS']['DRY-RUN'] == 'false':
            response = source_client.get_secret_value(
                SecretId=secret['Name']
            )

            kwargs = generate_optional_kwargs_from_secret(secret)

            if 'SecretBinary' in response:
                kwargs['SecretBinary'] = response['SecretBinary']

            if 'SecretString' in response:
                kwargs['SecretString'] = response['SecretString']

            response = target_client.create_secret(
                Name=secret['Name'],
                **kwargs
            )
                
config = configparser.ConfigParser()
config.read('settings.ini')

print("Creating source account client.")
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
    kwargs = {'NextToken': next_token} if next_token != "" else {}
    response = bcda_client.list_secrets(MaxResults=1, **kwargs)
    next_token = response['NextToken'] if ('NextToken' in response) else None

    non_prod_account_write_list.extend(
        process_secret_list(
            response['SecretList'], 
            non_prod_account_exclude_list
        )
    )

    prod_account_write_list.extend(
        process_secret_list(
            response['SecretList'], 
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
