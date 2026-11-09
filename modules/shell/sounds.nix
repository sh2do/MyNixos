# The shells' sounds: a water drop (notification), a low caw (critical) and a
# ripple tick (volume), synthesised with sox at build time, so nothing
# binary is committed. Sound.qml runs `rice-sound NAME` for each one; the
# decision of whether to play is sound.js's (tests/sound-test.js).
{ pkgs, ... }:

let
  sounds = pkgs.runCommand "rice-sounds" { nativeBuildInputs = [ pkgs.sox ]; } ''
    mkdir $out
    cd $out
    sox -n -r 44100 -c 1 drop.wav synth 0.22 sine 900:1500 fade q 0.005 0.22 0.18 gain -14
    sox -n -r 44100 -c 1 caw.wav synth 0.35 saw 140:95 lowpass 700 tremolo 22 40 fade q 0.03 0.35 0.2 gain -12
    sox -n -r 44100 -c 1 tick.wav synth 0.08 sine 1800:1200 fade q 0.002 0.08 0.06 gain -18
  '';

  # pw-play comes from the PATH (the system's pipewire), at a modest volume.
  rice-sound = pkgs.writeShellScriptBin "rice-sound" ''
    exec pw-play --volume=0.5 ${sounds}/"$1".wav
  '';
in
{
  home.packages = [ rice-sound ];
}
