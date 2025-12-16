const handlers = @import("handlers.zig");
const WebView = @import("webview.zig");
const std = @import("std");

pub fn registerAll(webview: *const WebView, ctx: *handlers.GlobalContext) !void {
    try bindWrapped(webview, "readFile", handlers.readFile, ctx);
    try bindWrapped(webview, "listDir", handlers.listDir, ctx);
}

fn bindWrapped(
    webview: *const WebView,
    name: [*:0]const u8,
    comptime handler: anytype,
    ctx: *handlers.GlobalContext,
) !void {
    const Wrapper = struct {
        fn callback(id: [*c]const u8, req: [*c]const u8, arg: ?*anyopaque) callconv(.c) void {
            const global_ctx: *handlers.GlobalContext = @ptrCast(@alignCast(arg));

            // 1. Setup Arena (Request Scope)
            var arena_impl = std.heap.ArenaAllocator.init(global_ctx.allocator);
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
                returnError(global_ctx, arena, id, @errorName(err));
                return;
            };
            defer parsed.deinit();

            // 3. Construct RequestContext
            const req_ctx = handlers.RequestContext{
                .global = global_ctx,
                .arena = arena,
            };

            // 4. Call Handler
            // Signature: fn(req_ctx, arg1, arg2...) !Result
            const result = @call(.auto, handler, .{ req_ctx } ++ parsed.value) catch |err| {
                returnError(global_ctx, arena, id, @errorName(err));
                return;
            };

            // 5. Serialize Result
            const result_json = std.json.Stringify.valueAlloc(arena, result, .{}) catch {
                returnError(global_ctx, arena, id, "SerializationError");
                return;
            };

            // 6. Respond Success
            global_ctx.webview.respond(id, 0, @ptrCast(result_json.ptr)) catch {};
        }
    };
    try webview.bind(name, Wrapper.callback, ctx);
}

fn returnError(ctx: *handlers.GlobalContext, arena: std.mem.Allocator, id: [*c]const u8, msg: []const u8) void {
    const json = std.json.Stringify.valueAlloc(arena, .{ .@"error" = msg }, .{}) catch return;
    ctx.webview.respond(id, 1, @ptrCast(json.ptr)) catch {};
}

fn ArgsTypes(comptime func: anytype) type {
    const info = @typeInfo(@TypeOf(func));
    const params = info.@"fn".params;
    if (params.len < 1) @compileError("Handler must accept at least (ctx)");

    // Extract parameter types skipping the first 1 (ctx)
    var types: [params.len - 1]type = undefined;
    for (params[1..], 0..) |param, i| {
        types[i] = param.type.?;
    }
    return std.meta.Tuple(&types);
}
