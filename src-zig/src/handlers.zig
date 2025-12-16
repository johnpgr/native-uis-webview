const std = @import("std");
const api = @import("api.zig");
const Webview = @import("webview.zig");

pub const Context = struct {
    webview: *const Webview,
    allocator: std.mem.Allocator,
};

pub fn readFile(ctx: *Context, id: [*c]const u8, args_json: []const u8) void {
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
    const encoded_len = std.base64.standard.Encoder.calcSize(content.len);
    const base64_buf = ctx.allocator.alloc(u8, encoded_len) catch {
        returnError(ctx, id, "OutOfMemory");
        return;
    };
    defer ctx.allocator.free(base64_buf);
    const base64 = std.base64.standard.Encoder.encode(base64_buf, content);

    const result = std.json.Stringify.valueAlloc(ctx.allocator, .{ .data = base64 }, .{}) catch return;
    defer ctx.allocator.free(result);

    ctx.webview.respond(id, 0, @ptrCast(result.ptr)) catch {};
}

pub fn listDir(ctx: *Context, id: [*c]const u8, args_json: []const u8) void {
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

    var files: std.ArrayListUnmanaged(api.FileInfo) = .empty;
    defer {
        for (files.items) |file| {
            ctx.allocator.free(file.name);
        }
        files.deinit(ctx.allocator);
    }

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        const name = ctx.allocator.dupe(u8, entry.name) catch continue;
        files.append(ctx.allocator, .{
            .name = name,
            .size = 0, // Would need stat
            .is_dir = entry.kind == .directory,
            .modified = 0,
        }) catch {
            ctx.allocator.free(name);
            continue;
        };
    }

    // Return as JSON
    const result = std.json.Stringify.valueAlloc(ctx.allocator, files.items, .{}) catch return;
    defer ctx.allocator.free(result);

    ctx.webview.respond(id, 0, @ptrCast(result.ptr)) catch {};
}

fn returnError(ctx: *Context, id: [*c]const u8, err: []const u8) void {
    const msg = std.json.Stringify.valueAlloc(ctx.allocator, .{ .@"error" = err }, .{}) catch return;
    defer ctx.allocator.free(msg);
    ctx.webview.respond(id, 1, @ptrCast(msg.ptr)) catch {};
}
