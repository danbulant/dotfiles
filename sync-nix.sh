echo "Copying configurations"
cp .config/* ~/.config/ -r
sudo cp configuration.nix /etc/nixos/configuration.nix
sudo cp home.nix /etc/nixos/home.nix
sudo nixos-rebuild switch