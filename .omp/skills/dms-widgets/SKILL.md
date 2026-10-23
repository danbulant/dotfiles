---
name: dms-widgets
description: >-
  Create, update, vendor, debug, check, and apply DankMaterialShell (DMS)
  widgets and plugins in this dotfiles repository, including QML bar pills,
  popouts, settings, plugin discovery, bar placement, and Home Manager wiring.
---
# DMS widget development

## Start with the local examples and installed version

- Inspect `.config/DankMaterialShell/plugins/` for vendored examples. Read the relevant plugin's manifest, QML entry point, settings component, helpers, and existing tests before changing it. For additional installed examples, inspect `${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins/`; these may be registry-managed or store-backed, so do not edit them as the source of truth.
- Inspect `servers/ui-mode/dotfiles.nix` for deployment mappings and `servers/ui-mode/home.nix` for the DMS package override, Home Manager module, and user-service integration. Both Fern and Aura use the UI module; select the actual target host.
- Resolve installed entry-point symlinks. Working-tree changes do not affect immutable Home Manager store copies until installed.
- Read the DMS input in `flake.nix` and revision in `flake.lock`. Prefer the installed package's `share/quickshell/dms/` sources when checking APIs. Do not assume `~/.config/quickshell/dms` exists or hard-code a store hash.
- Separate source changes, installation, plugin discovery, enablement, bar placement, and opening a popout. None implies the others succeeded.

## Documentation

The baseline inspected when writing this skill was DMS 1.6.3 at revision `4a87e8227daf0840b3376fd5e7f891f5900165a6`. Re-resolve it after updates. Public DMS documentation URLs redirected to Dux Shell 2.0 on 2026-10-23; newer paths and APIs may not match this checkout.

Version-matched references:

