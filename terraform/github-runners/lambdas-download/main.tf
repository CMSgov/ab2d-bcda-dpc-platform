module "lambdas" {
  source = "github.com/philips-labs/terraform-aws-github-runner//modules/download-lambda"
  lambdas = [
    {
      name = "webhook"
      tag  = var.module_version
    },
    {
      name = "runners"
      tag  = var.module_version
    },
    {
      name = "runner-binaries-syncer"
      tag  = var.module_version
    }
  ]
}

output "files" {
  value = module.lambdas.files
}
