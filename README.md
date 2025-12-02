[![License](https://img.shields.io/badge/License-GNU%20AGPL%20V3-green.svg?style=flat)](https://www.gnu.org/licenses/agpl-3.0.en.html) 
[![Docker Pulls](https://img.shields.io/docker/pulls/onlyoffice/documentserver?logo=docker)](https://hub.docker.com/r/onlyoffice/documentserver)
[![Docker Image Version](https://img.shields.io/docker/v/onlyoffice/documentserver?sort=semver&logo=docker)](https://hub.docker.com/r/onlyoffice/documentserver/tags)
[![GitHub Stars](https://img.shields.io/github/stars/ONLYOFFICE/OneClickInstall-Docs?style=flat&logo=github)](https://github.com/ONLYOFFICE/OneClickInstall-Docs/stargazers)

# ONLYOFFICE Docs - OneClickInstall

A simple self-hosted installer for ONLYOFFICE Docs using Docker or Linux packages.

| 🚀 [Start](#-quick-start) | 🛠 [Flags](#-flags) | 💡 [Examples](#-examples) | 🖥️ [Reqs](#-system-requirements) | ✅ [OS](#-supported-operating-systems) | 📚 [Resources](#-additional-resources) | 📝 [License](#-license) |
|--------------------------|--------------------------------------------|----------------------------|----------------------------------------|----------------------------------------|----------------------------------------|----------------------|

ONLYOFFICE Docs is an open-source office suite that comprises all the tools you need to work with documents, spreadsheets, presentations, PDFs, and PDF forms.

With just one script, you can deploy ONLYOFFICE Docs as a standalone document editing service.

ONLYOFFICE Docs is also a core component of broader collaboration platforms:  
- [**ONLYOFFICE DocSpace**](https://github.com/ONLYOFFICE/DocSpace-buildtools/tree/208163d521daf9c3a32ad34a53b0ca90c7dc9a40/install/OneClickInstall) is a room-based collaboration platform for project or team documents.  
- [**ONLYOFFICE Workspace**](https://github.com/ONLYOFFICE/OneClickInstall-Workspace) is a full-featured solution with document management, mail, calendar, CRM, and more.

To deploy these platforms, use their own dedicated installation scripts.  
This script installs **only the Docs component**, which can be integrated with them or used independently.

Supports all popular formats: **DOCX, XLSX, PPTX, ODT, PDF, CSV, TXT, HTML, EPUB**, and more.  
Works with platforms like **Nextcloud**, **ownCloud**, **Alfresco**, or independently via **Docker** or **Linux packages**.

## 🚀 Quick Start

### 1. Download the installer

Community Edition (default)
```bash
curl -O https://download.onlyoffice.com/docs/docs-install.sh
```

If you want to install a different edition, choose one of the following:
> Enterprise Edition
> ```bash
> curl -O https://download.onlyoffice.com/docs/docs-enterprise-install.sh
> ```

> Developer Edition
> ```bash
> curl -O https://download.onlyoffice.com/docs/docs-developer-install.sh
> ```

### 2. Run the script
The script detects your OS and installs ONLYOFFICE Docs using Docker (or native packages, if selected).  
```bash
sudo bash docs-install.sh
```
> Enterprise Edition
> ```bash
> sudo bash docs-enterprise-install.sh
> ```

> Developer Edition
> ```bash
> sudo bash docs-developer-install.sh
> ```

You'll be prompted to choose the installation method:

- `Y` - Docker (recommended)
- `N` - `.deb` / `.rpm` packages

## 🛠 Flags

All scripts support `--help` to show available flags. View available options with:
```bash
sudo bash docs-install.sh --help
```

### Common flags
> Works for both Docker and package installations

| Flag                  | Value placeholder                          | Default value      | Description                      |
|-----------------------|--------------------------------------------|--------------------|----------------------------------|
| `--installationtype`  | `community\|enterprise\|developer`         | `community`        | Choose edition                   |
| `--update`            | `true` \| `false`                          | `false`            | Update components                |
| `--skiphardwarecheck` | `true` \| `false`                          | `false`            | Skip hardware check              |
| `--jwtenabled`        | `true` \| `false`                          | `true`             | Enable JWT validation            |
| `--jwtheader`         | `<HEADER_NAME>`                            | `AuthorizationJwt` | JWT HTTP header                  |
| `--jwtsecret`         | `<JWT_SECRET>`                             | *(auto-generate)*  | JWT secret key                   |
| `--localscripts`      | `true` \| `false`                          | `false`            | Run local scripts                |
| `--docsport`          | `<PORT>`                                   | `80`               | Docs port                        |

### Docker flags
> Applies only to Docker installation

| Flag                       | Value placeholder            | Default value                | Description                                               |
|----------------------------|------------------------------|------------------------------|-----------------------------------------------------------|
| `--documentimage`          | `<name>` \| `<path>`         | `onlyoffice/documentserver`  | Image name or `.tar.gz` path                              |
| `--documentversion`        | `<VERSION_TAG>`              | *(latest stable)*            | Image tag / version                                       |
| `--installdocs`            | `true` \| `false` \| `pull`  | `true`                       | Install Docs or just pull images                          |
| `--registry`               | `<URL>`                      | -                            | Docker registry URL                                       |
| `--username`               | `<USERNAME>`                 | -                            | Docker registry username                                  |
| `--password`               | `<PASSWORD>`                 | -                            | Docker registry password                                  |
| `--externalserver`         | `true` \| `false`            | `true`                       | Expose Docs externally                                    |
| `--skipversioncheck`       | `true` \| `false`            | `false`                      | Skip version check                                        |
| `--letsencryptdomain`      | `<DOMAIN>`                   | -                            | Domain for Let's Encrypt cert                             |
| `--letsencryptmail`        | `<EMAIL>`                    | -                            | Admin email for Let's Encrypt                             |

## 💡 Examples

Typical usage scenarios with different combinations of flags.  

1. Quick install on non-default port 8080 (default is 80)
```bash
sudo bash docs-install.sh --docsport 8080
```

2. Update in Developer mode, skipping hardware checks
```bash
sudo bash docs-install.sh \
  --update true \
  --installationtype DEVELOPER \
  --skiphardwarecheck true
```

3. Update from a private registry
```bash
sudo bash docs-install.sh \
  --update true \
  --registry https://reg.example.com:5000 \
  --username USER \
  --password PASS
```

4. Install a specific Document Server image & version
```bash
sudo bash docs-install.sh \
  --documentimage onlyoffice/documentserver \
  --documentversion 8.3.3
```

5. Enable JWT with custom header & secret
```bash
sudo bash docs-install.sh \
  --jwtenabled true \
  --jwtheader "AuthorizationJwt" \
  --jwtsecret "SecretString"
```

6. Pull images only (offline prep)
```bash
sudo bash docs-install.sh \
  --installdocs pull \
  --documentimage onlyoffice/documentserver \
  --documentversion 8.0.0
```

7. Install with free HTTPS via Let's Encrypt
```bash
sudo bash docs-install.sh \
  --letsencryptdomain example.com \
  --letsencryptmail admin@example.com
```

## 🖥 System Requirements

| Resource     | Minimum                        |
|--------------|--------------------------------|
| **CPU**      | Dual-core 2 GHz                |
| **RAM**      | 2 GB+ (pkg) / 4 GB+ (Docker)\* |
| **Disk**     | 40 GB+ free                    |
| **Swap**     | ≥ 4 GB                         |
| **Kernel**   | Linux 3.10+ (x86_64)           |

\* Minimum requirements for test environments. For production, 8 GB RAM or more is recommended.

## ✅ Supported Operating Systems

The installation scripts support the following operating systems, which are **regularly tested** as part of our CI/CD pipelines:
<!-- OS-SUPPORT-LIST-START -->
- RHEL 8
- RHEL 9
- CentOS 8 Stream
- CentOS 9 Stream
- CentOS 10 Stream
- Amazon Linux 2023
- Debian 10
- Debian 11
- Debian 12
- Debian 13
- Ubuntu 20.04
- Ubuntu 22.04
- Ubuntu 24.04
<!-- OS-SUPPORT-LIST-END -->

## 📚 Additional Resources

| Resource         | Link                                                             |
|------------------|------------------------------------------------------------------|
| Official website | <https://www.onlyoffice.com/>                                    |
| Code repository  | <https://github.com/ONLYOFFICE/DocumentServer>                   |
| Docker image     | <https://github.com/ONLYOFFICE/Docker-DocumentServer>            |
| Help Center      | <https://helpcenter.onlyoffice.com/docs/installation>            |
| Product page     | <https://www.onlyoffice.com/office-suite.aspx>                   |
| Community Forum  | <https://forum.onlyoffice.com>                                   |
| Stack Overflow   | <https://stackoverflow.com/questions/tagged/onlyoffice>          |

## 📝 License

ONLYOFFICE Docs is distributed under the [**GNU AGPL v3**](https://onlyo.co/38YZGJh) license (for the Community Edition).  
**Enterprise** and **Developer** editions require a valid commercial license. For more details, please contact [sales@onlyoffice.com](mailto:sales@onlyoffice.com).

