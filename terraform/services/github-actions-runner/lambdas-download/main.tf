locals {
  release_tag = "v5.17.0"
}

module "lambdas" {
  source = "github.com/philips-labs/terraform-aws-github-runner//modules/download-lambda"
  lambdas = [
    {
      name = "webhook"
      tag  = local.release_tag
    },
    {
      name = "runners"
      tag  = local.release_tag
    },
    {
      name = "runner-binaries-syncer"
      tag  = local.release_tag
    },
    {
      name = "ami-housekeeper"
      tag  = local.release_tag
    }
  ]
}

output "files" {
  value = module.lambdas.files
}
