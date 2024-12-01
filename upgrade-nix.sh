if [ -z "$(which nh)" ]; then
    cd /etc/nixos
    sudo nix-channel --update
    sudo nix flake update
    sudo nixos-rebuild --upgrade switch
else
    sudo nix-channel --update
    sudo nix flake update
    sudo nh os switch .
fi