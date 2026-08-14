{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "tuwunel-admin";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "knadh";
    repo = "tuwunel-admin";
    tag = "v${version}";
    hash = "sha256-60yPa+B6PYzOoCjQyeqdy5vdF5BCFNVv2CTofPi6lRQ=";
  };

  cargoHash = "sha256-TpC+5/Ox04aQpUSssMnaVadq7+sroW9mJViVFGNsVIk=";

  env.VERSION = "v${version}";

  meta = {
    description = "Web admin UI for the tuwunel Matrix server";
    homepage = "https://github.com/knadh/tuwunel-admin";
    license = lib.licenses.asl20;
    mainProgram = "tuwunel-admin";
  };
}
