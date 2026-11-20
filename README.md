# mac-settings
Ender's mac settings

## Herdr mods

`herdr/mods/` holds mods for the [Herdr](https://herdr.dev) desktop app;
`install.sh` links each into `~/.config/herdr-app/mods/`.

- `kata`: reviews kata code reviews in a pane next to the agents working on
  them. A copy of `herdr/kata` from [eljaska/kata](https://github.com/eljaska/kata)
  (upstream: [martint/kata#13](https://github.com/martint/kata/pull/13)); re-copy
  it from there when the mod changes. It needs `kata serve` running and Python 3
  for its `kata-here` helper.
