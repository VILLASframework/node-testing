{
  system = "aarch64-linux";
  modules = [
    ../../modules/server

    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
