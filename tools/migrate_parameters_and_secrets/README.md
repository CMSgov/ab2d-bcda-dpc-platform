# Migrate parameters and secrets

Python tools intended to be used in migrating Parameter Store parameters and Secrets Manager secrets from source AWS legacy accounts to target prod and non-prod Greenfield accounts.

## Usage

1. Clone the repo to a local machine and open a shell in the directory containing the migrate_secrets.py and migrate_parameters.py scripts.

2. Follow the steps in this doc (https://boto3.amazonaws.com/v1/documentation/api/latest/guide/quickstart.html#configuration) to install boto3 (the AWS SDK for Python).

3. Edit the settings.ini file:
    - Enter account IDs and credentials for the source and target accounts.
    - Edit the parameter prefix lists to exclude parameters and secrets where one or more of the substrings in the list are contained in the parameter or secret name from being migrated.
    - Ensure that [MISCELLANEOUS].[DRY-RUN] is set to true.

4. Run the desired migration script to generate a dry-run list of which parameters or secrets will be migrated:

```sh
python3 migrate_parameters.py
or
python3 migrate_secrets.py
```

5. Add or remove substrings from the prod and/or non-prod exclusion lists in the settings.ini file and generate updated dry-run lists of items to be migrated until the list is in the desired state.

6. Update [MISCELLANEOUS].[DRY-RUN] to false in the settings.ini file.

7. Run the script; with dry-run set to false the AWS API will be called for each parameter or secret in the list to create the item in the target account.

## Additional Notes

These scripts currently fail if attempting to write a parameter or secret that already exists in the target account. Two enhancements could be implemented to prevent this behavior:

- the write_secret and put_parameter and write_secret API calls each have an overwrite setting that is false by default; this setting could be exposed in the settings.ini file to allow for any pre-existing items to be overwritten, although this seems risky.
- any duplicate key errors could be handled by logging the name of the parameter or secret that already existed and was not overwritten.
