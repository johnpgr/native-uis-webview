# Cross-Platform Native Webview Desktop App in Zig

## Overview

Use the [webview/webview](https://github.com/webview/webview) C/C++ library from Zig for cross-platform desktop apps.

**webview/webview handles:**
- Platform abstraction (Windows WebView2, macOS WKWebView, Linux WebKitGTK)
- Window creation and lifecycle
- JavaScript evaluation
- IPC via `webview_bind()` / `webview_return()` (JSON-based)

**We handle:**
- Zig bindings to webview C API
- JSON serialization/deserialization for IPC
- Type-safe TypeScript definitions
- Application logic (handlers)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        TypeScript (UI)                          │
│                                                                 │
│   const files = await window.listDir("/home");  // Promise      │
│   // files: FileInfo[] (typed)                                  │
└─────────────────────────────┬───────────────────────────────────┘
                              │ JSON: ["/home"]
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    webview/webview library                      │
│                                                                 │
│   webview_bind(w, "listDir", callback, ctx)                     │
│   webview_return(w, id, 0, "[{...}, {...}]")                    │
└─────────────────────────────┬───────────────────────────────────┘
                              │ callback(id, req_json, ctx)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Zig (Backend)                           │
│                                                                 │
│   fn listDirCallback(id, req, ctx) {                            │
│       const args = std.json.parseFromSlice(req);                │
│       const path = args[0];                                     │
│       const result = listDirImpl(path);                         │
│       const json = std.json.stringify(result);                  │
│       webview_return(w, id, 0, json);                           │
│   }                                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
core/
├── build.zig                    # Build config + webview dependency
├── build.zig.zon               # Package manifest
├── src/
│   ├── main.zig                # Entry point
│   ├── webview.zig             # Zig wrapper for webview C API
│   ├── api.zig                 # API types (Config, FileInfo, etc.)
│   ├── handlers.zig            # Handler implementations
│   └── bindings.zig            # Register all bindings
├── tools/
│   └── gen_types.zig           # Generate TypeScript types from api.zig
ui/
├── src/
│   ├── generated/
│   │   └── api.ts              # Generated types
│   ├── native.ts               # Typed wrappers for window.* functions
│   └── ...
```

---

## Implementation Steps

### Step 1: Add webview/webview Dependency

**Option A: Use existing Zig package**

Check if [webview-zig](https://github.com/thechampagne/webview-zig) or similar works with Zig 0.15.

**Option B: Add webview as C dependency**

```zig
// build.zig.zon
.dependencies = .{
    .webview = .{
        .url = "https://github.com/webview/webview/archive/refs/tags/0.12.0.tar.gz",
        .hash = "...",
    },
},
```

```zig
// build.zig
const webview_dep = b.dependency("webview", .{});
exe.addIncludePath(webview_dep.path(""));
exe.linkLibCpp();

// Platform-specific linking
switch (target.result.os.tag) {
    .linux => {
        exe.linkSystemLibrary("gtk+-3.0");
        exe.linkSystemLibrary("webkit2gtk-4.1");
    },
    .macos => {
        exe.linkFramework("WebKit");
    },
    .windows => {
        // WebView2 loader
    },
}
```

### Step 2: Zig Wrapper for webview C API

```zig
// src/webview.zig
const c = @cImport({
    @cInclude("webview.h");
});

pub const Webview = struct {
    handle: c.webview_t,

    pub fn init(debug: bool) Webview {
        return .{ .handle = c.webview_create(@intFromBool(debug), null) };
    }

    pub fn destroy(self: *Webview) void {
        c.webview_destroy(self.handle);
    }

    pub fn setTitle(self: *Webview, title: [*:0]const u8) void {
        c.webview_set_title(self.handle, title);
    }

    pub fn setSize(self: *Webview, width: i32, height: i32) void {
        c.webview_set_size(self.handle, width, height, c.WEBVIEW_HINT_NONE);
    }

    pub fn navigate(self: *Webview, url: [*:0]const u8) void {
        c.webview_navigate(self.handle, url);
    }

    pub fn run(self: *Webview) void {
        c.webview_run(self.handle);
    }

    pub fn eval(self: *Webview, js: [*:0]const u8) void {
        c.webview_eval(self.handle, js);
    }

    pub fn bind(
        self: *Webview,
        name: [*:0]const u8,
        callback: *const fn ([*:0]const u8, [*:0]const u8, ?*anyopaque) void,
        ctx: ?*anyopaque,
    ) void {
        c.webview_bind(self.handle, name, callback, ctx);
    }

    pub fn @"return"(self: *Webview, id: [*:0]const u8, status: i32, result: [*:0]const u8) void {
        c.webview_return(self.handle, id, status, result);
    }
};
```

### Step 3: Define API Types in Zig

```zig
// src/api.zig

pub const FileInfo = struct {
    name: []const u8,
    size: u64,
    is_dir: bool,
    modified: u64,
};

pub const Config = struct {
    theme: []const u8,
    font_size: u32,
    dark_mode: bool,
    recent_files: []const []const u8,
};

pub const DialogResult = union(enum) {
    cancelled,
    selected: []const []const u8,
};

// ... other types
```

### Step 4: Implement Handlers

```zig
// src/handlers.zig
const std = @import("std");
const api = @import("api.zig");
const Webview = @import("webview.zig").Webview;

pub const Context = struct {
    webview: *Webview,
    allocator: std.mem.Allocator,
};

pub fn readFile(ctx: *Context, id: [*:0]const u8, args_json: []const u8) void {
    // Parse args: ["path"]
    const parsed = std.json.parseFromSlice(
        struct { []const u8 },
        ctx.allocator,
        args_json,
        .{},
    ) catch |err| {
        returnError(ctx, id, @errorName(err));
        return;
    };
    defer parsed.deinit();

    const path = parsed.value[0];

    // Do the work
    const content = std.fs.cwd().readFileAlloc(ctx.allocator, path, 10 * 1024 * 1024) catch |err| {
        returnError(ctx, id, @errorName(err));
        return;
    };
    defer ctx.allocator.free(content);

    // Return result as JSON string (base64 for binary)
    const base64 = std.base64.standard.Encoder.encode(ctx.allocator, content) catch |err| {
        returnError(ctx, id, @errorName(err));
        return;
    };
    defer ctx.allocator.free(base64);

    var result = std.ArrayList(u8).init(ctx.allocator);
    defer result.deinit();
    std.json.stringify(.{ .data = base64 }, .{}, result.writer()) catch return;

    ctx.webview.@"return"(id, 0, result.items.ptr);
}

pub fn listDir(ctx: *Context, id: [*:0]const u8, args_json: []const u8) void {
    // Parse args
    const parsed = std.json.parseFromSlice(
        struct { []const u8 },
        ctx.allocator,
        args_json,
        .{},
    ) catch |err| {
        returnError(ctx, id, @errorName(err));
        return;
    };
    defer parsed.deinit();

    const path = parsed.value[0];

    // List directory
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
        returnError(ctx, id, @errorName(err));
        return;
    };
    defer dir.close();

    var files = std.ArrayList(api.FileInfo).init(ctx.allocator);
    defer files.deinit();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        files.append(.{
            .name = ctx.allocator.dupe(u8, entry.name) catch continue,
            .size = 0, // Would need stat
            .is_dir = entry.kind == .directory,
            .modified = 0,
        }) catch continue;
    }

    // Return as JSON
    var result = std.ArrayList(u8).init(ctx.allocator);
    defer result.deinit();
    std.json.stringify(files.items, .{}, result.writer()) catch return;

    ctx.webview.@"return"(id, 0, result.items.ptr);
}

