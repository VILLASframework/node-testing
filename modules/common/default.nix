# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ pkgs, ... }:
{
  networking = {
    useNetworkd = true;
    firewall.enable = false;
  };

  users = {
    users.villas = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      initialPassword = "villas";
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "villas" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  programs.direnv.enable = true;

  services = {
    openssh = {
      enable = true;
    };
  };

  environment = {
    systemPackages = with pkgs; [
      jq
      gdb
      tcpdump
      killall
      nftables
      dig
    ];
    enableDebugInfo = true;
  };

  systemd.coredump.enable = false;

  system.stateVersion = "24.05";
}
