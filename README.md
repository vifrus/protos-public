# LOVE Game Portal

A web portal for LOVE2D games, automatically built and deployed to GitHub Pages.

## How It Works

1. Add a LOVE game to the `games/` directory (each game in its own subfolder with `main.lua`)
2. Push to `main`
3. GitHub Actions builds each game for the web using [love.js](https://github.com/Davidobot/love.js)
4. A landing page is generated and deployed to GitHub Pages

## Adding a New Game

1. Create a new folder under `games/` (e.g., `games/my-game/`)
2. Add at minimum a `main.lua` file
3. Optionally add `conf.lua` for window configuration
4. Push to `main` -- the game will appear on the portal automatically

## Game Structure

Each game folder should be a standard LOVE project:

```
games/my-game/
├── main.lua      # Required: game entry point
├── conf.lua      # Optional: LOVE configuration
├── assets/       # Optional: images, sounds, etc.
└── lib/          # Optional: Lua libraries
```

## Web Compatibility Notes

- No `love.thread` support (web limitation)
- Audio should use `"static"` source type
- No FFI support
- Shaders must use strict GLSL typing (e.g., `2.0` not `2`)
- Games are built in compatibility mode (no SharedArrayBuffer required)

## Setup: Enable GitHub Pages

Before the first deployment works, you need to enable GitHub Pages manually:

1. Go to the repository **Settings** > **Pages**
2. Under "Build and deployment", set **Source** to **GitHub Actions**
3. Push to `main` or trigger the workflow manually from the **Actions** tab

## Local Development

Install [LOVE2D](https://love2d.org/) and run:

```bash
love games/hello-love/
love games/bouncing-ball/
```
