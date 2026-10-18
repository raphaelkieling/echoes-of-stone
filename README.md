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
