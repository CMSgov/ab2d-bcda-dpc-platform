//TODO: 
// - Add rate limiting rule to match BCDA's config
// - SQL Injection ruleset
// - Cloudfront distribution (?)
resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = var.scope

  default_action {
    allow {

    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }

  dynamic "rule" {
    for_each = var.rate_based_rule != null ? [var.rate_based_rule] : []
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {
            dynamic "custom_response" {
              for_each = rule.value.response_code != 403 ? [1] : []
              content {
                response_code = rule.value.response_code
              }
            }
          }
        }
      }

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }



  rule {
    name     = "CommonRuleset"
    priority = 0
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "CommonRuleset"
        vendor_name = "AWS"

        rule_action_override {
          name = "Example"
          action_to_use {
            allow {}
          }

        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = var.name
      sampled_requests_enabled   = true
    }

  }
}

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = var.aws_lb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
