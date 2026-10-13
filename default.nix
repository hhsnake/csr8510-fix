{ lib, stdenv, kernel }:

stdenv.mkDerivation rec {
  pname = "csr8510-fix";
  version = "1.0.0";

  src = lib.cleanSource ./.;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  preBuild = ''
    ./select-variant.sh "${kernel.modDirVersion}"
  '';

  makeFlags = kernel.makeFlags ++ [
    "KERNEL_VERSION=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(PWD)"
  ];

  buildFlags = [ "modules" ];

  installPhase = ''
    runHook preInstall
    install -D btusb.ko -t "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/bluetooth/"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Patched btusb driver for fake CSR8510 A10 / Barrot Bluetooth USB dongles";
    homepage = "https://github.com/hhsnake/csr8510-fix";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
