#!/bin/bash
#sh fast-copy.sh
if [ -z "$(which nh)" ]; then
    sudo cp *.nix /etc/nixos/
    sudo nixos-rebuild switch --show-trace
    cp /etc/nixos/flake.lock .
else
#    sudo nix-channel --update
#    sudo nix flake update
    nh os switch . -- --show-trace --option extra-substituters https://install.determinate.systems --option extra-trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=
  
fi
