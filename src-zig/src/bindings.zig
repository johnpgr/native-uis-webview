const handlers = @import("handlers.zig");
const WebView = @import("webview.zig");
const std = @import("std");

/// Command dispatch table - add new commands here
/// Format: .{ "commandName", handlerFn, .{ "arg1", "arg2", ... } }
const commands = .{
    .{ "readFile", handlers.readFile, .{"path"} },
    .{ "listDir", handlers.listDir, .{"path"} },
};

pub fn registerAll(webview: *const WebView, ctx: *handlers.GlobalContext) !void {
    try webview.bind("__invoke", invokeCallback, ctx);
}

fn invokeCallback(
    id: [*c]const u8,
    req: [*c]const u8,
    arg: ?*anyopaque,
) callconv(.c) void {
    const global_ctx: *handlers.GlobalContext = @ptrCast(@alignCast(arg));

    var arena = std.heap.ArenaAllocator.init(global_ctx.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const req_slice = std.mem.span(req);
    const parsed = std.json.parseFromSlice(std.json.Value, alloc, req_slice, .{}) catch |err| {
        returnError(global_ctx, alloc, id, @errorName(err));
        return;
    };
    defer parsed.deinit();

    const array = parsed.value.array.items;
    if (array.len < 2) {
        returnError(global_ctx, alloc, id, "InvalidRequest");
        return;
    }

    const command = array[0].string;
    const args = array[1];

    const req_ctx = handlers.RequestContext{
        .global = global_ctx,
        .arena = alloc,
    };

    const result = dispatch(req_ctx, command, args) catch |err| {
        returnError(global_ctx, alloc, id, @errorName(err));
        return;
    };

    global_ctx.webview.respond(id, 0, @ptrCast(result.ptr)) catch {};
}

/// Dispatch to handler based on command name
fn dispatch(ctx: handlers.RequestContext, command: []const u8, args: std.json.Value) ![]const u8 {
    inline for (commands) |entry| {
        if (std.mem.eql(u8, command, entry[0])) {
            return callHandler(entry[1], entry[2], ctx, args);
        }
    }
    return error.UnknownCommand;
}

/// Call a handler with arguments extracted from JSON using explicit arg names
fn callHandler(
    comptime handler: anytype,
    comptime arg_names: anytype,
    ctx: handlers.RequestContext,
    args: std.json.Value,
) ![]const u8 {
    const handler_args = try extractArgs(handler, arg_names, args);
    const result = try @call(.auto, handler, .{ctx} ++ handler_args);
    return try std.json.Stringify.valueAlloc(ctx.arena, result, .{});
}

/// Extract handler arguments from JSON using explicit arg names
fn extractArgs(
    comptime handler: anytype,
    comptime arg_names: anytype,
    args: std.json.Value,
) !ArgsTypes(handler) {
    const info = @typeInfo(@TypeOf(handler)).@"fn";
    const params = info.params[1..]; // Skip RequestContext

    var result: ArgsTypes(handler) = undefined;
    inline for (params, 0..) |param, i| {
        const field_name = arg_names[i];
        const json_val = args.object.get(field_name) orelse return error.MissingArgument;
        result[i] = try parseJsonValue(param.type.?, json_val);
    }
    return result;
}

fn parseJsonValue(comptime T: type, val: std.json.Value) !T {
    return switch (@typeInfo(T)) {
        .pointer => |p| if (p.size == .slice and p.child == u8) val.string else @compileError("Unsupported pointer type"),
        .int => @intCast(val.integer),
        .bool => val.bool,
        else => @compileError("Unsupported type"),
    };
}

fn ArgsTypes(comptime handler: anytype) type {
    const info = @typeInfo(@TypeOf(handler)).@"fn";
    const params = info.params[1..];
    var types: [params.len]type = undefined;
    for (params, 0..) |param, i| types[i] = param.type.?;
    return std.meta.Tuple(&types);
}

fn returnError(ctx: *handlers.GlobalContext, arena: std.mem.Allocator, id: [*c]const u8, msg: []const u8) void {
    const json = std.json.Stringify.valueAlloc(arena, .{ .@"error" = msg }, .{}) catch return;
    ctx.webview.respond(id, 1, @ptrCast(json.ptr)) catch {};
}
