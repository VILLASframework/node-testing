# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  inputs,
  config,
  self,
  pkgs,
  ...
}:
{
  imports = [ ../common ];

  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 512;
  };

  environment.systemPackages = with pkgs; [
    villas-node

    start-test
  ];
}
