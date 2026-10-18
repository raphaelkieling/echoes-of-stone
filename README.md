# Echoes of Stone

A fantasy Sokoban puzzle where heroes use unique abilities to move blocks and reach each level's goals.

![Gameplay screenshot](docs/Screenshot%202026-10-18%20at%2005.20.01.png)

## Game

With [LÖVE](https://love2d.org/) installed:

```sh
love .
```

## Testing

With `lua` installed:

```sh
lua tests/run.lua
```

## Developer console

Press the grave/tilde key (` or ~) to open or close the in-game console. Use `Tab` to autocomplete a command,
`Enter` to run it, and `Esc` to close it. Available commands:

- `show-solid` toggles outlines for solid map cells and interactive objects.
- `show-solid on` / `show-solid off` explicitly enable or disable the outlines.
- `jump-to 0` loads level 0; `jump-to p` loads the playground (also accepts a level name).
- `help` lists registered commands.

Commands are registered in `src/dev/ConsoleCommands.lua`. To remove the console
and other developer UI from a production build, set `developmentMode` to `false` in
`src/settings/BuildConfig.lua`.
