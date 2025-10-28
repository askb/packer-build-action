# Packer Build Action

GitHub Action for validating and building OpenStack images using HashiCorp Packer through a Tailscale bastion host.

## Features

- 🔍 **Validate Mode**: Syntax-only validation (no credentials required)
- 🔨 **Build Mode**: Full image builds via Tailscale bastion host
- 📦 **Ansible Integration**: Automatic Ansible Galaxy role installation
- 🔄 **Auto-discovery**: Finds Packer templates and var files automatically
- 🌐 **Multi-cloud Ready**: Configurable for any OpenStack environment
- 🔐 **OAuth Ephemeral Keys**: Uses Tailscale OAuth for secure, temporary connections

## Architecture

This action works in conjunction with [tailscale-openstack-bastion-action](https://github.com/askb/tailscale-openstack-bastion-action) to:

1. **Bastion Setup**: Creates an ephemeral OpenStack instance with Tailscale
2. **Packer Build**: Executes Packer build through the bastion's secure tunnel
3. **Cleanup**: Automatically tears down the bastion after build completion

## Usage

### Validate Packer Templates

Validation mode performs syntax checking without requiring cloud credentials or a bastion:

```yaml
- name: Validate Packer templates
  uses: lfreleng-actions/packer-build-action@v1
  with:
    mode: validate
    packer_working_dir: packer
```

### Build Images with Bastion

Complete workflow showing bastion setup, build, and teardown:

```yaml
jobs:
  build-image:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Step 1: Setup bastion with Tailscale
      - name: Setup bastion
        id: bastion
        uses: lfreleng-actions/tailscale-openstack-bastion-action@v1
        with:
          mode: setup
          tailscale-oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
          tailscale-oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
          openstack-auth-url: ${{ secrets.OPENSTACK_AUTH_URL }}
          openstack-project-id: ${{ secrets.OPENSTACK_PROJECT_ID }}
          openstack-username: ${{ secrets.OPENSTACK_USERNAME }}
          openstack-password-b64: ${{ secrets.OPENSTACK_PASSWORD_B64 }}
          openstack-region: ${{ secrets.OPENSTACK_REGION }}
          bastion-name: "packer-build-${{ github.run_id }}"
          bastion-flavor: "v3-standard-2"
          bastion-image: "Ubuntu 22.04.5 LTS (x86_64) [2025-03-27]"
          bastion-network: "your-network-name"

      # Step 2: Build with Packer
      - name: Build image
        uses: lfreleng-actions/packer-build-action@v1
        with:
          mode: build
          bastion_ip: ${{ steps.bastion.outputs.bastion_ip }}
          bastion_ssh_user: ${{ steps.bastion.outputs.bastion_ssh_user }}
          packer_template: templates/builder.pkr.hcl
          packer_vars_file: vars/ubuntu-22.04.pkrvars.hcl
          openstack_auth_url: ${{ secrets.OPENSTACK_AUTH_URL }}
          openstack_project_id: ${{ secrets.OPENSTACK_PROJECT_ID }}
          openstack_username: ${{ secrets.OPENSTACK_USERNAME }}
          openstack_password: ${{ secrets.OPENSTACK_PASSWORD }}
          openstack_network_id: ${{ secrets.OPENSTACK_NETWORK_ID }}

      # Cleanup bastion
      - name: Teardown bastion
        if: always()
        uses: lfreleng-actions/openstack-bastion-action@v1
        with:
          mode: teardown
          bastion_id: ${{ steps.bastion.outputs.bastion_id }}
          openstack_auth_url: ${{ secrets.OPENSTACK_AUTH_URL }}
          openstack_project_id: ${{ secrets.OPENSTACK_PROJECT_ID }}
          openstack_username: ${{ secrets.OPENSTACK_USERNAME }}
          openstack_password: ${{ secrets.OPENSTACK_PASSWORD }}
```

## Inputs

### Required Inputs

| Input  | Description                           | Default    |
| ------ | ------------------------------------- | ---------- |
| `mode` | Operation mode: `validate` or `build` | `validate` |

### Build Mode Required Inputs

| Input                  | Description                              |
| ---------------------- | ---------------------------------------- |
| `bastion_ip`           | Bastion Tailscale IP from bastion action |
| `openstack_auth_url`   | OpenStack authentication URL             |
| `openstack_project_id` | OpenStack project/tenant ID              |
| `openstack_username`   | OpenStack username                       |
| `openstack_password`   | OpenStack password                       |
| `openstack_network_id` | OpenStack network UUID                   |

### Optional Inputs

| Input                | Description               | Default       |
| -------------------- | ------------------------- | ------------- |
| `packer_template`    | Path to Packer template   | Auto-discover |
| `packer_vars_file`   | Path to vars file         | Auto-discover |
| `packer_working_dir` | Working directory         | `.`           |
| `path_prefix`        | Path prefix for execution | `target-repo` |
| `packer_version`     | Packer version            | `1.11.2`      |
| `ansible_version`    | Ansible version           | `2.17.0`      |
| `python_version`     | Python version            | `3.11`        |
| `bastion_ssh_user`   | SSH user for bastion      | `ubuntu`      |

## Outputs

| Output              | Description                   |
| ------------------- | ----------------------------- |
| `validation_result` | Validation result summary     |
| `image_name`        | Built image name (build mode) |
| `image_id`          | Built image ID (build mode)   |
| `build_status`      | Build completion status       |

## Requirements

### For Validate Mode

- Packer templates with valid HCL syntax
- No credentials required

### For Build Mode

- Active bastion host (from `openstack-bastion-action`)
- OpenStack credentials
- Packer templates configured for OpenStack
- Ansible roles (if using common-packer)

## Project Structure

```
packer-build-action/
├── action.yaml              # Action definition
├── scripts/
│   └── validate-packer.sh   # Validation script
├── docs/
│   ├── USAGE.md            # Detailed usage guide
│   ├── PACKER_TEMPLATES.md # Template requirements
│   └── TROUBLESHOOTING.md  # Common issues
└── examples/
    └── workflows/          # Example workflows
```

## Documentation

- [Usage Guide](docs/USAGE.md) - Detailed usage instructions
- [Packer Templates](docs/PACKER_TEMPLATES.md) - Template requirements
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Development](docs/DEVELOPMENT.md) - Contributing guide

