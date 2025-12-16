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

    var ctx = handlers.Context{
        .webview = &webview,
        .allocator = gpa.allocator(),
    };
    try bindings.registerAll(&webview, &ctx);

    try webview.setTitle("Native App");
    try webview.setSize(1024, 768);
    try webview.setHtml(html);
    try webview.run();
}
