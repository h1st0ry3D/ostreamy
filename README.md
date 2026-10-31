# Ostreamy (Omarchy shell plugin)

Bar widget and panel for [ostreamy-cli](https://github.com/h1st0ry3d/ostreamy-cli),
the Sunshine stream target switcher. The panel does not read the config or talk to
Hyprland. It calls `ostreamy state` for JSON and `ostreamy on`, `off`, `mode` and
`edit` for changes, so the CLI stays the only place that knows the layout rules.

```
bar icon (two frames) -> panel
  Ostreamy        [Edit]
  1920x1200 at 60 Hz, desktop
  ------------------------------
  [ Enable ] [ Disable ] [ Toggle ]
  Resolution
  [ 1280x800 · Deck native ] [ 1920x1200 · 16:10 desktop ]
  Frame rate
  [ 30 ] [ 40 ] [ 45 ] [ 60 ] [ 80 ] [ 90 ]
```

## Requires

- `ostreamy-cli` installed (`ostreamy` in `/usr/local/bin` or `~/.local/bin`)
- Omarchy with the Quickshell shell, Hyprland Lua config

Install the CLI first, then link this plugin:

```bash
git clone <repo> ~/github/ostreamy
ln -s ../../../github/ostreamy ~/.config/omarchy/plugins/h1st0ry3d.ostreamy
```

Add it to `~/.config/omarchy/shell.json`, both as a bar widget and as an enabled
plugin:

```json
{ "bar": { "layout": { "right": [ { "id": "h1st0ry3d.ostreamy" } ] } },
  "plugins": [ { "id": "h1st0ry3d.ostreamy", "enabled": true } ] }
```

The panel is reached from the bar icon. `Edit` opens `~/.config/ostreamy/config.sh`
through `ostreamy edit` (xdg-open, then a terminal editor as fallback).

## Behaviour worth knowing

- Enable and Disable map to `ostreamy on` and `ostreamy off`. Toggle picks the
  opposite of the current state.
- Resolution and frame rate map to `ostreamy mode WxH@HZ`. While a stream runs, the
  CLI saves the value and applies it to the next session, because changing the
  mode under a live encoder stalls the video. The panel reports that instead of
  pretending the change took effect.
- The bar tooltip shows the configured mode and whether a stream is running.

## Files

```
manifest.json   plugin metadata (id h1st0ry3d.ostreamy)
Panel.qml       bar icon and panel
```

## License

MIT
