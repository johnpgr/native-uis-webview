# Native Webview App (Zig + React)

## Project Overview

This project is a cross-platform desktop application that combines a **Zig** native backend with a **React (TypeScript)** frontend.

It uses the [webview/webview](https://github.com/webview/webview) library to create a native window containing a system webview (WebKitGTK on Linux, WebView2 on Windows, WebKit on macOS). The Zig backend handles OS-level operations (file system, dialogs, etc.) and communicates with the React frontend via a JSON-based IPC mechanism.

## Architecture

- **Frontend (`src/`):** A Single Page Application (SPA) built with React, TypeScript, Vite, and Tailwind CSS. It builds into a single HTML file (`dist/index.html`) that gets embedded into the Zig binary at compile time.
- **Backend (`src-zig/`):** A Zig application that initializes the webview window, exposes native functions to JavaScript, and handles application lifecycle.
- **IPC:** Communication happens via `webview_bind` (C -> JS) and `webview_return` (JS -> C). TypeScript wrappers provide a type-safe API for these native calls.

## Current Status

- **Core:** Zig build setup (`build.zig`) with dependencies in `build.zig.zon`. The build system reads `dist/index.html` and embeds it into the binary via build options. `main.zig` creates a webview window and loads the embedded HTML. **IPC handlers are not yet implemented.**
- **UI:** Vite + React + Tailwind setup with `vite-plugin-singlefile` to bundle everything into a single HTML file. Uses React Compiler via babel plugin.

## Development Workflow

### Prerequisites

- **Zig:** Version 0.15.2
- **Node.js & pnpm:** For the UI
- **System Libraries (Linux):** `libgtk-3-dev`, `libwebkit2gtk-4.1-dev` (or similar depending on distro)

### 1. Building & Running the Core

The core application is located in `src-zig/`.

```bash
cd src-zig
zig build run
```

### 2. Developing the UI

The UI is located at the project root.

```bash
pnpm install
pnpm run dev   # Run in browser (mock native calls if needed)
pnpm run build # Build single-file HTML for production/integration
```

## Project Structure

```
/
├── AGENTS.md              # Project documentation (canonical source)
├── CLAUDE.md -> AGENTS.md # Symlink for Claude Code
├── GEMINI.md -> AGENTS.md # Symlink for Gemini
├── README.md -> AGENTS.md # Symlink for GitHub
├── IMPLEMENTATION_PLAN.md # Detailed implementation roadmap
├── package.json           # UI dependencies & scripts
├── pnpm-lock.yaml         # Lockfile
├── vite.config.ts         # Vite config (single-file build)
├── tsconfig.json          # TypeScript config
├── eslint.config.js       # ESLint config
├── prettier.config.js     # Prettier config
├── index.html             # Vite entry HTML
├── src/                   # React Frontend Source
│   ├── main.tsx           # Entry point
│   ├── App.tsx            # Main component
│   └── index.css          # Global styles
├── public/                # Static assets
├── dist/                  # UI Build Output (single-file HTML)
└── src-zig/               # Zig Backend
    ├── build.zig          # Build configuration
    ├── build.zig.zon      # Zig dependencies
    └── main.zig           # Application entry point
```

## Troubleshooting

### WebKitGTK Crash on Wayland (Error 71 Protocol Error)

Users on Wayland, especially with NVIDIA graphics, might experience a crash immediately after the main window appears, with a message similar to: `Gdk-Message: ... Error 71 (Erro de protocolo) dispatching to Wayland display.`

This is a known compatibility issue with WebKitGTK's hardware acceleration (DMABuf) on certain Wayland setups.

**Workaround:**
Run the application with the `WEBKIT_DISABLE_DMABUF_RENDERER=1` environment variable:

```bash
WEBKIT_DISABLE_DMABUF_RENDERER=1 zig build run
```

If the issue persists, try forcing the XWayland backend:

```bash
GDK_BACKEND=x11 zig build run
```

## Next Steps

Refer to `IMPLEMENTATION_PLAN.md` for the detailed roadmap. Immediate tasks include:

1. Adding a Zig wrapper (`webview.zig`) for the webview C API.
2. Implementing IPC handlers (`handlers.zig`) for native functionality.
3. Generating TypeScript definitions from Zig types for type-safe IPC.
