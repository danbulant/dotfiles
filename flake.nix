{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    home-manager.url = "github:nix-community/home-manager"; # /release-24.11
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # kwin-effects-forceblur.url = "https://gist.githubusercontent.com/taj-ny/c1abdde710f33e34dc39dc53a5dc2c09/raw/7078265012c37b6f6bc397e9a7893bc6004e7b6c/kwin-effects-forceblur.nix";
  };

  outputs = { nixpkgs, ... }@attrs: {
    nixosConfigurations.lenovo-nix = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = with attrs; [
        home-manager.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}