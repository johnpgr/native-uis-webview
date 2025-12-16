const std = @import("std");

pub fn build(b: *std.Build) void {
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
