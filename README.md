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

## Components

Game objects are compositions of components. A character keeps its character-only pieces together under the `Character` component:

```text
GameObject
├── Transform
├── InteractiveObject
└── Character
    ├── Player
    ├── CharacterClass (Dwarf, Wizard, ...)
    ├── CharacterMovement
    ├── StateMachine (Idle, Walking, Pushing)
    ├── Animation
    ├── SpriteRenderer
    └── MovementEffects
```

`CharacterFactory` assembles this composition; `CharacterMovement` handles shared move orchestration, while each class component implements its own ability. The nested components remain available through `gameObject:getComponent(name)`. To extend a character, add a component to its `Character` container rather than adding class-specific conditionals to movement code. Character classes are registered in `src/characters/Classes.lua`.

## Scenes and states

`SceneManager` swaps the active scene root. Scenes and world objects share the `Node` parent/child lifecycle, while components add behavior to game objects. The playing scene is composed like this:

```text
PlayingScene
├── Board
│   ├── Character
│   └── Box
└── PlayingHud
```

`src/core/StateMachine.lua` is independent of scenes and game objects. `PlayingScene` uses it for `Entering`, `Playing`, `Paused`, `LevelTransition`, and `Completed`; the character `StateMachine` component is a thin adapter to the same core implementation.

## Desktop builds

On macOS, with `curl`, `zip`, and `ditto` available:

```sh
./scripts/build-desktop.sh
```

This creates a Windows x64 folder/ZIP and a macOS `.app`/ZIP under `dist/desktop/`. To create only one platform, pass `windows` or `macos`. The script packages the game with the official LÖVE 11.5 runtimes and disables the development console in release builds.

The macOS app is not signed or notarized; a public release may need an Apple Developer ID signature and notarization to avoid Gatekeeper warnings.
