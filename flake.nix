# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  description = "Flake for NEIS 2024 paper";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";

    villas-node = {
      #   url = "github:VILLASframework/node/neis-fixes";
      url = "path:/home/stv0g/workspace/villas/node";
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
        testSpecs = pkgs.callPackage ./tests.nix { };
        testSpecsJSON =
          pkgs.runCommand "test-specs.json"
            { jsonFile = pkgs.writeText "test-specs.json" (builtins.toJSON testSpecs); }
            ''
              # Pretty print
              ${pkgs.jq}/bin/jq . < $jsonFile > $out
            '';

        overlays = [
          (final: prev: {
            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (pythonFinal: pythonPrev: { qemu-qmp = pythonFinal.callPackage ./packages/qemu-qmp.nix { }; })
            ];

            fiware-orion = prev.callPackage ./packages/fiware-orion.nix { };
            mongoc = prev.callPackage ./packages/mongoc.nix { };

            start-vms = prev.writeShellApplication {
              name = "start-vms";
              runtimeInputs = [ test.config.driver ];
              text = ''
                testSpecs=${testSpecsJSON} \
                nixos-test-driver "$@"
              '';
            };

            start-test = prev.writeShellApplication {
              name = "start";
              checkPhase = "true";
              text = "sudo ${final.villas-node}/bin/villas-node /etc/villas-node-$1.json";
            };

            ssh-vms = prev.writeShellApplication {
              name = "ssh-vms";
              checkPhase = "true";
              runtimeInputs = with prev; [
                tmux
                sshpass
                openssh
              ];
              text = ''
                SESSION="ssh-vms"
                SSH="sshpass -p villas ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o User=villas"

                tmux kill-session -t $SESSION || true

                tmux \
                    new-session -d -s $SESSION  "$SSH -p 2000 localhost" \; \
                    split-window -h -t $SESSION "$SSH -p 2100 localhost" \; \
                    split-window -h -t $SESSION "$SSH -p 2101 localhost" \; \
                    attach-session -t $SESSION:0
              '';
            };
          })
          inputs.villas-node.overlays.default
        ];

        pkgs = import nixpkgs {
          inherit system;
          inherit overlays;
          config.allowUnfree = true;
        };

        nixos-lib = import (nixpkgs + "/nixos/lib") { };

        test = nixos-lib.evalTest {
          name = "benchmark";

          hostPkgs = pkgs;

          extraPythonPackages =
            p: with p; [
              qemu-qmp
              pydantic
              matplotlib
              pandas
            ];

          node.specialArgs = {
            inherit self;
            inherit inputs;
            inherit pkgs;
          };

          defaults =
            { config, ... }:
            {
              documentation.enable = false;

              virtualisation = {
                sharedDirectories = {
                  home = {
                    source = "/home/stv0g";
                    target = "/home/stv0g";
                  };
                };

                qemu = {
                  guestAgent.enable = true;
                  options = [
                    # Extra QMP socket for test.py
                    "-qmp unix:/tmp/vm-state-${config.system.name}/qmp2,server=on,wait=off"

                    # QEmu Guest Agent socket
                    "-chardev socket,path=/tmp/vm-state-${config.system.name}/qga,server=on,wait=off,id=qga0"
                    "-device virtio-serial"
                    "-device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
                  ];
                };

                memorySize = 4096;
                cores = 4;
                writableStore = true;
              };

              systemd.services.qemu-guest-agent = {
                serviceConfig = {
                  LogFilterPatterns = "~guest-exec-status called";
                };
              };
            };

          nodes = {
            server = import ./modules/server;
            peer-left = import ./modules/peer-left;
            peer-right = import ./modules/peer-right;
          };

          testScript = builtins.readFile ./tests.py;
          skipTypeCheck = true;
        };
      in
      {
        packages = with pkgs; {
          default = start-vms;

          specs = testSpecsJSON;
        };

        devShell = pkgs.mkShell {
          buildInputs = [ (pkgs.callPackage "${nixpkgs}/nixos/lib/test-driver" { }) ];
          packages =
            with pkgs;
            [
              ssh-vms
              start-vms
              reuse
            ]
            ++ test.config.extraPythonPackages pkgs.python3Packages;
        };
      }
    ));
}
