{ pkgs, ...}: {
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
            python3

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
        ];
    };
    programs = {
        fish = {
            enable = true;
            interactiveShellInit = ''
                set fish_greeting # Disable greeting
            '';
            shellInit = ''
                source ~/.config/fish/config-old.fish
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
        mise.enable = true;
        direnv.enable = true;
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