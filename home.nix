{ pkgs, ...}: 
let
  unstable-pkgs = import <nixos-unstable> {};
in
{
    home = {
        stateVersion = "24.05";

        packages = with pkgs; [
            grc
            onefetch
            fira-code
            kitty
            nushell
            rofi-wayland
            rustup 
            discord
            spotify
            spicetify-cli
            meslo-lgs-nf
            waybar
            chromium
            firefox
            dunst
            sccache
            discord
            spotify
            spicetify-cli
            meslo-lgs-nf
            blueman
            swaybg
            activitywatch
            networkmanagerapplet
            kubectl
            duf
            dust
            jetbrains.rust-rover
            jetbrains.webstorm
            mongodb-compass
            hashcat
            tldr
            dunst
            grim
            slurp
            wl-clipboard
            nextcloud-client
            kdePackages.partitionmanager
            kdePackages.filelight
            kdePackages.kate
            xorg.xbacklight
            cachix
            playerctl
            libcanberra-gtk3 # sound events
            qt6ct
            nil # nix language server

            jq
            htmlq
            fzf

            strace
            ghidra
            ffuf
            sqlmap
            nmap
            rustscan
            thc-hydra
            file
            binwalk
            p7zip
            foremost
            gdb
            feroxbuster
            python312Packages.pypykatz
            screen

            (python312.withPackages (ps: with ps; [ 
                pyquery
                pygobject3
            ]))
            pipx
            gobject-introspection

            unstable-pkgs.prisma-engines
            openssl
            gcc
            # required by mise plugins
            automake
            autoconf
            ncurses
            pkg-config
            gnumake
        ];
    };
    programs = {
        fish = {
            enable = true;
            interactiveShellInit = ''
                set fish_greeting # Disable greeting
            '';
            shellInit = with unstable-pkgs; ''
                source ~/.config/fish/config-old.fish

                set -x PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines}/bin/schema-engine"
                set -x PRISMA_QUERY_ENGINE_BINARY "${prisma-engines}/bin/query-engine"
                set -x PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines}/lib/libquery_engine.node"
                set -x PRISMA_FMT_BINARY "${prisma-engines}/bin/prisma-fmt"
            '';
            plugins = with pkgs.fishPlugins; [
                { name = "grc"; src = grc.src; }
                { name = "tide"; src = tide.src; }
            ];
        };
        vscode = {
            enable = true;
            extensions = with pkgs.vscode-extensions; [

            ];
        };
        git = {
            enable = true;
            userName  = "Daniel Bulant";
            userEmail = "danbulant@gmail.com";
        };
        btop.enable = true;
        bat.enable = true;
        lsd.enable = true;
        fastfetch.enable = true;
        mise = {
            enable = true;
            globalConfig = {
                tools = {
                    usage = "latest";
                    node = "latest";
                    python = "3";
                    terraform = "latest";
                    erlang = "latest";
                    gleam = "latest";
                    "pipx:pypykats" = "latest";
                    "pipx:pyquery" = "latest";
                    "pipx:pygobject" = "latest";
                    "npm:pnpm" = "latest";
                };
                plugins = {
                    gleam = "https://github.com/asdf-community/asdf-gleam.git";
                };
                env = {
                    MISE_NODE_COMPILE = "false";
                    MISE_PYTHON_COMPILE = "false";
                    MISE_NODE_COREPACK = "true";
                };
            };
            settings = {
                python_compile = false;
                python_precompiled_os = "unknown-linux-musl";
            };
        };
        direnv.enable = true;
        direnv.nix-direnv.enable = true;
        # firefox.enable = true;
    };
    services.kdeconnect.enable = true;
    services.kdeconnect.indicator = true;
    xdg.mimeApps = {
        enable = true;

        defaultApplications = {
            "text/html" = "firefox.desktop";
            "x-scheme-handler/http" = "firefox.desktop";
            "x-scheme-handler/https" = "firefox.desktop";
            "x-scheme-handler/about" = "firefox.desktop";
            "x-scheme-handler/unknown" = "firefox.desktop";
        };
    };
}