fn returnError(ctx: *Context, id: [*:0]const u8, err: []const u8) void {
    var msg = std.ArrayList(u8).init(ctx.allocator);
    defer msg.deinit();
    std.json.stringify(.{ .@"error" = err }, .{}, msg.writer()) catch return;
    ctx.webview.@"return"(id, 1, msg.items.ptr);
}
```

### Step 5: Register Bindings

```zig
// src/bindings.zig
const handlers = @import("handlers.zig");
const Webview = @import("webview.zig").Webview;

pub fn registerAll(webview: *Webview, ctx: *handlers.Context) void {
    webview.bind("readFile", wrapHandler(handlers.readFile), ctx);
    webview.bind("writeFile", wrapHandler(handlers.writeFile), ctx);
    webview.bind("listDir", wrapHandler(handlers.listDir), ctx);
    webview.bind("getConfig", wrapHandler(handlers.getConfig), ctx);
    // ... etc
}

fn wrapHandler(comptime handler: anytype) fn ([*:0]const u8, [*:0]const u8, ?*anyopaque) void {
    return struct {
        fn callback(id: [*:0]const u8, req: [*:0]const u8, arg: ?*anyopaque) void {
            const ctx: *handlers.Context = @ptrCast(@alignCast(arg));
            handler(ctx, id, std.mem.span(req));
        }
    }.callback;
}
```

### Step 6: Main Entry Point

```zig
// src/main.zig
const std = @import("std");
const Webview = @import("webview.zig").Webview;
const bindings = @import("bindings.zig");
const handlers = @import("handlers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var webview = Webview.init(true); // debug=true
    defer webview.destroy();

    var ctx = handlers.Context{
        .webview = &webview,
        .allocator = gpa.allocator(),
    };

    // Register all IPC handlers
    bindings.registerAll(&webview, &ctx);

    webview.setTitle("My App");
    webview.setSize(1024, 768);
    webview.navigate("file:///path/to/ui/dist/index.html");

    webview.run();
}
```

### Step 7: Generate TypeScript Types

Small Zig program that uses comptime to emit TypeScript:

```zig
// tools/gen_types.zig
const std = @import("std");
const api = @import("../src/api.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll("// AUTO-GENERATED - DO NOT EDIT\n\n");

    // Emit each struct as TypeScript interface
    inline for (@typeInfo(api).@"struct".decls) |decl| {
        const T = @field(api, decl.name);
        if (@typeInfo(@TypeOf(T)) == .type) {
            try emitInterface(stdout, decl.name, T);
        }
    }
}

