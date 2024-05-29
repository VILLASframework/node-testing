# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ self, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  services.mongodb.enable = true;

  systemd.services = {
    fiware-orion = {
      description = "FIWARE Orion Context Broker";
      wantedBy = [ "multi-user.target" ];
      requires = [ "mongodb.service" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.fiware-orion}/bin/contextBroker -fg -dbhost localhost:27017";
      };
    };
  };
}
