echo "Copying configurations"
cp .config/* ~/.config/ -r
cp .default-python-packages ~
sudo cp *.nix /etc/nixos/
sudo nixos-rebuild switch