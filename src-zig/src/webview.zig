/// A Zig wrapper around the C webview library.
const c = @import("c");
const std = @import("std");

pub const WebviewError = error{
    WebviewFailed,
};

const Self = @This();

handle: c.webview_t,

pub fn init(debug: bool) WebviewError!Self {
    const handle = c.webview_create(@intFromBool(debug), null) orelse return WebviewError.WebviewFailed;

    return .{
        .handle = handle,
    };
}

pub fn destroy(self: *const Self) void {
    const result = c.webview_destroy(self.handle);
    if (result != 0) {
        std.debug.print("Failed to destroy webview\n", .{});
    }
}

pub fn setTitle(self: *const Self, title: [*:0]const u8) WebviewError!void {
    const result = c.webview_set_title(self.handle, title);
    if (result != 0) {
        return WebviewError.WebviewFailed;
    }
}

pub fn setSize(self: *const Self, width: i32, height: i32) WebviewError!void {
    const result = c.webview_set_size(self.handle, width, height, c.WEBVIEW_HINT_NONE);
    if (result != 0) {
        return WebviewError.WebviewFailed;
    }
}

pub fn setHtml(self: *const Self, html: [*:0]const u8) WebviewError!void {
    const result = c.webview_set_html(self.handle, html);
    if (result != 0) {
        return WebviewError.WebviewFailed;
    }
}

pub fn navigate(self: *const Self, url: [*:0]const u8) WebviewError!void {
    const result = c.webview_navigate(self.handle, url);
    if (result != 0) {
        return WebviewError.WebviewFailed;
    }
}

pub fn run(self: *const Self) WebviewError!void {
    const result = c.webview_run(self.handle);
    if (result != 0) {
        return WebviewError.WebviewFailed;
    }
}

pub fn eval(self: *const Self, js: [*:0]const u8) WebviewError!void {
    const result = c.webview_eval(self.handle, js);
    if (result != 0) {
        return WebviewError.WebviewFailed;
    }
}

pub fn bind(
    self: *const Self,
    name: [*:0]const u8,
    callback: *const fn ([*c]const u8, [*c]const u8, ?*anyopaque) callconv(.c) void,
    ctx: ?*anyopaque,
) WebviewError!void {
    const result = c.webview_bind(self.handle, name, callback, ctx);
    if (result != 0) {
        return WebviewError.WebviewFailed;
    }
}

pub fn respond(self: *const Self, id: [*c]const u8, status: i32, result: [*c]const u8) WebviewError!void {
    const res = c.webview_return(self.handle, id, status, result);
    if (res != 0) {
        return WebviewError.WebviewFailed;
    }
}
