const handlers = @import("handlers.zig");
const WebView = @import("webview.zig");
const std = @import("std");

pub fn registerAll(webview: *const WebView, ctx: *handlers.Context) !void {
    try bindWrapped(webview, "readFile", handlers.readFile, ctx);
    try bindWrapped(webview, "listDir", handlers.listDir, ctx);
}

fn bindWrapped(
    webview: *const WebView,
    name: [*:0]const u8,
    comptime handler: anytype,
    ctx: *handlers.Context,
) !void {
    const Wrapper = struct {
        fn callback(id: [*c]const u8, req: [*c]const u8, arg: ?*anyopaque) callconv(.c) void {
            const context: *handlers.Context = @ptrCast(@alignCast(arg));

            // 1. Setup Arena (Request Scope)
            // This frees ALL memory allocated during the request (args, result strings, temp)
            var arena_impl = std.heap.ArenaAllocator.init(context.allocator);
            defer arena_impl.deinit();
            const arena = arena_impl.allocator();

            // 2. Parse Arguments
            const req_slice = std.mem.span(req);
            const ArgsTupleType = ArgsTypes(handler);

            const parsed = std.json.parseFromSlice(
                ArgsTupleType,
                arena,
                req_slice,
                .{},
            ) catch |err| {
                returnError(context, arena, id, @errorName(err));
                return;
            };
            defer parsed.deinit();

            // 3. Call Handler
            // Signature: fn(ctx, arena, arg1, arg2...) !Result
            const result = @call(.auto, handler, .{ context, arena } ++ parsed.value) catch |err| {
                returnError(context, arena, id, @errorName(err));
                return;
            };

            // 4. Serialize Result
            const result_json = std.json.Stringify.valueAlloc(arena, result, .{}) catch {
                returnError(context, arena, id, "SerializationError");
                return;
            };

            // 5. Respond Success
            context.webview.respond(id, 0, @ptrCast(result_json.ptr)) catch {};
        }
    };
    try webview.bind(name, Wrapper.callback, ctx);
}

fn returnError(ctx: *handlers.Context, arena: std.mem.Allocator, id: [*c]const u8, msg: []const u8) void {
    const json = std.json.Stringify.valueAlloc(arena, .{ .@"error" = msg }, .{}) catch return;
    ctx.webview.respond(id, 1, @ptrCast(json.ptr)) catch {};
}

fn ArgsTypes(comptime func: anytype) type {
    const info = @typeInfo(@TypeOf(func));
    const params = info.@"fn".params;
    if (params.len < 2) @compileError("Handler must accept at least (ctx, arena)");

    // Extract parameter types skipping the first 2 (ctx, arena)
    var types: [params.len - 2]type = undefined;
    for (params[2..], 0..) |param, i| {
        types[i] = param.type.?;
    }
    return std.meta.Tuple(&types);
}