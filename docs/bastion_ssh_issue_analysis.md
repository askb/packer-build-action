# SSH Bastion Support Issue in releng-common-packer

## Summary

The `releng-common-packer` repository's Packer templates DO NOT support SSH bastion configuration, which is causing test failures in the `packer-build-action` repository when attempting to build via a bastion host.

## Root Cause Analysis

### Current Template Configuration

In `/packer/common-packer/templates/builder.pkr.hcl`, the OpenStack source only defines:

```hcl
source "openstack" "builder" {
  flavor            = "${var.flavor}"
  image_disk_format = "${var.vm_image_disk_format}"
  image_name        = "ZZCI - ${var.distro} - builder - ${var.arch} - ${legacy_isotime("20060102-150405.000")}"
  instance_name     = "${var.distro}-builder-${uuidv4()}"
  metadata = {
    ci_managed = "yes"
  }
  networks                = ["${var.cloud_network}"]
  region                  = "${var.cloud_region}"
  source_image_name       = "${var.base_image}"
  ssh_proxy_host          = "${var.ssh_proxy_host}"    # ← Only supports SSH proxy, NOT bastion
  ssh_username            = "${var.ssh_user}"
  use_blockstorage_volume = "${var.vm_use_block_storage}"
  user_data_file          = "${var.cloud_user_data}"
  volume_size             = "${var.vm_volume_size}"
}
```

### What's Missing

The template lacks these critical SSH bastion parameters:

- `ssh_bastion_host` - IP address or hostname of the bastion
- `ssh_bastion_username` - Username for bastion authentication
- `ssh_bastion_port` - SSH port on bastion (optional, defaults to 22)
- `ssh_bastion_agent_auth` - Whether to use SSH agent for bastion auth (optional)
- `ssh_bastion_private_key_file` - Private key for bastion auth (optional)

### Current vs Required Configuration

**Current (ssh_proxy_host):**

- Uses SOCKS5 or HTTP proxy for SSH tunneling
- Requires proxy server setup
- Less common for OpenStack bastion scenarios

**Required (ssh*bastion*\*):**

- Direct SSH bastion/jump host support
- Native Packer OpenStack plugin feature
- Standard pattern for accessing private cloud instances

## Test Failure Evidence

From workflow run #18705135427:

```
Warning: an 'only' option was passed, but not all matches were found for the given build.

A build command cannot run without at least one build to process.
```

The `-only='*.openstack.builder'` flag fails because:

1. Template defines TWO builders: `docker.builder` and `openstack.builder`
2. When bastion config is passed via Packer vars, the openstack builder tries to use bastion SSH settings
3. Template doesn't declare the bastion variable definitions
4. Build selection fails

## Required Fix in releng-common-packer

### 1. Add Variable Declarations

Add to `templates/builder.pkr.hcl`:

```hcl
variable "ssh_bastion_host" {
  type    = string
  default = ""
  description = "Bastion host for SSH access to OpenStack instances"
}

variable "ssh_bastion_username" {
  type    = string
  default = ""
  description = "Username for bastion host authentication"
}

variable "ssh_bastion_port" {
  type    = number
  default = 22
  description = "SSH port on bastion host"
}

variable "ssh_bastion_agent_auth" {
  type    = bool
  default = true
  description = "Use SSH agent for bastion authentication"
}
```

### 2. Update OpenStack Source Block

Modify the `source "openstack" "builder"` block:

```hcl
source "openstack" "builder" {
  flavor            = "${var.flavor}"
  image_disk_format = "${var.vm_image_disk_format}"
  image_name        = "ZZCI - ${var.distro} - builder - ${var.arch} - ${legacy_isotime("20060102-150405.000")}"
  instance_name     = "${var.distro}-builder-${uuidv4()}"
  metadata = {
    ci_managed = "yes"
  }
  networks                = ["${var.cloud_network}"]
  region                  = "${var.cloud_region}"
  source_image_name       = "${var.base_image}"

  # Legacy proxy support (kept for backwards compatibility)
  ssh_proxy_host          = "${var.ssh_proxy_host}"

  # Bastion/Jump host support (NEW)
  ssh_bastion_host        = var.ssh_bastion_host != "" ? var.ssh_bastion_host : null
  ssh_bastion_username    = var.ssh_bastion_username != "" ? var.ssh_bastion_username : null
  ssh_bastion_port        = var.ssh_bastion_port
  ssh_bastion_agent_auth  = var.ssh_bastion_agent_auth

  ssh_username            = "${var.ssh_user}"
  use_blockstorage_volume = "${var.vm_use_block_storage}"
  user_data_file          = "${var.cloud_user_data}"
  volume_size             = "${var.vm_volume_size}"
}
```

### 3. Documentation Updates

Update `packer/common-packer/README.md` to document:

- New bastion variables
- When to use `ssh_bastion_*` vs `ssh_proxy_host`
- Example usage with bastion hosts

## Alternative Workaround (Temporary)

If upstream fix takes time, the `packer-build-action` can work around this by:

1. Forking/vendoring releng-common-packer templates
2. Adding bastion support in the forked version
3. Using the forked templates in tests

However, this is NOT recommended as it creates maintenance burden.

## Impact

**Who's affected:**

- Anyone using releng-common-packer templates with bastion hosts
- CI/CD pipelines that build via jump hosts
- Environments where direct OpenStack access isn't available

**Severity:** High

- Blocks packer-build-action testing with upstream templates
- Limits deployment flexibility for OpenStack users

## Packer OpenStack Plugin Documentation

