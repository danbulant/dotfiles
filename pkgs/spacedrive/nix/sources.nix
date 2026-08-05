{ lib, root }:
let
  cleaned = lib.cleanSource root;
  commonCargoFiles = [
    "^\\.cargo(/.*)?$"
    "^Cargo\\.lock$"
    "^Cargo\\.toml$"
    "^rust-toolchain\\.toml$"
    "^apps$"
    "^apps/mobile$"
    "^apps/mobile/modules$"
    "^apps/mobile/modules/sd-mobile-core$"
    "^apps/mobile/modules/sd-mobile-core/core$"
    "^apps/mobile/modules/sd-mobile-core/core/Cargo\\.toml$"
    "^apps/mobile/modules/sd-mobile-core/core/src(/.*)?$"
  ];
in
{
  frontendSrc = lib.sources.sourceByRegex cleaned [
    "^package\\.json$"
    "^tsconfig\\.json$"
    "^bunfig\\.toml$"
    "^apps(/.*)?$"
    "^packages(/.*)?$"
    "^scripts(/.*)?$"
    "^\\.github/actions(/.*)?$"
  ];

  daemonRustSrc = lib.sources.sourceByRegex cleaned (
    commonCargoFiles
    ++ [
      "^apps/cli(/.*)?$"
      "^apps/server(/.*)?$"
      "^apps/tauri(/.*)?$"
      "^core(/.*)?$"
      "^crates(/.*)?$"
      "^xtask(/.*)?$"
    ]
  );

  desktopRustSrc = lib.sources.sourceByRegex cleaned (
    commonCargoFiles
    ++ [
      "^apps/cli(/.*)?$"
      "^apps/server(/.*)?$"
      "^apps/tauri(/.*)?$"
      "^core(/.*)?$"
      "^crates(/.*)?$"
      "^xtask(/.*)?$"
    ]
  );

  cliRustSrc = lib.sources.sourceByRegex cleaned (
    commonCargoFiles
    ++ [
      "^apps/cli(/.*)?$"
      "^apps/server(/.*)?$"
      "^apps/tauri(/.*)?$"
      "^core(/.*)?$"
      "^crates(/.*)?$"
      "^xtask(/.*)?$"
    ]
  );
}
