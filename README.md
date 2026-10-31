# Ostreamy

Bar widget and panel for [ostreamy-cli](https://github.com/h1st0ry3d/ostreamy-cli),
the Sunshine stream target switcher. The panel does not read the config or talk to
Hyprland. It calls `ostreamy state` for JSON and `ostreamy on`, `off`, `mode` and
`edit` for changes, so the CLI stays the only place that knows the layout rules.

```
bar icon (two frames) -> panel
  Ostreamy        [Edit]
  1920x1200 at 60 Hz, desktop
  ------------------------------
  [ Start ] [ Stop ]
  Resolution
  [ 1280x800 ] [ 1920x1200 ]
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

After adding the plugin, restart the shell from a terminal that belongs to the
running session, or refresh the signature first:

```bash
export HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | jq -r 'sort_by(.time)|last|.instance')
omarchy restart shell
```

A stale signature in a long-lived terminal makes the restart kill the shell without
relaunching it: the script calls `hyprctl dispatch` and that fails silently. The bar
then has no widget because it has no shell. Check with
`omarchy-shell shell debugBarGeometry` after the restart; the widget should appear
with `visible=true` and a width of about 27 px.

## Behaviour worth knowing

- Start and Stop map to `ostreamy on` and `ostreamy off`. The state line above the
  buttons shows which layout is active, so there is no third flipping button.
- The same two actions are reachable without the panel:
  `omarchy-shell h1st0ry3d.ostreamy.actions start` and `... stop`.
- Switching layout reconfigures every bar surface. The panel therefore closes first
  and the CLI runs 1.2 s later, which avoids the Qt Wayland configure abort that
  killed the shell (core `6vvm2e2snt`) when the two overlapped. The scripted actions
  also hide the focused panel through the shell, since an IPC call can land on a
  different bar copy than the one with the open popup.
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