Reference: https://developer.hashicorp.com/packer/integrations/hashicorp/openstack/latest/components/builder/openstack

Relevant bastion parameters:

- `ssh_bastion_host` (string)
- `ssh_bastion_port` (int)
- `ssh_bastion_agent_auth` (bool)
- `ssh_bastion_username` (string)
- `ssh_bastion_password` (string)
- `ssh_bastion_interactive` (bool)
- `ssh_bastion_private_key_file` (string)

## Next Steps

1. **File Issue:** Create issue in lfit/releng-common-packer repository
2. **Submit PR:** Implement the fix described above
3. **Test:** Verify fix works with packer-build-action
4. **Document:** Update releng-common-packer docs with bastion usage

## Test Case for Verification

After fix is merged, this should work:

```bash
packer build \
  -var "ssh_bastion_host=100.64.183.39" \
  -var "ssh_bastion_username=root" \
  -var "ssh_bastion_agent_auth=true" \
  -var-file=vars/ubuntu-22.04.pkrvars.hcl \
  templates/builder.pkr.hcl
```

---

## Visual Diagram: Current vs Required Architecture

### Current State (Failing)

```
┌─────────────────────┐
│ GitHub Actions      │
│ packer-build-action │
└──────────┬──────────┘
           │
           │ Passes bastion config:
           │ - ssh_bastion_host
           │ - ssh_bastion_username
           │
           ▼
┌─────────────────────────────────┐
│ releng-common-packer            │
│ templates/builder.pkr.hcl       │
│                                 │
│ ✗ NO bastion variables defined │
│ ✗ NO ssh_bastion_* in source   │
│ ✓ Only ssh_proxy_host supported│
└─────────────────────────────────┘
           │
           ▼
    ❌ BUILD FAILS
    "undefined variable" or
    "no builds to process"
```

### Required State (Fixed)

```
┌─────────────────────┐
│ GitHub Actions      │
│ packer-build-action │
└──────────┬──────────┘
           │
           │ Passes bastion config:
           │ - ssh_bastion_host=100.64.183.39
           │ - ssh_bastion_username=root
           │
           ▼
┌──────────────────────────────────────┐
│ releng-common-packer                 │
│ templates/builder.pkr.hcl            │
│                                      │
│ ✓ Bastion variables declared         │
│ ✓ ssh_bastion_* in openstack source │
│ ✓ Backwards compatible              │
└──────────┬───────────────────────────┘
           │
           │ SSH via bastion
           │
           ▼
┌──────────────────────┐      SSH      ┌────────────────────┐
│ Bastion Host         │◄──────────────│ OpenStack Instance │
│ 100.64.183.39        │               │ (Private Network)  │
│ (Tailscale/Public)   │               │                    │
└──────────────────────┘               └────────────────────┘
           ▲
           │
    ✅ BUILD SUCCEEDS
    Packer connects via bastion
    to provision OpenStack VM
```

---

## Code Comparison

### Before (Current - No Bastion Support)

```hcl
# Variables section - NO bastion vars
variable "ssh_proxy_host" {
  type    = string
  default = ""
}

# Source section
source "openstack" "builder" {
  # ... other config ...
  ssh_proxy_host = "${var.ssh_proxy_host}"  # Only proxy, no bastion
  ssh_username   = "${var.ssh_user}"
}
```

### After (Fixed - With Bastion Support)

```hcl
# Variables section - ADD bastion vars
variable "ssh_proxy_host" {
  type    = string
  default = ""
}

variable "ssh_bastion_host" {
  type    = string
  default = ""
}

variable "ssh_bastion_username" {
  type    = string
  default = ""
}

variable "ssh_bastion_port" {
  type    = number
  default = 22
}

variable "ssh_bastion_agent_auth" {
  type    = bool
  default = true
}

# Source section
source "openstack" "builder" {
  # ... other config ...

  # Legacy proxy support
  ssh_proxy_host = "${var.ssh_proxy_host}"

  # NEW: Bastion/jump host support
  ssh_bastion_host       = var.ssh_bastion_host != "" ? var.ssh_bastion_host : null
  ssh_bastion_username   = var.ssh_bastion_username != "" ? var.ssh_bastion_username : null
  ssh_bastion_port       = var.ssh_bastion_port
  ssh_bastion_agent_auth = var.ssh_bastion_agent_auth

  ssh_username = "${var.ssh_user}"
}
```

---

## Key Differences: ssh*proxy_host vs ssh_bastion*\*

| Feature                 | ssh_proxy_host          | ssh*bastion*\*            |
| ----------------------- | ----------------------- | ------------------------- |
| **Type**                | SOCKS5/HTTP proxy       | SSH jump host             |
| **Setup**               | Requires proxy server   | Native SSH bastion        |
| **Authentication**      | Proxy auth              | SSH keys/agent            |
| **Use Case**            | Generic proxy tunneling | OpenStack bastion pattern |
| **Packer Support**      | Generic                 | OpenStack plugin native   |
| **Common in OpenStack** | ❌ Rare                 | ✅ Standard               |

---

## Additional Context: Why Tests Are Failing

The test workflow does this:

1. Creates a Tailscale bastion host in OpenStack
2. Gets bastion IP: `100.64.183.39`
3. Tries to pass bastion config to Packer:
   ```yaml
   bastion_ip: ${{ steps.bastion.outputs.bastion_ip }}
   bastion_ssh_user: "root"
   ```
4. The action translates this to Packer vars
5. But releng-common-packer template doesn't accept these vars
6. Build fails with "undefined variable" or "no matching builds"

The fix enables the entire bastion workflow to work end-to-end.
