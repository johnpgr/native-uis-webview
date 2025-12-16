const std = @import("std");
const api = @import("api.zig");
const Webview = @import("webview.zig");

// Persistent application state
pub const GlobalContext = struct {
    webview: *const Webview,
    allocator: std.mem.Allocator,
};

// Per-request context
pub const RequestContext = struct {
    global: *GlobalContext,
    arena: std.mem.Allocator,
};

pub fn readFile(ctx: RequestContext, path: []const u8) !struct { data: []const u8 } {
    const arena = ctx.arena;
    
    // Read file
    const content = try std.fs.cwd().readFileAlloc(arena, path, 10 * 1024 * 1024);
    
    // Base64 encode
    const encoded_len = std.base64.standard.Encoder.calcSize(content.len);
    const base64_buf = try arena.alloc(u8, encoded_len);
    const base64 = std.base64.standard.Encoder.encode(base64_buf, content);

    return .{ .data = base64 };
}

pub fn listDir(ctx: RequestContext, path: []const u8) ![]api.FileInfo {
    const arena = ctx.arena;

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var files: std.ArrayListUnmanaged(api.FileInfo) = .empty;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        try files.append(arena, .{
            .name = try arena.dupe(u8, entry.name),
            .size = 0,
            .is_dir = entry.kind == .directory,
            .modified = 0,
        });
    }

    return files.items;
}
