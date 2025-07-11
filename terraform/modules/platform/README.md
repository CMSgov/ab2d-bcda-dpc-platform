# Platform Child Module

This simple [child module](https://developer.hashicorp.com/terraform/language/modules#child-modules) comprises data sources, outputs, and some modest logic to encourage adoption of DASG's emerging, _platform_-wide standards for use in CDAP-customer terraform modules.
The resources that are referenced by terraform data source in this module are managed by the CMS Hybrid Cloud team and/or the CDAP team.

**NOTE** Ensure changes made to local.static_tags that are relevant to both **this** module and the `standards` module remain synchronized. 

## Limitations

**This module is suitable for CDAP-customer usage in greenfield environments only.**

This child module is opinionated and makes various assumptions about the environment in which it operates in order to balance a maximum value with limited complexity.
The key assumptions are focused on the existence of resources that managed externally from customer infrastructure-as-code repositories, such as account-level and vpc-level resources, provided by the CMS Hybrid Cloud and CDAP teams.

## Example Usage

```hcl
## AB2D API Module Usage Example
module "platform" {
  # Ensure `ref` in the following line is pinned to something static
  # e.g. a known branch, commit hash, or tag from **this repository**
  source = "git::https://github.com/CMSgov/cdap.git//terraform/modules/platform?ref=plt-1033"

  app         = "ab2d"
  env         = var.env
  root_module = "https://github.com/CMSgov/ab2d-ops/tree/main/terraform/services/api"
  service     = "api"
}

## Configure the aws provider with the default tag standards sourced from the `platform` child module
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = module.platform.default_tags
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.10.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~>5 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | The short name for the delivery team or ADO. | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The solution's environment name. | `string` | n/a | yes |
| <a name="input_root_module"></a> [root\_module](#input\_root\_module) | The full URL to the terraform module root at issue for this infrastructure | `string` | n/a | yes |
| <a name="input_service"></a> [service](#input\_service) | Service _or_ terraservice name. | `string` | n/a | yes |
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional tags to merge into final default\_tags output | `map(string)` | `{}` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

No modules.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy.permissions_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/nat_gateway) | data source |
| [aws_nat_gateways.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/nat_gateways) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |
| [aws_security_groups.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_groups) | data source |
| [aws_ssm_parameter.platform_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_subnets.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | The AWS account ID associated with the current caller identity |
| <a name="output_app"></a> [app](#output\_app) | The short name for the delivery team or ADO. |
| <a name="output_default_tags"></a> [default\_tags](#output\_default\_tags) | Map of tags for use in AWS provider block `default_tags`. Merges collection of standard tags with optional, user-specificed `additional_tags` |
| <a name="output_env"></a> [env](#output\_env) | The solution's application environment name. |
| <a name="output_is_ephemeral_env"></a> [is\_ephemeral\_env](#output\_is\_ephemeral\_env) | Returns true when environment is \_ephemeral\_, false when \_established\_ |
| <a name="output_kion_roles"></a> [kion\_roles](#output\_kion\_roles) | Map of common kion/cloudtamer [aws\_iam\_role data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role#attributes-reference), keyed by `name`. |
| <a name="output_logging_bucket"></a> [logging\_bucket](#output\_logging\_bucket) | The designated access log bucket [aws\_s3\_bucket data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket#attribute-reference) for the current environment |
| <a name="output_nat_gateways"></a> [nat\_gateways](#output\_nat\_gateways) | Map of current VPC **available** [aws\_nat\_gateway data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role#attributes-reference), keyed by `id`. |
| <a name="output_parent_env"></a> [parent\_env](#output\_parent\_env) | The solution's source environment. For established environments this is equal to the environment's name |
| <a name="output_platform_cidr"></a> [platform\_cidr](#output\_platform\_cidr) | The CIDR-range for the CDAP-managed VPC for CI and other administrative functions. |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | Map of current VPC **private** [aws\_subnet data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet), keyed by `subnet_id` |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | Map of current VPC **public** [aws\_subnet data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet), keyed by `id` |
| <a name="output_region_name"></a> [region\_name](#output\_region\_name) | The region name associated with the current caller identity |
| <a name="output_sdlc_env"></a> [sdlc\_env](#output\_sdlc\_env) | The SDLC (production vs non-production) environment. |
| <a name="output_security_groups"></a> [security\_groups](#output\_security\_groups) | Map of current VPC's common [aws\_security\_group data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group#attribute-reference), keyed by `name` |
| <a name="output_service"></a> [service](#output\_service) | The name of the current service or terraservice. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The current environment VPC ID value |
<!-- END_TF_DOCS -->
