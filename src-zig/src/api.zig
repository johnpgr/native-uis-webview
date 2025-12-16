pub const FileInfo = struct {
    name: []const u8,
    size: u64,
    is_dir: bool,
    modified: u64,
};

pub const Config = struct {
    theme: []const u8,
    font_size: u32,
    dark_mode: bool,
    recent_files: []const []const u8,
};

pub const DialogResult = union(enum) {
    cancelled: void,
    selected: []const []const u8,
};