- [Plugin development guide and manifest specification](https://github.com/AvengeMedia/DankMaterialShell/blob/4a87e8227daf0840b3376fd5e7f891f5900165a6/quickshell/PLUGINS/README.md).
- [PluginComponent](https://github.com/AvengeMedia/DankMaterialShell/blob/4a87e8227daf0840b3376fd5e7f891f5900165a6/quickshell/Modules/Plugins/PluginComponent.qml), [BasePill sizing](https://github.com/AvengeMedia/DankMaterialShell/blob/4a87e8227daf0840b3376fd5e7f891f5900165a6/quickshell/Modules/Plugins/BasePill.qml), and [PluginSettings](https://github.com/AvengeMedia/DankMaterialShell/blob/4a87e8227daf0840b3376fd5e7f891f5900165a6/quickshell/Modules/Plugins/PluginSettings.qml).
- [Theme reference](https://github.com/AvengeMedia/DankMaterialShell/blob/4a87e8227daf0840b3376fd5e7f891f5900165a6/quickshell/PLUGINS/THEME_REFERENCE.md).
- [IPC handlers](https://github.com/AvengeMedia/DankMaterialShell/blob/4a87e8227daf0840b3376fd5e7f891f5900165a6/quickshell/DMSShellIPC.qml) and [plugin discovery/lifecycle](https://github.com/AvengeMedia/DankMaterialShell/blob/4a87e8227daf0840b3376fd5e7f891f5900165a6/quickshell/Services/PluginService.qml).

Current entry points: [plugin development](https://danklinux.com/docs/dankmaterialshell/plugin-development), [plugin overview](https://danklinux.com/docs/dankmaterialshell/plugins-overview), and [keybinds/IPC](https://danklinux.com/docs/dankmaterialshell/keybinds-ipc). Check redirects/version compatibility before following them. For dependency APIs, use documentation matching the installed Qt and [Quickshell](https://quickshell.org/docs/) versions.

## Create or update

1. Keep the plugin directory, manifest `id`, settings `pluginId`, bar entry, and IPC identifier consistent. Check the version-matched manifest schema and loader, not just an existing plugin's tolerated fields. Declare only necessary permissions; settings UI requires `settings_write` in this baseline.
2. A bar widget normally needs `plugin.json`, a `PluginComponent` QML entry point, and optionally a `PluginSettings` component. Desktop widgets, daemons, and launchers have different contracts. For forks, establish the upstream base and local delta, preserve attribution/license, and avoid registry updates overwriting local changes.
3. Reuse supported `qs.Common`, `qs.Services`, `qs.Widgets`, and `qs.Modules.Plugins` APIs, themed controls, and existing controllers. Read component definitions before guessing properties. Some implementations are re-exported from `dank-qml-common`; follow installed imports/symlinks rather than changing import conventions.
4. Provide the intended `horizontalBarPill`, `verticalBarPill`, and `popoutContent` components. Preserve inherited click/popout handling. `BasePill` measures content through `implicitWidth`/`implicitHeight`; explicit width alone on a plain `Item` can leave it measuring zero. Avoid parent/content sizing cycles.
5. Diagnose text clipping, pill sizing, host constraints, and screen overflow separately. For wrapping external text, use a finite width and `Text.PlainText`; choose wrapping/elision deliberately and propagate implicit height. Bound large popouts with scrolling. Check narrow screens, neighboring widgets, and supported orientations.
6. Use `pluginData`, `PluginSettings.loadValue/saveValue`, and existing setting controls. Preserve valid false/zero values and reactive updates. Runtime settings are not source files and may contain credentials: inspect selected fields only, never dump or commit the complete settings.
7. Keep substantial data logic in QML-compatible pure helpers where practical. Reuse existing test conventions. Use process argv arrays rather than interpolated shell strings; inspect real output/error contracts. Preserve cancellation and stale-result protection across asynchronous updates.
8. Add a new vendored plugin to `servers/ui-mode/dotfiles.nix` using the existing `xdg.configFile."DankMaterialShell/plugins/<id>"` pattern with the repo directory as source, `recursive = true`, and `force = true`. Do not incidentally take declarative ownership of the entire runtime settings directory. New files must be Git-tracked before Git-backed flake builds include them.

## Check work

Honor the task's runtime boundary. If DMS is stopped and live checks are waived, do not start/restart it, launch a probe shell, or repeatedly query unavailable IPC. Finish offline work and report the limitation. Otherwise reproduce the changed surface before fixing it and check the existing instance rather than launching a second shell.

Offline checks, selected for the change:

- Parse `plugin.json`; check identity, required fields against the installed schema/loader, permissions, and existence of component/settings/helper files. Manifest validation is not runtime instantiation.
- Run existing relevant helper tests. Add deterministic behavior regressions for real boundary cases, not source-text/wiring assertions or mock echoes.
- Parse changed QML without rewriting: `qmlformat path/to/Changed.qml >/dev/null`; inspect exit status/stderr. `qmlformat --dry-run` only reports settings and is not a syntax check. Avoid formatter churn.
- Use `qmllint` with the correct Qt/Quickshell imports and DMS `qs` root. Separate unresolved environment imports from actual errors; do not suppress diagnostics to manufacture a pass.
- If deployment wiring changed, evaluate the relevant mapping. For example, replacing `PLUGIN_ID`:

```sh
nix-instantiate --eval --strict --json --expr '
  let
    c = import ./servers/ui-mode/dotfiles.nix;
    p = c.xdg.configFile."DankMaterialShell/plugins/PLUGIN_ID";
  in { source = toString p.source; recursive = p.recursive; force = p.force; }
'
```

When live checks are allowed, inspect the actual bar and popout, settings changes, relevant loading/error/empty transitions, long/unbroken text, and dynamic updates. Check logs and capture only the relevant screen region; inspect the image rather than merely producing a screenshot. A temporary real-QML harness can measure sizing and controlled transitions, but does not replace integration in DMS. Use real installed components, isolate the harness, and stop/remove only its own processes/files afterward.

Useful tools:

- `quickshell log --pid <actual-QML-pid> --tail 100 --no-color` and `journalctl --user -u dms.service -n 100 --no-pager`.
- `grim -g 'X,Y WIDTHxHEIGHT' /tmp/dms-widget-check.png`, with current compositor geometry rather than historical coordinates.
- If session variables are missing, recover only the needed graphical-session values (`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, and Hyprland's signature where relevant). Do not dump all process environment or globally rewrite service environment as a widget workaround.

## Apply the change

### Install source

For lasting deployment, use Home Manager's existing mappings. It is embedded in the NixOS configs. Build-only example for Fern; substitute the actual host:

```sh
nix build --no-link --print-out-paths \
  .#nixosConfigurations.fern.config.home-manager.users.dan.home.activationPackage
```

If applying home configuration is requested, run the resulting package's `activate` script as `dan`, not root. This applies all pending home changes, not just the plugin; inspect scope first. A full `sudo nixos-rebuild switch --flake .#fern` is only for a requested/necessary system activation, not routine widget iteration.

For an authorized plugin-only preview, preserve the existing installed plugin path and links in a private persistent backup, then temporarily replace only that plugin directory with an absolute symlink to its repo source. Never write through store-backed links or recursively delete the original installation. Resolve entry points/helpers again to prove the intended source is installed. After preview, restore the original path or complete declarative deployment; report which source remains active. Home Manager may replace the development override on later activation.

### Discover, reload, and place

Running DMS only; check local help/source after version changes. Replace `PLUGIN_ID` with the intended identifier:

```sh
dms ipc --help
dms ipc call plugin-scan scan
dms ipc call plugin-scan list
dms ipc call plugins enable PLUGIN_ID
dms ipc call plugins status PLUGIN_ID
dms ipc call plugin-scan status PLUGIN_ID
dms ipc call settings get barConfigs
```

Discovery is debounced; the immediate scan response is not proof of loading. Enable only when intended. For a known plugin's metadata changes use `plugin-scan rescan PLUGIN_ID`; for source changes use `plugins reload PLUGIN_ID`, then inspect status and logs. In this baseline reload can enable an unloaded plugin. Reload operates on installed files, not automatically on the working tree.

Enablement does not place a widget. Use DMS Settings to add it to the intended bar/section and preserve order, other widgets, and per-monitor configuration. Entries may be strings or objects. Open its popout through the UI or `dms ipc call widget toggle PLUGIN_ID` and inspect the actual focused-screen surface.

Do not use `settings set barConfigs` on this baseline: its handler rejects arrays/objects. If direct JSON editing is needed, back up and patch only the intended fields, preferably while DMS is stopped to avoid writer races. Parse-check the file; if edited live, verify resulting in-memory settings as well. Never replace complete settings with a historical snapshot.

Prefer plugin-scoped reload over shell restart. Do not kill/restart the managed shell or launch a second notification daemon as a routine widget edit step.

## Delivery

Report source changes, installed source, enablement/placement changes, executed checks, and whether home/system activation occurred. Distinguish parsed QML from instantiated QML, loaded status from visual proof, and build-only from deployment. If live verification was waived, say so without claiming runtime success. Keep credentials, private desktop content, and chat transcripts out of artifacts.
