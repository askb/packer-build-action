# Example Packer Template with Bastion Support

This example demonstrates how to configure Packer templates to work with the OpenStack Tailscale bastion workflow.

## Structure

```
examples/
├── templates/
│   ├── builder.pkr.hcl          # Example Ubuntu builder
│   └── variables.pkr.hcl        # Variable definitions
├── vars/
│   └── ubuntu-22.04.pkrvars.hcl # Variable values
└── provision/
    └── baseline.sh              # Provisioning script
```

## Usage

### 1. Copy Templates to Your Project

```bash
cp -r examples/templates/ packer/templates/
cp -r examples/vars/ packer/vars/
cp -r examples/provision/ packer/provision/
```

### 2. Customize Variables

Edit `packer/vars/ubuntu-22.04.pkrvars.hcl`:

```hcl
base_image = "Ubuntu 22.04"
cloud_network = "default"
cloud_region = "ca-ymq-1"
ssh_user = "ubuntu"
distro = "ubuntu2204"
```

### 3. Run Locally (Optional)

```bash
cd packer

# Initialize plugins
packer init templates/builder.pkr.hcl

# Validate template
packer validate \
  -var-file=vars/ubuntu-22.04.pkrvars.hcl \
  templates/builder.pkr.hcl

# Build (if you have a bastion)
packer build \
  -var-file=vars/ubuntu-22.04.pkrvars.hcl \
  -var="bastion_host=100.64.1.100" \
  -var="bastion_user=root" \
  templates/builder.pkr.hcl
```

### 4. Run via GitHub Actions

The workflow will automatically:

1. Create bastion host
2. Wait for Tailscale connection
3. Build with bastion configuration
4. Cleanup bastion

## Key Features

### Bastion Support

The template includes bastion host configuration:

```hcl
variable "bastion_host" {
  type        = string
  default     = ""
  description = "Bastion host IP address (Tailscale)"
}

variable "bastion_user" {
  type        = string
  default     = "root"
  description = "Bastion host SSH user"
}

source "openstack" "builder" {
  # ... other config ...

  # SSH via bastion
  ssh_bastion_host     = var.bastion_host != "" ? var.bastion_host : null
  ssh_bastion_username = var.bastion_user
}
```

### Cloud Configuration

OpenStack cloud settings:

```hcl
cloud_auth_url    = env("OS_AUTH_URL")
cloud_tenant_name = env("OS_PROJECT_NAME")
cloud_username    = env("OS_USERNAME")
cloud_password    = env("OS_PASSWORD")
cloud_region      = var.cloud_region
```

### Build Provisioning

The example includes basic provisioning:

```hcl
provisioner "shell" {
  script = "provision/baseline.sh"
}
```

## Customization

### Add More Templates

Create additional templates in `templates/`:

```hcl
# templates/docker.pkr.hcl
source "openstack" "docker" {
  name = "docker-${var.distro}"
  # ... config ...
}

build {
  sources = ["source.openstack.docker"]

  provisioner "shell" {
    script = "provision/docker.sh"
  }
}
```

### Add More Variables

Create additional var files in `vars/`:

```hcl
# vars/ubuntu-24.04.pkrvars.hcl
base_image = "Ubuntu 24.04"
distro = "ubuntu2404"
# ... other vars ...
```

### Multi-stage Provisioning

```hcl
build {
  sources = ["source.openstack.builder"]

  provisioner "shell" {
    script = "provision/01-baseline.sh"
  }

  provisioner "ansible" {
    playbook_file = "provision/playbook.yml"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo cloud-init clean"
    ]
  }
}
```

## Testing

### Validate All Templates

```bash
#!/bin/bash
for template in templates/*.pkr.hcl; do
  if [[ "$template" == *"variables"* ]]; then
    continue
  fi

  for varfile in vars/*.pkrvars.hcl; do
    echo "Validating $template with $varfile"
    packer validate -var-file="$varfile" "$template"
  done
done
```

### Format Templates

```bash
packer fmt -recursive templates/
```

## Best Practices

1. **Use Variables:** Keep templates flexible with variables
2. **Separate Concerns:** Use different templates for different purposes
3. **Version Plugins:** Pin plugin versions in required_plugins
4. **Test Locally:** Validate before pushing to GitHub
5. **Document:** Add comments explaining complex configurations
6. **Modular Provisioning:** Break provisioning into reusable scripts

## Reference

- [Packer OpenStack Builder](https://www.packer.io/plugins/builders/openstack)
- [Packer HCL Templates](https://www.packer.io/guides/hcl)
- [SSH Bastion Configuration](https://www.packer.io/docs/communicators/ssh#ssh-bastion)
