{
  lib,
  pkgs ? import <nixpkgs> { },
  ...
}:

pkgs.python3Packages.buildPythonApplication {
  pname = "llama-swap-exporter";
  version = "0.1.0";

  src = ./src;
  build-system = with pkgs.python3Packages; [
    setuptools
    setuptools-scm
  ];
  pyproject = true;
  meta = {
    description = "Prometheus exporter for llama-swap metrics";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };
}
