const builtin = @import("builtin");
const c = @import("c");
const std = @import("std");
const Webview = @import("webview.zig");
const config = @import("config");
const bindings = @import("bindings.zig");
const handlers = @import("handlers.zig");

const html = config.index_html ++ "\x00";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const webview = Webview.init(builtin.mode == .Debug) catch {
        std.debug.print("Failed to create webview\n", .{});
        return;
    };
    defer webview.destroy();

    var ctx = handlers.GlobalContext{
        .webview = &webview,
        .allocator = gpa.allocator(),
    };
    try bindings.registerAll(&webview, &ctx);

    try webview.setTitle("Native App");
    try webview.setSize(1024, 768);
    
    applyPlatformStyles(&webview);

    try webview.setHtml(html);
    try webview.run();
}

fn applyPlatformStyles(webview: *const Webview) void {
    if (webview.getWindow()) |handle| {
        _ = handle;
        switch (builtin.os.tag) {
            .linux => {
                // Linux (GTK)
                // handle is GtkWindow*
                // Example: Remove window decorations (frameless)
                // gtk_window_set_decorated(@ptrCast(handle), 0);
                
                // Example: Set default size via GTK if needed (though webview.setSize does this)
                // gtk_window_set_default_size(@ptrCast(handle), 1200, 800);
            },
            .windows => {
                // Windows (Win32)
                // handle is HWND
                // Example: Set specific window styles using SetWindowLongPtrA
            },
            .macos => {
                // macOS (Cocoa)
                // handle is NSWindow*
                // Example: Set style mask for transparent title bar
            },
            else => {},
        }
    }
}

// Platform-specific extern declarations
extern "c" fn gtk_window_set_decorated(window: *anyopaque, setting: c_int) void;
extern "c" fn gtk_window_set_resizable(window: *anyopaque, setting: c_int) void;