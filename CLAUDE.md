## Project Overview

ONLYOFFICE OneClickInstall-Docs — one-click installer scripts for ONLYOFFICE Docs supporting Docker and native Linux package (DEB/RPM) deployment methods.

## Tech Stack

Bash/Shell, Docker, Vagrant (testing), GitHub Actions, jq

## Project Structure

```
docs-install.sh       — Community Edition wrapper (detects OS, routes to installer)
install.sh            — Docker installation script (1033 lines)
install-Debian.sh     — Debian/Ubuntu package installer wrapper
install-RedHat.sh     — RHEL/CentOS/Amazon package installer wrapper
install-Debian/       — Debian-specific scripts
  install-preq.sh     — Prerequisites
  install-app.sh      — App installation (APT)
  check-ports.sh      — Port checks
  tools.sh            — Utility functions
  uninstall.sh        — Uninstall
install-RedHat/       — RedHat-specific scripts
  install-preq.sh     — Prerequisites (standard)
  install-preq-amzn.sh — Prerequisites (Amazon Linux)
  install-app.sh      — App installation (YUM/DNF)
  check-ports.sh      — Port checks
  tools.sh            — Utility functions
  uninstall.sh        — Uninstall
tests/vagrant/        — Vagrant multi-OS test infrastructure
```

## Usage

```bash
# Download and run (Community Edition)
curl -O https://download.onlyoffice.com/docs/docs-install.sh
sudo bash docs-install.sh

# Key flags
--installationtype    community|enterprise|developer
--docsport            <PORT>     (default: 80)
--jwtenabled          true|false
--jwtsecret           <SECRET>
--letsencryptdomain   <DOMAIN>
--letsencryptmail     <EMAIL>
--skiphardwarecheck   true|false
--update              true|false
--uninstall           true|false
```

## Testing

```bash
# Vagrant-based multi-OS testing
cd tests/vagrant
TEST_CASE='--local-install' OS='base-ubuntu2404' vagrant up

# Docker installation test
sudo bash install.sh --skiphardwarecheck true
```

Supported OS: RHEL 8/9, CentOS 8-10 Stream, Amazon Linux 2023, Debian 10-13, Ubuntu 20.04/22.04/24.04/26.04, ARM64

## Key Patterns

- `docs-install.sh` detects OS and routes to Docker or package installer
- `install.sh` handles full Docker lifecycle: pull, configure, run
- `install-Debian/` and `install-RedHat/` mirror each other in structure
- Hardware checks: 2 CPU cores, 4GB RAM, 40GB disk minimum
- Three editions: Community, Enterprise, Developer
- JWT auto-generation if secret not provided
- Let's Encrypt integration for HTTPS

## Review Focus

**Shell**: POSIX compatibility, quoting, `set -e`, error handling, root checks
**Security**: Credential handling, JWT secret generation, SSL/TLS setup
**Portability**: Multi-distro support (Debian/RedHat/Amazon), architecture detection (x86_64/aarch64)
**Docker**: Image pull logic, container configuration, registry auth
**Idempotency**: Install/update/uninstall scripts must be safe to re-run

## Git Workflow

- **Main branch**: `master`
- **Integration branch**: `develop`
- **Branch naming**: `feature/*`, `bugfix/*`, `hotfix/*`, `release/*`
