#!/bin/bash
echo "Copying configurations"
cp .config/* ~/.config/ -r
cp .default-python-packages ~
if [ -z "$(which nh)" ]; then
    sudo cp *.nix /etc/nixos/
    sudo nixos-rebuild switch --show-trace
    cp /etc/nixos/flake.lock .
else
    sudo nix-channel --update
    sudo nix flake update
    nh os switch . -- --show-trace
fi
