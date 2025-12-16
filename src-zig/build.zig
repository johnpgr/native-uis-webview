const std = @import("std");
const api = @import("src/api.zig");

const generated_types = generateTypes();

pub fn build(b: *std.Build) void {
    // Write generated TypeScript types
    const output_path = b.pathFromRoot("../src/generated/types.ts");
    std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = generated_types }) catch |err| {
        std.debug.panic("Failed to write types.ts: {s}", .{@errorName(err)});
    };
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const webview = b.dependency("webview", .{});

    // Translate C headers to a Zig module
    const c_translate = b.addTranslateC(.{
        .root_source_file = webview.path("core/include/webview.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const c_module = c_translate.createModule();

    // Embed index.html via build options
    const options = b.addOptions();
    const index_html_path = b.pathFromRoot("../dist/index.html");
    const index_html = std.fs.cwd().readFileAlloc(b.allocator, index_html_path, 50 * 1024 * 1024) catch |err| @panic(@errorName(err));
    options.addOption([]const u8, "index_html", index_html);

    const exe = b.addExecutable(.{
        .name = "native-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "c", .module = c_module },
            },
        }),
    });
    exe.root_module.addOptions("config", options);

    // Add webview C++ implementation
    exe.linkLibCpp();
    exe.root_module.addIncludePath(webview.path("core/include"));
    exe.root_module.addCSourceFile(.{
        .file = webview.path("core/src/webview.cc"),
        .flags = &.{ "-std=c++14", "-DWEBVIEW_STATIC" },
    });

    // Platform-specific linking
    switch (exe.rootModuleTarget().os.tag) {
        .macos => exe.linkFramework("WebKit"),
        .linux => {
            exe.linkSystemLibrary2("gtk+-3.0", .{ .use_pkg_config = .force });
            exe.linkSystemLibrary2("webkit2gtk-4.1", .{ .use_pkg_config = .force });
        },
        .windows => {
            exe.linkSystemLibrary("ole32");
            exe.linkSystemLibrary("version");
            exe.linkSystemLibrary("shlwapi");
        },
        else => {},
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn generateTypes() []const u8 {
    comptime {
        var result: []const u8 = "// AUTO-GENERATED - DO NOT EDIT\n\n";

        for (@typeInfo(api).@"struct".decls) |decl| {
            const T = @field(api, decl.name);
            if (@typeInfo(@TypeOf(T)) == .type) {
                result = result ++ emitType(decl.name, T);
            }
        }

        return result;
    }
}

fn emitType(name: []const u8, comptime T: type) []const u8 {
    const info = @typeInfo(T);

    return switch (info) {
        .@"struct" => |s| blk: {
            var result: []const u8 = "export interface " ++ name ++ " {\n";
            for (s.fields) |field| {
                result = result ++ "  " ++ field.name ++ ": " ++ zigTypeToTs(field.type) ++ ";\n";
            }
            break :blk result ++ "}\n\n";
        },
        .@"enum" => |e| blk: {
            var result: []const u8 = "export type " ++ name ++ " =\n";
            for (e.fields, 0..) |field, i| {
                result = result ++ "  | \"" ++ field.name ++ "\"";
                if (i < e.fields.len - 1) {
                    result = result ++ "\n";
                } else {
                    result = result ++ ";\n\n";
                }
            }
            break :blk result;
        },
        .@"union" => |u| blk: {
            var result: []const u8 = "export type " ++ name ++ " =\n";
            for (u.fields, 0..) |field, i| {
                result = result ++ "  | { type: \"" ++ field.name ++ "\"";
                if (field.type != void) {
                    result = result ++ "; value: " ++ zigTypeToTs(field.type);
                }
                result = result ++ " }";
                if (i < u.fields.len - 1) {
                    result = result ++ "\n";
                } else {
                    result = result ++ ";\n\n";
                }
            }
            break :blk result;
        },
        else => "",
    };
}

fn zigTypeToTs(comptime T: type) []const u8 {
    return switch (@typeInfo(T)) {
        .int, .comptime_int, .float, .comptime_float => "number",
        .bool => "boolean",
        .pointer => |p| if (p.size == .slice and p.child == u8)
            "string"
        else if (p.size == .slice)
            zigTypeToTs(p.child) ++ "[]"
        else
            "unknown",
        .optional => |o| zigTypeToTs(o.child) ++ " | null",
        .void => "void",
        else => "unknown",
    };
}
