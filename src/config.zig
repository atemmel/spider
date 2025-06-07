const std = @import("std");
const utils = @import("utils.zig");

pub var bookmarkPath: []u8 = undefined;
pub var shell: ?[:0]const u8 = null;
pub var home: []const u8 = "";
pub var drawBg: bool = false;

pub var ally: std.mem.Allocator = undefined;
pub var goodParse = true;
pub var binds: std.ArrayList(Bind) = undefined;

pub const Bind = struct {
    key: i32,
    command: [:0]const u8,
};

pub fn init(allyo: std.mem.Allocator) !void {
    ally = allyo;
    binds = std.ArrayList(Bind).init(ally);
    try loadEnv();
}

pub fn deinit() void {
    ally.free(bookmarkPath);

    clearBinds();
    binds.deinit();
    ally.free(home);
    if (shell) |s| {
        ally.free(s);
    }
}

pub fn clearBinds() void {
    for (binds.items) |bind| {
        ally.free(bind.command);
    }
    binds.clearRetainingCapacity();
}

pub fn loadFile(path: []const u8) !void {
    const str = std.fs.cwd().readFileAlloc(ally, path, std.math.maxInt(usize)) catch {
        return;
    };
    defer ally.free(str);

    var parsed = std.json.parseFromSlice(std.json.Value, ally, str, .{ .allocate = .alloc_if_needed }) catch {
        goodParse = false;
        return;
    };
    defer parsed.deinit();
    var root = parsed.value;

    if (root.object.get("drawBg")) |child| {
        drawBg = child.bool;
    }

    if (root.object.get("binds")) |child| {
        var it = child.object.iterator();
        while (it.next()) |item| {
            const key = item.key_ptr;
            if (key.len <= 0) {
                continue;
            }
            const command = item.value_ptr;
            try binds.append(Bind{
                .key = key.*[0],
                .command = try ally.dupeZ(u8, command.string),
            });
        }
    }
}

pub fn loadEnv() !void {
    if (std.posix.getenv("SHELL")) |env| {
        shell = env;
    }
    if (std.posix.getenv("HOME")) |env| {
        home = env;
    }
    bookmarkPath = try utils.prependHomeAlloc(".spider-bookmarks", home, ally);
}
