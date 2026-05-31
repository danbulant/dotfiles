# Steam Heroic Direct Shortcuts

Reference for the non-declarative Steam shortcuts added for Heroic-managed games.
These live in Steam config files, not Nix, so this file records the important state for future recovery.

## Files

- Steam shortcuts: `/home/dan/.local/share/Steam/userdata/238310127/config/shortcuts.vdf`
- Steam compatibility mapping: `/home/dan/.local/share/Steam/config/config.vdf`
- Steam compatdata: `/home/dan/.local/share/Steam/steamapps/compatdata/`
- Heroic game config: `/home/dan/.config/heroic/GamesConfig/`

## Steam Shortcuts

All direct shortcuts are configured to use `DW-Proton Latest`.

| Name | App ID | Exe | StartDir | Launch options |
| --- | ---: | --- | --- | --- |
| `Arknights: Endfield (Direct Launcher)` | `3532200938` | `/home/dan/Games/Heroic/ArknightsEndfieldgowoU/Launcher.exe` | `/home/dan/Games/Heroic/ArknightsEndfieldgowoU` | empty |
| `Arknights: Endfield (Direct Game)` | `2506976826` | `/home/dan/Games/Heroic/ArknightsEndfieldgowoU/games/EndField Game/Endfield.exe` | `/home/dan/Games/Heroic/ArknightsEndfieldgowoU/games/EndField Game` | empty |
| `Zenless Zone Zero (Direct Launcher)` | `2568476331` | `/home/dan/Games/Heroic/ZenlessZoneZero/launcher_epic.exe` | `/home/dan/Games/Heroic/ZenlessZoneZero` | `UMU_ID=umu-zenlesszonezero UMU_USE_STEAM=1 WINE_DISABLE_VULKAN_OPWR=1 %command% {enable_pay:true}` |
| `Zenless Zone Zero (Direct Game)` | `4264951319` | `/home/dan/Games/Heroic/ZenlessZoneZero/games/ZenlessZoneZero Game/ZenlessZoneZero.exe` | `/home/dan/Games/Heroic/ZenlessZoneZero/games/ZenlessZoneZero Game` | `UMU_ID=umu-zenlesszonezero UMU_USE_STEAM=1 WINE_DISABLE_VULKAN_OPWR=1 %command%` |

The original Heroic-generated shortcuts were left in place:

| Name | App ID | Exe | Launch options |
| --- | ---: | --- | --- |
| `Zenless Zone Zero` | `2928100415` | `heroic` | `--no-gui --no-sandbox "heroic://launch?appName=525aa0efd70f4399b9f64bcd2a5b38c7&runner=legendary"` |
| `Arknights: Endfield` | `2465091319` | `heroic` | `--no-gui --no-sandbox "heroic://launch?appName=bcd55b0d87c245dd867f5b1bd496f1df&runner=legendary"` |

## Compatibility Mapping

The app IDs above were added under `InstallConfigStore.Software.Valve.Steam.CompatToolMapping` in Steam's `config.vdf`:

```vdf
"CompatToolMapping"
{
    "3532200938"
    {
        "name"     "DW-Proton Latest"
        "config"   ""
        "priority" "250"
    }
    "2506976826"
    {
        "name"     "DW-Proton Latest"
        "config"   ""
        "priority" "250"
    }
    "2568476331"
    {
        "name"     "DW-Proton Latest"
        "config"   ""
        "priority" "250"
    }
    "4264951319"
    {
        "name"     "DW-Proton Latest"
        "config"   ""
        "priority" "250"
    }
}
```

## Prefix Links

The direct Steam shortcuts use the existing Heroic prefixes by symlinking each shortcut's `pfx` directory:

```sh
ln -s "/home/dan/Games/Heroic/Prefixes/default/Zenless Zone Zero" \
  "/home/dan/.local/share/Steam/steamapps/compatdata/2568476331/pfx"

ln -s "/home/dan/Games/Heroic/Prefixes/default/Zenless Zone Zero" \
  "/home/dan/.local/share/Steam/steamapps/compatdata/4264951319/pfx"

ln -s "/home/dan/Games/Heroic/Prefixes/default/Arknights Endfield" \
  "/home/dan/.local/share/Steam/steamapps/compatdata/3532200938/pfx"

ln -s "/home/dan/Games/Heroic/Prefixes/default/Arknights Endfield" \
  "/home/dan/.local/share/Steam/steamapps/compatdata/2506976826/pfx"
```

If Steam already created a fresh prefix, move it aside before creating the symlink:

```sh
mv "/home/dan/.local/share/Steam/steamapps/compatdata/4264951319/pfx" \
  "/home/dan/.local/share/Steam/steamapps/compatdata/4264951319/pfx.steam-empty-bak"
```

## Notes

- `gamescope` is installed declaratively in `servers/ui-mode/home.nix` for optional testing.
- `Zenless Zone Zero (Direct Game)` is the most promising shortcut: the game process starts and Steam starts `gameoverlayui` for it.
- The Heroic-generated `heroic://launch` shortcuts can start the games, but Steam Overlay/Input may not attach because Steam tracks Heroic/Electron rather than the final game process.
- Zenless launcher mode needs fresh Epic exchange-code arguments from Heroic/Legendary, so the direct launcher shortcut may not be reliable.
- A `wine64-preloader`/`rpcss.exe` `SIGSYS` coredump was seen during startup, but the game continued and overlay was started; treat it as non-fatal unless the game crashes.
