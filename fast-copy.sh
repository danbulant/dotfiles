
echo "Copying configurations"
cp .config/* ~/.config/ -r
echo fixing quickshell copy
rm -r ~/.config/quickshell
cp dots-hyprland/.config/quickshell ~/.config/quickshell -r
cp .default-python-packages ~
cp .oh-my-posh.nu ~