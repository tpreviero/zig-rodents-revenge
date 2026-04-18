# Zig, Rodent's Revenge!

A [Zig](https://ziglang.org/) port of the classic game [Rodent's Revenge](https://en.wikipedia.org/wiki/Rodent%27s_Revenge),
where you play as a mouse trying to trap cats in a maze.

This is a migration of my Go implementation — [tpreviero/go-rodents-revenge](https://github.com/tpreviero/go-rodents-revenge) —
rewritten in Zig using [raylib-zig](https://github.com/raylib-zig/raylib-zig) bindings over
[raylib](https://github.com/raysan5/raylib) 5.6-dev.

I do not own the rights to the original game; this is a fan recreation for fun.

## Requirements

- Zig **0.16.0**

## Build and run

Native desktop build:

```bash
zig build run
```

WebAssembly build (requires an internet connection on first run to fetch
the Emscripten SDK):

```bash
zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast
# Output lands in zig-out/web/ — serve it with any static HTTP server, e.g.:
python3 -m http.server --directory zig-out/web 8000
```

A playable build is auto-deployed to GitHub Pages on every push to `main` —
see [tpreviero.github.io/zig-rodents-revenge](https://tpreviero.github.io/zig-rodents-revenge/).

Dependencies are fetched and built automatically on the first run.

## Controls

- _Arrow keys_ / numpad: Move the rodent (8 directions)
- `P`: Pause the game
- `Right Shift + UP`: Increase difficulty (speeds up the cats)
- `Right Shift + DOWN`: Decrease difficulty (slows the cats)
- `Right Shift + RIGHT`: Skip to the next level
- `Right Shift + LEFT`: Go back to the previous level
- `Right Shift + M`: Toggle between single player and cooperative mode
- `?`: Toggle the help screen
- `ESC`: Quit
