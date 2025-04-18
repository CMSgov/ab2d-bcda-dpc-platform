# Terraform for the AWS WAF configuration for APIs in target accounts

This terraform code sets up the WAF for the APIs.

## What is AWS WAF?

[WAF](https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html) stands for "Web Application Firewall", it is a means of filtering web traffic through our applications, and allows for more fine-tuned filtering than security groups alone can provide. WAFs work by using Access Control Lists (ACLs) to protect a set of AWS resources, typically a Load Balancer in our use-case. These ACLs have rules attached to them that define the inspections that take place when a request passes through the WAF, which is how requests are ALLOWed or BLOCKed (or COUNTed, in the case of an override).

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan
```

## How to manage IP allowlists:

The WAF shared service creates empty IPv4 and IPv6 allowlists by default, and attaches them to the ACL. IP ranges in these allowlists can be managed through either a [Github Actions workflow](https://github.com/CMSgov/cdap/blob/main/.github/workflows/ab2d-ip-sets-sync.yml), like AB2D, or a [Lambda function](https://github.com/CMSgov/cdap/tree/main/terraform/services/api-waf-sync), like BCDA and DPC. These allowlists ensure that only IPs that fall within the defined CIDR ranges can make through the WAF and hit the associated API.

Additionally, we provide an external-services IP set, which is populated with internal CIDRs to allow access within the VPN. CIDRs included in this IP set fall under zScaler ranges and NAT gateways for VPCs on the same account. These IP sets are managed by the CDAP team.

## How to temporarily shutdown API access:

To shutdown API access for all customers, we have two options:

- Remove the 0.0.0.0 ingress rule on the associated Load Balancer,
- OR remove all IP ranges from the appropriate allowlist and stop any automated processes that might overwrite those changes (in the case of the Lambda-managed IP sets)

To restore access, simply add back the 0.0.0.0 ingress rule, or run the automation for the IP sets, depending on the option chosen.

Similarly, to shutdown API access for a specific customer or IP range:

- Add a listener rule to the Load Balancer that specifies the IP ranges we wish to block, and deny them access
- OR remove the problematic IP range from the associated allowlist and stop any automated processes that might overwrite those changes (in the case of the Lambda-managed IP sets)

To restore access, remove the listener rule blocking the IP range, or run the automation for the IP sets, depending on the option chosen.

## How to override default rules:

Occasionally, the need arises for an override of an Amazon provided rule. (For example, if customers are routinely sending requests with no UserAgent header, Amazon will block it due to matching the NoUserAgentHEADER default rule. We'd still want these requests to come through, so we would override the default rule on the app that is experiencing this.) Luckily, Amazon provides us with a method to do so, which is also available in the Terraform library. To override, simple note the name of the problematic rule, and create an override in the WAF module. This can be done by either specifying a rule to override for all environments and apps:
<details>
<summary>Blanket Override</summary>

```
rule_action_override {
  name = "SizeRestrictions_BODY"
  action_to_use {
    count {}
  }
}
```
</details>

Or, by specifying a specific app or environment to override the rule in:
<details>
<summary>App/Environment Specific Override</summary>

```
dynamic "rule_action_override" {
  for_each = var.app == "dpc" ? ["apply"] : []
  content {
    name = "CrossSiteScripting_BODY"
    action_to_use {
      count {}
    }
  }
}
```
</details>
