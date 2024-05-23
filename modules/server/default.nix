{ lib, ... }:
{
  imports = [
    ./broker.nix
    ./relay.nix
    ./signaling.nix

    ../common
  ];

  networking = {
    hostName = "server";
  };
}
