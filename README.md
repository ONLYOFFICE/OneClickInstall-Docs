[![License](https://img.shields.io/badge/License-GNU%20AGPL%20V3-green.svg?style=flat)](https://www.gnu.org/licenses/agpl-3.0.en.html) 

## Overview

This repo contains scripts to quickly install ONLYOFFICE Document Server.

ONLYOFFICE Document Server is a free collaborative online office suite comprising viewers and editors for texts, spreadsheets and presentations, fully compatible with Office Open XML formats: .docx, .xlsx, .pptx.

Starting from version 6.0, Document Server is distributed under a new name - ONLYOFFICE Docs. 

ONLYOFFICE Docs can be used as a part of [ONLYOFFICE Workspace](#onlyoffice-workspace) or with third-party sync&share solutions (e.g. Nextcloud, ownCloud, Seafile) to enable collaborative editing within their interface.

It has three editions - [Community, Enterprise, and Developer](#onlyoffice-docs-editions).

`docs-install.sh` is used to install ONLYOFFICE Docs Community Edition.

`docs-enterprise-install.sh` installs ONLYOFFICE Docs Enterprise Edition.

`docs-developer-install.sh` istalls ONLYOFFICE Docs Developer Edition. 

## Functionality

ONLYOFFICE Document Server includes the following editors:

* ONLYOFFICE Document Editor
* ONLYOFFICE Spreadsheet Editor
* ONLYOFFICE Presentation Editor

The editors allow you to create, edit, save and export text, spreadsheet and presentation documents and additionally have the features:

* Collaborative editing
* Hieroglyph support
* Reviewing
* Spell-checking

## Recommended system requirements

* **CPU**: dual-core 2 GHz or higher
* **RAM**: 2 GB or more
* **HDD**: at least 40 GB of free space
* **Swap file**: at least 4 GB
* **OS**: amd64 Linux distribution with kernel version 3.10 or later

## Installing ONLYOFFICE Docs using the provided script

**STEP 1**: Download ONLYOFFICE Docs Community Edition Docker script file:

```bash
wget http://download.onlyoffice.com/docs/docs-install.sh
```

**STEP 2**: Install ONLYOFFICE Docs executing the following command:

```bash
bash docs-install.sh
```

## Project information

Official website: [https://www.onlyoffice.com](https://www.onlyoffice.com/?utm_source=github&utm_medium=cpc&utm_campaign=GitHubDS)

Code repository: [https://github.com/ONLYOFFICE/DocumentServer](https://github.com/ONLYOFFICE/DocumentServer "https://github.com/ONLYOFFICE/DocumentServer")

Docker Image: [https://github.com/ONLYOFFICE/Docker-DocumentServer](https://github.com/ONLYOFFICE/Docker-DocumentServer "https://github.com/ONLYOFFICE/Docker-DocumentServer")

License: [GNU AGPL v3.0](https://onlyo.co/38YZGJh)

ONLYOFFICE Docs on official website: [http://www.onlyoffice.com/office-suite.aspx](http://www.onlyoffice.com/office-suite.aspx?utm_source=github&utm_medium=cpc&utm_campaign=GitHubDS)

## User feedback and support

If you have any problems with or questions about [ONLYOFFICE Document Server][2], please visit our official forum to find answers to your questions: [dev.onlyoffice.org][1] or you can ask and answer ONLYOFFICE development questions on [Stack Overflow][3].

  [1]: http://dev.onlyoffice.org
  [2]: https://github.com/ONLYOFFICE/DocumentServer
  [3]: http://stackoverflow.com/questions/tagged/onlyoffice