## Test Workflows

This repository includes test workflows for each Tailscale authentication method supported by the bastion action:

### 1. OAuth with Ephemeral Keys (Recommended) ⭐

**Workflow:** `.github/workflows/test-build-minimal.yaml`

**Description:** Tests Packer build using Tailscale OAuth with ephemeral keys. This is the **recommended** authentication method for production use.

**Status:** ✅ **WORKING** (as of 2025-10-21 after fixes to `openstack-bastion-action`)

**Benefits:**

- ✅ Automatic key rotation (no 90-day manual rotation like legacy auth keys)
- ✅ Better security (keys expire automatically)
- ✅ No manual key management
- ✅ Persistent nodes (survive network disconnects)
- ✅ Production-ready

**Recent Fixes (2025-10-21):**
The `openstack-bastion-action` dependency was updated with two critical fixes:

1. Changed `EPHEMERAL=false` - Creates persistent nodes instead of auto-removed ephemeral nodes
2. Changed runner tags to `tag:ci` - Correct ACL permissions for GitHub Actions runner

These fixes ensure OAuth ephemeral authentication works reliably for production workloads.

**Bastion Configuration:**

```yaml
tailscale_oauth_client_id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
tailscale_oauth_secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
tailscale_use_ephemeral_keys: "true" # Generates OAuth ephemeral keys
tailscale_tags: "tag:bastion" # Required for proper ACL permissions
```

**Required Secrets:**

- `TAILSCALE_OAUTH_CLIENT_ID`
- `TAILSCALE_OAUTH_SECRET`

---

### 2. OAuth with Reusable Keys ⚠️ **NOT SUPPORTED**

**Workflow:** `.github/workflows/test-build-oauth-reusable.yaml` **[DISABLED]**

**Status:** ❌ **This authentication method is currently not supported by the bastion action.**

