# Packer Build Action

GitHub Action for validating and building OpenStack images using HashiCorp Packer through a bastion host.

## Features

- 🔍 **Validate Mode**: Syntax-only validation (no credentials required)
- 🔨 **Build Mode**: Full image builds via bastion host
- 📦 **Ansible Integration**: Automatic Ansible Galaxy role installation
- 🔄 **Auto-discovery**: Finds Packer templates and var files automatically
- 🌐 **Multi-cloud Ready**: Configurable for any OpenStack environment

## Usage

### Validate Packer Templates

```yaml
- name: Validate Packer templates
  uses: lfreleng-actions/packer-build-action@v1
  with:
    mode: validate
    packer_working_dir: packer
```

### Build Images with Bastion

```yaml
jobs:
  build-image:
    runs-on: ubuntu-latest
    steps:
      # Setup bastion first
      - name: Setup bastion
        id: bastion
        uses: lfreleng-actions/openstack-bastion-action@v1
        with:
          mode: setup
          tailscale_oauth_client_id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
          tailscale_oauth_secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
          openstack_auth_url: ${{ secrets.OPENSTACK_AUTH_URL }}
          openstack_project_id: ${{ secrets.OPENSTACK_PROJECT_ID }}
          openstack_username: ${{ secrets.OPENSTACK_USERNAME }}
          openstack_password: ${{ secrets.OPENSTACK_PASSWORD }}
          openstack_network_id: ${{ secrets.OPENSTACK_NETWORK_ID }}

      # Build with Packer
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

## Related Actions

- [openstack-bastion-action](https://github.com/lfreleng-actions/openstack-bastion-action) - Bastion host management

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

## Support

For issues and questions:

- GitHub Issues: [Report a bug](https://github.com/lfreleng-actions/packer-build-action/issues)
- Documentation: [docs/](docs/)
