{ nix-gaming, nixpkgs-unstable, suyu, hyprland-plugins, hyprland, ... }:
{ pkgs, inputs, ...}:
let

  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
  };

in
{
    home = {
        stateVersion = "24.05";

        packages = with pkgs; [
#            davinci-resolve # builds spidermonkey for some reason bruh
	        anki-bin
            xournalpp
            simple-scan
            dotnet-sdk
            # acpilight
            #kdePackages.plasma-workspace
            godot_4
            rar
            wootility
            surrealdb
            #surrealist
            pico-sdk
            elf2uf2-rs
            # nix-gaming.packages.${pkgs.system}.osu-lazer-bin
            obsidian
            betaflight-configurator
            home-manager
            glxinfo
            pciutils
            nix-top
            grc
            onefetch
            inter
            fira
            fira-code
            fira-code-nerdfont
            iosevka
            kitty
            rofi-wayland
            discord
            vesktop
            spotify
            spicetify-cli
            meslo-lgs-nf
            waybar
            chromium
            # firefox
            dunst
            sccache
            swaybg
            activitywatch
            networkmanagerapplet
            kubectl
            duf
            dust
            jetbrains.rust-rover
            jetbrains.webstorm
            jetbrains.phpstorm
            jetbrains.pycharm-community-bin
            jetbrains.clion
            jetbrains.goland
            jetbrains.datagrip
            jetbrains.rider
            datovka
            nwg-displays
            wireguard-tools
            mongodb-compass
            hashcat
            tldr
            dunst
            grim
            slurp
            wl-clipboard
            nextcloud-client
            kdePackages.plasma-workspace
            kdePackages.partitionmanager
            kdePackages.filelight
            kdePackages.kate
            kdePackages.ksystemstats
            kdePackages.kinfocenter
            kdePackages.kirigami-addons
            kdePackages.ark
            #xorg.xbacklight
            cachix
            playerctl
            libcanberra-gtk3 # sound events
            qt6ct
            nil # nix language server
            nix-output-monitor
            expect
            nh
            
            udev-block-notify

            appimage-run

            heroic
            heaptrack
            cinny-desktop
            gping
            # redisinsight
            valgrind
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
            ansible
            aria2
            qbittorrent
            audacity
            bettercap
            # bitwarden
            duperemove
            ffmpeg
            flameshot
            ripgrep
            iotop
            nethogs
            john
            iperf
            mold
            nheko
            quickemu
            qemu
            # uwufetch
            # vagrant
            socat
            websocat
            whois
            wifite2
            dig
            httpie
            inxi
            numbat
            wireshark
            nixfmt-rfc-style
            qpwgraph

            nixpkgs-unstable.legacyPackages.${system}.zed-editor
            # suyu.packages.${pkgs.stdenv.hostPlatform.system}.suyu

            android-tools
            hyperfine
            scc
            aircrack-ng
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
            openvpn
            ghostty

            mdbook
            nix-tree
            nix-du
            graphviz

            blender
            warpinator

            awatcher
            tigervnc

            oh-my-posh

            libva-utils

            # (python312.withPackages (ps: with ps; [ 
            #     pyquery
            #     pygobject3
            # ]))
            # pipx
            # gobject-introspection

            crate2nix
        ];
    };
    services.lorri.enable = true;
    wayland.windowManager.hyprland = {
#        enable = true;
        # package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        # portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        # plugins = [
        #     hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo
        #     hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprtrails
        # ];
    };
    fonts.fontconfig = {
        enable = true;
        defaultFonts = {
            emoji = ["Noto Color Emoji"];
            monospace = ["Iosevka" "Iosevka NF" "FiraCode Nerd Font Mono"];
            sansSerif = ["Inter"];
            serif = ["Noto Serif"];
        };
    };
    programs = {
        fish = {
            enable = true;
            shellInit = ''
                source ~/.config/fish/config-old.fish

            '';
            # set -x PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines}/bin/schema-engine"
            # set -x PRISMA_QUERY_ENGINE_BINARY "${prisma-engines}/bin/query-engine"
            # set -x PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines}/lib/libquery_engine.node"
            # set -x PRISMA_FMT_BINARY "${prisma-engines}/bin/prisma-fmt"
            plugins = with pkgs.fishPlugins; [
                { name = "grc"; src = grc.src; }
                { name = "tide"; src = tide.src; }
            ];
        };
        nushell = {
            enable = true;

            # unstable, perhaps 25.05
            # plugins = with pkgs.nushellPlugins; [
            #     query
            #     skim
            #     net
            #     highlight
            #     gstat
            #     formats
            #     dbus
            #     units
            # ];
            # configFile.source = ./.config/nushell/base-config.nu;
            configFile.text = ''use base-config.nu'';
            shellAliases = {
                ns = "nix-shell --run nu";
                nsp = "nix-shell --run nu -p";
                l = "lsd -la";
            };
        };
        vscode = {
            enable = true;
            # package = nixpkgs-unstable.packages.${pkgs.system}.vscode;
            # package = unstable.pkgs.vscode;
            extensions = with pkgs.vscode-extensions; [

            ];
        };
        # nixvim = {
        #     enable = true;
        #     # colorscheme = "hanekawa_tsubasa";w
        #     colorschemes.onedark.enable = true;
        #     plugins = {
        #         wakatime.enable = true;
        #         cmp = {
        #             autoEnableSources = true;
        #             enable = true;
        #             settings.sources = [
        #                 { name = "fish"; }
        #                 { name = "nvim_lsp"; }
        #                 { name = "path"; }
        #                 { name = "buffer"; }
        #                 # { name = "treesitter"; }
        #             ];
        #         };
        #     };
        # };
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
                pull.ff = "only";
                gpg.format = "ssh";
                commit.gpgsign = true;
                gpg.ssh.allowedSignersFile = "/home/dan/allowed_signers";
            };
        };
        gitui.enable = true;
        btop.enable = true;
        bat.enable = true;
        lsd.enable = true;
        fastfetch.enable = true;
        direnv.enable = true;
        direnv.nix-direnv.enable = true;
        # firefox.enable = true;
    };
    services.kdeconnect.enable = true;
    services.kdeconnect.indicator = true;
    services.blueman-applet.enable = true;
    services.mpris-proxy.enable = true;
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