**Reason:** The bastion VM uses cloud-init to configure Tailscale, and cloud-init cannot use OAuth directly. OAuth with reusable keys (ephemeral=false) requires direct OAuth authentication which is not possible in the cloud-init environment.

**Alternatives:**

- Use **OAuth with Ephemeral Keys** (recommended) - generates temporary keys from OAuth
- Use **Legacy Auth Key** - uses pre-created Tailscale auth key

**Technical Details:**

```yaml
# This configuration will FAIL:
tailscale_oauth_client_id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
tailscale_oauth_secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
tailscale_use_ephemeral_keys: "false" # ❌ Not supported for bastion
```

**Error Message:**

```
Error: OAuth without ephemeral keys is not supported for bastion hosts
The bastion (cloud-init) cannot use OAuth directly.
```

The workflow file is kept for reference but is disabled (no auto-triggers) and will always fail.

---

### 3. Legacy Auth Key (Deprecated)

**Workflow:** `.github/workflows/test-build-authkey.yaml`

**Description:** Tests Packer build using the legacy Tailscale auth key method. This method is **deprecated** but still supported for backwards compatibility.

**Bastion Configuration:**

```yaml
tailscale_auth_key: ${{ secrets.TAILSCALE_AUTH_KEY }}
```

**Required Secrets:**

- `TAILSCALE_AUTH_KEY`

**Note:** OAuth methods are recommended over legacy auth keys.

---

### Running Tests

**Via GitHub UI:**

1. Go to the Actions tab
2. Select the workflow you want to run
3. Click "Run workflow"
4. Optionally customize inputs
5. Click the "Run workflow" button

**Via GitHub CLI:**

```bash
# OAuth Ephemeral (recommended)
gh workflow run test-build-minimal.yaml

# Legacy Auth Key
gh workflow run test-build-authkey.yaml

# OAuth Reusable - DISABLED (not supported, will fail)
# gh workflow run test-build-oauth-reusable.yaml
```

---

### Authentication Method Comparison

| Method          | Security | Complexity | Supported | Recommended   | Key Management      |
| --------------- | -------- | ---------- | --------- | ------------- | ------------------- |
| OAuth Ephemeral | ⭐⭐⭐   | Low        | ✅ Yes    | ✅ Yes        | Automatic           |
| OAuth Reusable  | ⭐⭐     | Low        | ❌ **No** | ❌ No         | N/A (not supported) |
| Legacy Auth Key | ⭐       | Very Low   | ✅ Yes    | ⚠️ Deprecated | Manual rotation     |

---

### How Tailscale SSH Works with Packer

The two supported authentication methods (OAuth Ephemeral and Legacy Auth Key) result in the same SSH behavior:

1. **Bastion Setup:** The bastion action sets up Tailscale on both the GitHub runner and the bastion instance
2. **Network Join:** Both join the same Tailscale network using the chosen auth method
3. **Packer Connection:** Packer uses `ssh_bastion_agent_auth = true` to satisfy its validation requirement
4. **SSH Agent:** An empty SSH agent is started (required by Packer, even though not used)
5. **Tailscale Intercept:** When Packer connects, Tailscale SSH intercepts and handles authentication automatically
6. **No Traditional Keys:** No SSH private keys, passwords, or agent keys are needed

**Key Insight:** The authentication method only affects how the runner and bastion join the Tailscale network, not how Packer connects through the bastion.

---

## Related Actions

- [tailscale-openstack-bastion-action](https://github.com/askb/tailscale-openstack-bastion-action) - Bastion host management with Tailscale

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/amazing-feature`
3. **Commit your changes with DCO sign-off:** `git commit -s`
4. **Push to the branch:** `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <description>

[optional body]

Signed-off-by: Your Name <your.email@example.com>
```

**Types:** Feat, Fix, Chore, Docs, Style, Refactor, Perf, Test, CI, Build

### Code Quality

- Run `pre-commit run --all-files` before committing
- Ensure all tests pass
- Follow existing code style
- Add tests for new features

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

Copyright © 2025 The Linux Foundation

## Support

For issues and questions:

- GitHub Issues: [Report a bug](https://github.com/lfreleng-actions/packer-build-action/issues)
- Documentation: [docs/](docs/)
