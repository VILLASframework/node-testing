{
  system = "aarch64-linux";
  modules = [
    ../../modules/rpi4
    ../../modules/peer

    ./configuration.nix
  ];
}
