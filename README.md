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

## Architecture

- Character abilities live in `src/characters/classes/`; each class implements its own `move` method.
- `src/game/MovementSession.lua` provides shared grid and collision helpers. `CharacterMovement.lua` commits moves and records undo.
- Player states live in `src/characters/states/` and are registered in `PlayerStates.lua`. `Walking` and `Pushing` share `MovementState`, which handles movement presentation effects; idle-only presentation, such as the subtle sway, belongs in `Idle.lua`.
- To add a character class, create its class file and register it in `src/characters/Classes.lua`.
- Generated move, blocked-move, undo, target, and UI sounds are configured in `src/audio/SoundCatalog.lua`; set a sound's `file` path there to replace its synthesized version without changing gameplay code.
- A local JSON event log is saved under `logs/` in LÖVE's save directory. It records app/screens/levels, console command names, and player movement outcomes for debugging; nothing is uploaded. The logger listens to the game's event emitter, so gameplay code emits events without depending on the logger.
- In development, run `copy-logger-path` in the console to copy the current log file's shell-quoted path (ready to paste after `cat `).
