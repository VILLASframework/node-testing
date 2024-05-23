{ pkgs, lib, ... }:
let
  signalingServer = pkgs.buildGo122Module {
    pname = "villas-signaling-server";
    version = "master";
    src = pkgs.fetchFromGitHub {
      owner = "VILLASframework";
      repo = "signaling";
      rev = "fab85e4b2722eb60f7167866b5aff172d9173150";
      hash = "sha256-FYE+49IjSHPTZpcetr0S/9mpGttP1N0spbahAUv+FUg=";
    };
    vendorHash = "sha256-hDAk2W8P3nc6USlxmHpJJtp8K7IMMLLBuGQ/w/L1V30=";
    meta = with lib; {
      mainProgram = "server";
      license = licenses.asl20;
    };
  };
in
{
  systemd.services = {
    villas-signaling-server = {
      description = "VILLASnode WebRTC signaling server";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${signalingServer}/bin/server";
      };
    };
  };
}
