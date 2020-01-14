# hashicorp-install

This is a shell script for downloading, verifying (with GPG), and installing
the `consul`, `packer`, and `terrform` Hashicorp packages.

## Requirements

Usage of this script requires:

* Linux
* `gpgv`
* `unzip`
* `sudo` or administrative access

## Usage

To install [Packer](https://www.packer.io):

```
./hashicorp-install.sh packer
```

To install a specific version of Packer, set the `PACKAGE_VERSION` variable to the desired version, e.g. for 1.4.4:

```
PACKAGE_VERSION=1.4.4 ./hashicorp-install.sh packer
```
