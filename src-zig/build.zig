const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "native-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Add webview C library
    const webview = b.dependency("webview", .{});
    exe.linkLibCpp();
    exe.root_module.addIncludePath(webview.path("core/include"));
    exe.root_module.addCSourceFile(.{
        .file = webview.path("core/src/webview.cc"),
        .flags = &.{ "-std=c++14", "-DWEBVIEW_STATIC" },
    });

    // Embed index.html via build options
    const options = b.addOptions();
    const index_html_path = b.pathFromRoot("../dist/index.html");
    const index_html = std.fs.cwd().readFileAlloc(b.allocator, index_html_path, 50 * 1024 * 1024) catch |err| @panic(@errorName(err));
    options.addOption([]const u8, "index_html", index_html);
    exe.root_module.addOptions("config", options);

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
