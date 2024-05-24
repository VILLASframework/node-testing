{
  description = "Flake for NEIS 2024 paper";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";

    villas-node = {
      url = "github:VILLASframework/node/neis-fixes";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      ...
    }@inputs:
    {
      nixosConfigurations =
        let
          nixosSystem =
            path:
            nixpkgs.lib.nixosSystem (
              {
                specialArgs = {
                  inherit inputs;
                  inherit self;
                };
              }
              // (import ./configs/server)
            );
        in
        {
          server = nixosSystem ./configs/server;
          rpi-peer = nixosSystem ./configs/rpi-peer;
        };

      images = {
        peer = self.nixosConfigurations.peer.config.system.build.sdImage;
      };
    }
    // (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        nixos-lib = import (nixpkgs + "/nixos/lib") { };

        nixosTest =
          path:
          (nixos-lib.runTest (
            pkgs.callPackage path {
              inherit self;
              inherit inputs;
            }
          ));

        benchmark = nixos-lib.evalTest {
          name = "benchmark";

          hostPkgs = pkgs;

          defaults.documentation.enable = false;
          node.specialArgs = {
            inherit self;
            inherit inputs;
          };

          defaults = {
            virtualisation = {
              sharedDirectories = {
                home = {
                  source = "/home/stv0g";
                  target = "/home/stv0g";
                };
              };
              writableStore = true;
            };
          };

          nodes = {
            server = import ./modules/server;
            peer-left = import ./modules/peer-left;
            peer-right = import ./modules/peer-right;
          };

          testScript = builtins.readFile ./test.py;
        };
      in
      {
        packages = rec {
          default = start-vms;

          start-vms = pkgs.writeShellApplication {
            name = "start-vms";
            runtimeInputs = [ benchmark.config.driver ];
            text = ''nixos-test-driver "$@"'';
          };

          ssh-vms = pkgs.writeShellApplication {
            name = "ssh-vms";
            checkPhase = "true";
            runtimeInputs = with pkgs; [
              tmux
              sshpass
              openssh
            ];
            text = ''
              SESSION="ssh-vms"
              SSH="sshpass -p villas ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o User=villas"

              # tmux kill-session -t $SESSION

              tmux \
                  new-session -d -s $SESSION  "$SSH -p 2000 localhost" \; \
                  split-window -h -t $SESSION "$SSH -p 2100 localhost" \; \
                  split-window -h -t $SESSION "$SSH -p 2101 localhost" \; \
                  attach-session -t $SESSION:0
            '';
          };
        };

        devShell = pkgs.mkShell {
          packages = with self.packages.${system}; [
            ssh-vms
            start-vms
            pkgs.reuse
          ];
        };
      }
    ));
}
