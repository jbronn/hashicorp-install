# hashicorp-install

This is a shell script for downloading, verifying (with GPG), and installing
the following Hashicorp packages on Linux:

* [Consul](https://www.consul.io)
* [Consul ESM](https://github.com/hashicorp/consul-esm)
* [Packer](https://www.packer.io)
* [Terraform](https://www.terraform.io)
* [Vault](https://www.vaultproject.io)

## Requirements

Use of this script requires:

* Linux
* `gpgv`
* `unzip`
* `curl` or `wget`
* `sudo` or administrative access

## Usage

To install Packer:

```
./hashicorp-install.sh packer
```

To install a specific version of Packer, set the `PACKAGE_VERSION` variable to the desired version, e.g. for 1.4.4:

```
PACKAGE_VERSION=1.4.4 ./hashicorp-install.sh packer
```
