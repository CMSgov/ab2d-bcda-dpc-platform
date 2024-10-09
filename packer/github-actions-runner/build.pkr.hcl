packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

build {
  name = "github-actions-runner"
  sources = [
    "source.amazon-ebs.github-actions-runner"
  ]

  provisioner "shell" {
    remote_folder = "/home/ec2-user/"
    environment_vars = []
    inline = [
      "sudo yum -y update --security",
      "sudo yum -y install amazon-cloudwatch-agent jq git docker",
      "sudo yum -y install curl",
      "sudo systemctl enable docker.service",
      "sudo systemctl enable containerd.service",
      "sudo service docker start",
      "sudo usermod -a -G docker ec2-user",
    ]
  }

  provisioner "file" {
    content = templatefile("./install-runner.sh", {
      S3_LOCATION_RUNNER_DISTRIBUTION = var.s3_tarball
    })
    destination = "/home/ec2-user/install-runner.sh"
  }

  provisioner "shell" {
    remote_folder = "/home/ec2-user/"
    inline = [
      "chmod +x /home/ec2-user/install-runner.sh",
      "/home/ec2-user/install-runner.sh"
    ]
  }

  provisioner "file" {
    content = templatefile("./start-runner.sh", { metadata_tags = "enabled" })
    destination = "/home/ec2-user/start-runner.sh"
  }

  provisioner "shell" {
    remote_folder = "/home/ec2-user/"
    inline = [
      "sudo mv /home/ec2-user/start-runner.sh /var/lib/cloud/scripts/per-boot/start-runner.sh",
      "sudo chmod +x /var/lib/cloud/scripts/per-boot/start-runner.sh",
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}

