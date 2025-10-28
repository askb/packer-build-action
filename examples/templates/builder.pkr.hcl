packer {
  required_version = ">= 1.9.0"
  required_plugins {
    openstack = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

# ========================================
# Cloud Provider Variables
# ========================================

variable "cloud_auth_url" {
  type        = string
  default     = env("OS_AUTH_URL")
  description = "OpenStack authentication URL"
}

variable "cloud_tenant_name" {
  type        = string
  default     = env("OS_PROJECT_NAME")
  description = "OpenStack project/tenant name"
}

variable "cloud_username" {
  type        = string
  default     = env("OS_USERNAME")
  description = "OpenStack username"
}

variable "cloud_password" {
  type        = string
  default     = env("OS_PASSWORD")
  sensitive   = true
  description = "OpenStack password"
}

variable "cloud_region" {
  type        = string
  default     = "ca-ymq-1"
  description = "OpenStack region"
}

variable "cloud_network" {
  type        = string
  default     = "default"
  description = "Network name for the instance"
}

variable "cloud_domain_name" {
  type        = string
  default     = env("OS_USER_DOMAIN_NAME")
  description = "OpenStack domain name (required for v3 API)"
}

# ========================================
# Image Configuration Variables
# ========================================

variable "base_image" {
  type        = string
  default     = "Ubuntu 22.04"
  description = "Base image to use for building"
}

variable "image_name" {
  type        = string
  default     = "builder-{{isotime \"2006-01-02-1504\"}}"
  description = "Name for the output image"
}

variable "flavor" {
  type        = string
  default     = "v3-standard-2"
  description = "OpenStack flavor for build instance"
}

variable "ssh_user" {
  type        = string
  default     = "ubuntu"
  description = "SSH user for connecting to instance"
}

variable "distro" {
  type        = string
  default     = "ubuntu2204"
  description = "Distribution identifier"
}

# ========================================
# Bastion Host Variables
# ========================================

variable "bastion_host" {
  type        = string
  default     = ""
  description = "Bastion host IP address (from Tailscale). Leave empty for direct connection."
}

variable "bastion_user" {
  type        = string
  default     = "root"
  description = "SSH user for bastion host"
}

variable "bastion_port" {
  type        = number
  default     = 22
  description = "SSH port for bastion host"
}

# ========================================
# Build Configuration Variables
# ========================================

variable "ssh_timeout" {
  type        = string
  default     = "30m"
  description = "Timeout for SSH connection"
}

variable "ssh_handshake_attempts" {
  type        = number
  default     = 20
  description = "Number of SSH handshake attempts"
}

variable "build_timeout" {
  type        = string
  default     = "60m"
  description = "Maximum time for build to complete"
}

variable "ansible_roles_path" {
  type        = string
  default     = ".galaxy"
  description = "Path for Ansible roles"
}

# ========================================
# OpenStack Source Configuration
# ========================================

source "openstack" "builder" {
  # Authentication
  identity_endpoint = var.cloud_auth_url
  tenant_name       = var.cloud_tenant_name
  domain_name       = var.cloud_domain_name
  username          = var.cloud_username
  password          = var.cloud_password
  region            = var.cloud_region

  # Image configuration
  image_name        = var.image_name
  source_image_name = var.base_image
  flavor            = var.flavor

  # Network
  networks = [var.cloud_network]

  # SSH configuration
  ssh_username = var.ssh_user
  ssh_timeout  = var.ssh_timeout

  # Bastion configuration (conditional)
  # Note: Using Tailscale SSH - requires agent auth to be enabled
  # Even though Tailscale doesn't use the agent, Packer requires one auth method.
  # The SSH agent will be started (potentially empty) to satisfy this requirement.
  # Tailscale handles the actual authentication when the connection is made.
  ssh_bastion_host              = var.bastion_host != "" ? var.bastion_host : null
  ssh_bastion_username          = var.bastion_host != "" ? var.bastion_user : null
  ssh_bastion_port              = var.bastion_host != "" ? var.bastion_port : null
  ssh_bastion_agent_auth        = var.bastion_host != "" ? true : null

  # Connection settings
  communicator                  = "ssh"
  ssh_handshake_attempts        = var.ssh_handshake_attempts
  ssh_pty                       = true

  # Metadata
  metadata = {
    build_date  = "{{isotime \"2006-01-02\"}}"
    build_tool  = "packer"
    distro      = var.distro
    packer_version = "{{packer_version}}"
  }

  # Image visibility
  image_visibility = "private"

  # Floating IP (not needed with bastion)
  use_floating_ip = var.bastion_host != "" ? false : true
}

# ========================================
# Build Definition
# ========================================

build {
  name    = "builder-${var.distro}"
  sources = ["source.openstack.builder"]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "echo 'Cloud-init completed'"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "echo 'System updated'"
    ]
  }

  # Run baseline provisioning
  provisioner "shell" {
    script = "${path.cwd}/provision/baseline.sh"
    environment_vars = [
      "DISTRO=${var.distro}"
    ]
  }

  # Cleanup before image creation
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up before image creation...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean -y",
      "sudo cloud-init clean --logs --seed",
      "sudo rm -rf /var/lib/cloud/instances/*",
      "sudo rm -f /etc/machine-id",
      "sudo touch /etc/machine-id",
      "sudo rm -f ~/.bash_history || true",
      "sudo rm -f /root/.bash_history || true",
      "echo 'Cleanup completed'"
    ]
  }

  # Post-processors can be added here
  # post-processor "manifest" {
  #   output = "manifest.json"
  # }
}
