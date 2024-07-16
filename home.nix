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
            fira
            fira-code
            fira-code-nerdfont
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

            caddy
            jq
            htmlq
            fzf
            gleam
            erlang
            terraform
            nodejs
            # nodePackages.pnpm
            corepack

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
            difftastic.enable = true;
            signing = {
                signByDefault = true;
                key = "/home/dan/.ssh/id_ed25519";
            };
            extraConfig = {
                pull.rebase = false;
                gpg.format = "ssh";
            };
        };
        gitui.enable = true;
        btop.enable = true;
        bat.enable = true;
        lsd.enable = true;
        fastfetch.enable = true;
        direnv.enable = true;
        direnv.nix-direnv.enable = true;
        firefox.enable = true;
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
