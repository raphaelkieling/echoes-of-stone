# Echos of Stone

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
- `help` lists registered commands.

Commands are registered in `src/dev/ConsoleCommands.lua`. To remove the console
from a production build, set `devConsoleEnabled` to `false` in
`src/settings/BuildConfig.lua`.
