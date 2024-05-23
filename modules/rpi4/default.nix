{
  pkgs,
  inputs,
  modulesPath,
  lib,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4

    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")

    ./hardware-configuration.nix
  ];

  hardware = {
    raspberry-pi."4" = {
      apply-overlays-dtmerge.enable = true;
    };
    deviceTree = {
      enable = true;
      filter = lib.mkForce "*rpi-4-*.dtb";
    };
  };

  boot.supportedFilesystems = lib.mkForce [
    "vfat"
    "ext4"
  ];

  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
  ];

  # Workaround: https://github.com/NixOS/nixpkgs/issues/154163
  # modprobe: FATAL: Module sun4i-drm not found in directory
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
}
