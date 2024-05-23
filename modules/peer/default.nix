{
  inputs,
  config,
  self,
  pkgs,
  ...
}:
let
  start = pkgs.writeShellApplication {
    name = "start";
    checkPhase = "true";
    text = ''
      sudo villas-node /etc/villas-node-$1.json
    '';
  };
in
{
  imports = [
    inputs.villas-node.nixosModules.default

    ../common
  ];

  services = {
    # villas.node = {
    #   enable = false;
    #   # config = {};
    # };
  };

  environment.systemPackages = [
    config.services.villas.node.package
    start
  ];
}
