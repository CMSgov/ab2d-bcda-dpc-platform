# cdap

Infra and operations code (terraform modules, scripts, tools, services, etc.)
to build a platform for the AB2D, BCDA, and DPC teams.


## Installing and Using Pre-commit

Anyone committing to this repo must use the pre-commit hook to lower the likelihood that secrets will be exposed.

### Step 1: Install pre-commit

You can install pre-commit using the MacOS package manager Homebrew:

```sh
brew install pre-commit
```

Other installation options can be found in the [pre-commit documentation](https://pre-commit.com/#install).

### Step 2: Install the hooks

Run the following command to install the gitleaks hook:

```sh
pre-commit install
```

This will download and install the pre-commit hooks specified in `.pre-commit-config.yaml`.


## Connecting AWS accounts via OIDC

Workflows running in GitHub servers must use OpenID Connect (OIDC) to interact with the AWS API. We have manually created OIDC identity providers and IAM roles in each AWS account for this purpose.
