# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ config, lib, ... }:
{
  imports = [
    ./mqtt-broker.nix
    ./ngsi-broker.nix
    ./webrtc-turn-relay.nix
    ./webrtc-signaling.nix
    ./websocket-relay.nix

    ../common
  ];

  networking = {
    hostName = "server";
  };
}