fn emitInterface(writer: anytype, name: []const u8, comptime T: type) !void {
    try writer.print("export interface {s} {{\n", .{name});

    const info = @typeInfo(T);
    if (info == .@"struct") {
        inline for (info.@"struct".fields) |field| {
            const ts_type = zigTypeToTs(field.type);
            try writer.print("  {s}: {s};\n", .{ field.name, ts_type });
        }
    }

    try writer.writeAll("}\n\n");
}

fn zigTypeToTs(comptime T: type) []const u8 {
    return switch (@typeInfo(T)) {
        .int, .float => "number",
        .bool => "boolean",
        .pointer => |p| if (p.child == u8) "string" else zigTypeToTs(p.child) ++ "[]",
        .optional => |o| zigTypeToTs(o.child) ++ " | null",
        else => "unknown",
    };
}
```

Run: `zig run tools/gen_types.zig > ../ui/src/generated/api.ts`

### Step 8: TypeScript Native Wrappers

```typescript
// ui/src/native.ts
import type { FileInfo, Config } from './generated/api';

// Declare window bindings (injected by webview)
declare global {
  interface Window {
    readFile(path: string): Promise<{ data: string }>;  // base64
    writeFile(path: string, content: string): Promise<void>;
    listDir(path: string): Promise<FileInfo[]>;
    getConfig(): Promise<Config>;
    setConfig(config: Config): Promise<void>;
    showMessage(title: string, message: string): Promise<void>;
  }
}

// Typed wrappers with better ergonomics
export async function readFile(path: string): Promise<Uint8Array> {
  const { data } = await window.readFile(path);
  return Uint8Array.from(atob(data), c => c.charCodeAt(0));
}

export async function readTextFile(path: string): Promise<string> {
  const bytes = await readFile(path);
  return new TextDecoder().decode(bytes);
}

export async function writeFile(path: string, content: Uint8Array): Promise<void> {
  const base64 = btoa(String.fromCharCode(...content));
  return window.writeFile(path, base64);
}

export async function writeTextFile(path: string, content: string): Promise<void> {
  return writeFile(path, new TextEncoder().encode(content));
}

export const listDir = window.listDir;
export const getConfig = window.getConfig;
export const setConfig = window.setConfig;
export const showMessage = window.showMessage;
```

---

## Key Files

| File | Purpose |
|------|---------|
| `core/build.zig` | Build config, webview dependency, platform linking |
| `core/src/webview.zig` | Zig wrapper for webview C API |
| `core/src/api.zig` | Type definitions (source of truth for TS generation) |
| `core/src/handlers.zig` | Handler implementations |
| `core/src/bindings.zig` | Register handlers with webview |
| `core/src/main.zig` | Entry point |
| `core/tools/gen_types.zig` | Generate TypeScript from Zig types |
| `ui/src/generated/api.ts` | Generated TypeScript interfaces |
| `ui/src/native.ts` | Typed wrappers for window.* functions |

---

## IPC Summary

**webview/webview provides:**
- `webview_bind(name, callback, ctx)` → creates `window.name()` returning Promise
- `webview_return(id, status, json)` → resolves/rejects the Promise

**Data flow:**
```
JS: window.listDir("/home")
    → webview serializes args as JSON array: ["/home"]
    → callback(id, "[\"\/home\"]", ctx)
    → Zig parses JSON, does work, returns JSON
    → webview_return(id, 0, "[{...}]")
    → webview parses JSON, resolves Promise
JS: receives [{name: "...", ...}, ...]
```

**Binary data:** Base64 encode in JSON (or use data URLs for large files)

---

## Build Commands

```bash
cd core && zig build        # Build app
cd core && zig build run    # Run app

# Generate TypeScript types
zig run tools/gen_types.zig > ../ui/src/generated/api.ts

# UI development
cd ui && npm run dev
```

---

## Implementation Order

1. **Step 1-2**: Get webview compiling and showing a window
2. **Step 3-5**: Implement one handler (e.g., `showMessage`) end-to-end
3. **Step 6**: Wire up main.zig with UI loading
4. **Step 7-8**: Add TypeScript types and wrappers
5. **Iterate**: Add more handlers as needed
