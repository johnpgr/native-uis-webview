# Native Webview App (Zig + React)

## Project Overview

This project is a cross-platform desktop application that combines a **Zig** native backend with a **React (TypeScript)** frontend.

It uses the [webview/webview](https://github.com/webview/webview) library to create a native window containing a system webview (WebKitGTK on Linux, WebView2 on Windows, WebKit on macOS). The Zig backend handles OS-level operations (file system, dialogs, etc.) and communicates with the React frontend via a JSON-based IPC mechanism.

## Architecture

- **Frontend (`ui/`):** A Single Page Application (SPA) built with React, TypeScript, Vite, and Tailwind CSS. It builds into a single HTML file for easy loading into the webview.
- **Backend (`core/`):** A Zig application that initializes the webview window, exposes native functions to JavaScript, and handles application lifecycle.
- **IPC:** Communication happens via `window.webview_bind` (C -> JS) and `window.webview_return` (JS -> C). TypeScript wrappers provide a type-safe API for these native calls.

## Current Status

- **Core:** Basic Zig build setup (`build.zig`) is in place with dependencies defined in `build.zig.zon`. `main.zig` currently opens a simple webview with hardcoded HTML. **It does not yet implement the full IPC handlers or load the actual UI build.**
- **UI:** Standard Vite + React + Tailwind setup. Includes `vite-plugin-singlefile` to bundle assets for the webview.

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
├── CLAUDE.md              # Project guidelines and shortcuts
├── IMPLEMENTATION_PLAN.md # detailed implementation roadmap
├── GEMINI.md              # This context file
├── package.json           # UI dependencies & Scripts
├── vite.config.ts         # Vite config (single-file build)
├── src/                   # React Frontend Source
│   ├── main.tsx           # Entry point
│   └── ...
├── dist/                  # UI Build Output
└── src-zig/               # Zig Backend
    ├── build.zig          # Build configuration
    ├── build.zig.zon      # Zig dependencies
    └── main.zig           # Application entry point

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
```

## Next Steps

Refer to `IMPLEMENTATION_PLAN.md` for the detailed roadmap. Immediate tasks include:

1.  Refactoring `core/` to add `webview.zig` wrapper and `handlers.zig`.
2.  Implementing the mechanism to load the built `index.html` from the UI into the webview.
3.  Generating TypeScript definitions from Zig types.
