{
  # Link individual files instead of whole directories.  This leaves room for
  # applications such as DMS to generate additional files next to the managed
  # Hyprland and Kitty configuration.
  xdg.configFile = {
    "activitywatch" = {
      source = ../../.config/activitywatch;
      recursive = true;
    };
    "carapace" = {
      source = ../../.config/carapace;
      recursive = true;
    };
    "fish" = {
      source = ../../.config/fish;
      recursive = true;
    };
    "hypr" = {
      source = ../../.config/hypr;
      recursive = true;
    };
    "kitty" = {
      source = ../../.config/kitty;
      recursive = true;
    };
    "mpv" = {
      source = ../../.config/mpv;
      recursive = true;
    };
    "nano" = {
      source = ../../.config/nano;
      recursive = true;
    };
    "nushell" = {
      source = ../../.config/nushell;
      recursive = true;
    };
    "oh-my-posh/config.toml".source = ../../.config/oh-my-posh/config.toml;
    "opencode" = {
      source = ../../.config/opencode;
      recursive = true;
    };
    "rofi" = {
      source = ../../.config/rofi;
      recursive = true;
    };
    "vivaldi-stable.conf".source = ../../.config/vivaldi-stable.conf;
    "zed" = {
      source = ../../.config/zed;
      recursive = true;
    };
  };

  home.file = {
    ".default-python-packages".source = ../../.default-python-packages;
    ".oh-my-posh.nu".source = ../../.oh-my-posh.nu;
    ".vscode/settings.json".source = ../../.vscode/settings.json;
  };
}
