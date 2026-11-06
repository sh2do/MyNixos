# Patched hp-wmi from omen-fan-control. Adds the multicolor keyboard
# (hp::kbd_zoned_backlight-*, hp::kbd_backlight) and lightbar LED nodes that
# omen-rgb needs. Installed under updates/ so it shadows the in-tree hp-wmi.
{ lib, stdenv, buildPackages, fetchFromGitHub, kernel, kernelModuleMakeFlags }:

stdenv.mkDerivation {
  pname = "hp-wmi-omen";
  version = "unstable-2026-10-26-${kernel.version}";

  src = fetchFromGitHub {
    owner = "arfelious";
    repo = "omen-fan-control";
    rev = "d46f3996d4511a3ae7dae090a5355cba75ca7197";
    hash = "sha256-C9hEU/Z9nulLlgNZYW84TSCfS0R6nQhRYrR7si3XIEk=";
  };

  sourceRoot = "source/src/omen_fan_control/data/driver/hp-wmi-omen";

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [ "pic" "format" ];

  makeFlags = kernelModuleMakeFlags ++ [
    "KVERSION=${kernel.modDirVersion}"
    "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  buildFlags = [ "all" ];

  installPhase = ''
    runHook preInstall
    install -Dm644 hp-wmi.ko $out/lib/modules/${kernel.modDirVersion}/updates/hp-wmi.ko
    # Sign like modules_install would; the NixOS module aggregator needs the .cer
    ${lib.getExe buildPackages.kmodigest} $out/lib/modules/${kernel.modDirVersion}/updates/hp-wmi.ko
    runHook postInstall
  '';

  meta = {
    description = "HP WMI driver with Omen RGB keyboard and lightbar support";
    homepage = "https://github.com/arfelious/omen-fan-control";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
