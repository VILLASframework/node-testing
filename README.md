# VILLASnode WebRTC Testing

This Git repository contains the code used for producing the results of the following paper:

- TODO

The benchmark results presented in the paper have been gathered in a reproducible manner using a declarative description of the test setup using the [Nix](https://nixos.org/) language, package-manager and NixOS operating system.
This description covers the entire configuration of virtual machines which compose the test setup.
But it also extends to scripts for executing the tests, post-processing results as well as generating figures..

Nix has been chosen as it allows other researchers to verify the results presented in the paper
using a setup which bit-to-bit identical. This includes the software versions, operating system
and network configuration as as methods for for analyzing the results.

## Prerequisites

- A reasonable modern Linux machine and OS
  - x86_64 architecture
- [The Nix package manager](https://nixos.org/download/)

### The authors setup

- Hardware:
  - **CPU:** AMD Ryzen 9 7950X 16-Core Processor
  - **RAM:** Kingston, 64 GiB DDR 5, 4800 MT/s
- Software:
  - NixOS Unstable (rev [126f49a01de5b7e35a43fd43f891ecf6d3a51459](https://github.com/NixOS/nixpkgs/commit/126f49a01de5b7e35a43fd43f891ecf6d3a51459))
  - Nix [v2.18.2](https://github.com/NixOS/nix/releases/2.18.2)

## Usage

### Run tests

```shell
nix run
```

or with [direnv](https://direnv.net/):

```shell
echo "use flake" > .envrc
direnv allow

start-vms
```

### Connect to VMs

```shell
ssh-vms
```

### Produce figures

## License

This project is released under the terms of the [Apache 2.0 license](LICENSE).

- SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
- SPDX-License-Identifier: Apache-2.0

## Author

- Steffen Vogel <steffen.vogel@opal-rt.com>
