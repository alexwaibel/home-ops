# Template for deploying k3s backed by Flux

Highly opinionated repository for deploying my home infrastructure.

## Overview

- [Introduction](https://github.com/alexwaibel/home-ops#-introduction)
- [Prerequisites](https://github.com/alexwaibel/home-ops#-prerequisites)
- [Repository structure](https://github.com/alexwaibel/home-ops#-repository-structure)
- [Lets go!](https://github.com/alexwaibel/home-ops#-lets-go)

## 👋 Introduction

TODO

## 📝 Prerequisites

### 💻 Systems

- A server with [Proxmox VE](https://www.proxmox.com/en/downloads) installed.
  - Must be configured with a sufficiently large ZFS pool.

### 🔧 Workstation Tools

📍 Install the **most recent version** of the CLI tools below. If you are **having trouble with future steps**, it is very likely you don't have the most recent version of these CLI tools, **!especially sops AND yq!**.

1. Install [brew](https://brew.sh/).

2. Install [go-task](https://github.com/go-task/task) via Brew

    ```sh
    brew install go-task/tap/go-task
    ```

3. Install workstation dependencies via Brew

    ```sh
    task init
    ```

### ⚠️ pre-commit

It is advisable to install [pre-commit](https://pre-commit.com/) and the pre-commit hooks that come with this repository.

1. Enable Pre-Commit

    ```sh
    task precommit:init
    ```

2. Update Pre-Commit, though it will occasionally make mistakes, so verify its results.

    ```sh
    task precommit:update
    ```

## 🚀 Lets go

📍 **All of the below commands** are run on your **local** workstation.

### 🔐 Setting up Age

📍 Here we will create a Age Private and Public key. Using [SOPS](https://github.com/mozilla/sops) with [Age](https://github.com/FiloSottile/age) allows us to encrypt secrets and use them in Ansible and Terraform.

1. Create a Age Private / Public Key

    ```sh
    age-keygen -o age.agekey
    ```

2. Set up the directory for the Age key and move the Age file to it

    ```sh
    mkdir -p ~/.config/sops/age
    mv age.agekey ~/.config/sops/age/keys.txt
    ```

3. Export the `SOPS_AGE_KEY_FILE` variable in your `bashrc`, `zshrc` or `config.fish` and source it, e.g.

    ```sh
    export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
    source ~/.bashrc
    ```

4. Replace the public keys in `.sops.yaml` (they start with 'age').

### ⚡ Preparing Debian VM with Packer and Terraform

1. Double check the configuration in [.envrc](.envrc) and ensure [direnv](https://direnv.net/) is configured.

2. Set your secrets. Copy `.secrets.example` to `.secrets` and fill in your values.
   NOTE: Packer uses http server so local workstation must be reachable over network by server. WSL2 has issues with this.
   https://github.com/microsoft/WSL/issues/4150#issuecomment-504209723


2. Provision cloudinit template
Run `task packer:all`

3. Provision NAS VM
Run:
`task terraform: init`
`task terraform: plan`
`task terraform: apply`
