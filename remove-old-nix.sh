# sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 30d
# nix-env --delete-generations 30d
# nix-collect-garbage
nh clean all -k 5 -K 20d
