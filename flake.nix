{
  description = "Patched btusb driver for fake CSR8510 A10 / Barrot Bluetooth USB dongles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = { config, ... }: {
      boot.extraModulePackages = [
        (config.boot.kernelPackages.callPackage ./default.nix { })
      ];
    };
  };
}
