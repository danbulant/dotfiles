{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./udev-block-notify.nix {}