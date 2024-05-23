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
    ];
    enableDebugInfo = true;
  };

  systemd.coredump.enable = true;

  system.stateVersion = "24.05";
}
