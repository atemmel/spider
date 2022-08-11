const std = @import("std");
const utils = @import("utils.zig");

pub var bookmarkPath: []u8 = undefined;
pub var opener: ?[:0]const u8 = null;
pub var shell: ?[:0]const u8 = null;
pub var openerEnv: ?[:0]const u8 = null;
pub var shellEnv: ?[:0]const u8 = null;
pub var home: []const u8 = "";
pub var drawBg: bool = false;

pub var ally: std.mem.Allocator = undefined;
pub var goodParse = true;
pub var binds: std.ArrayList(Bind) = undefined;

//TODO: Port this
//pub var editor: ?[:0]u8 = undefined;

pub const Bind = struct {
    key: i32,
    command: [:0]const u8,
};

pub fn init(allyo: std.mem.Allocator) void {
    ally = allyo;
    binds = std.ArrayList(Bind).init(ally);
}

pub fn deinit() void {
    if (openerEnv) |env| {
        ally.free(env);
    }
    if (shellEnv) |env| {
        ally.free(env);
    }
    if (opener) |env| {
        ally.free(env);
    }
    if (shell) |env| {
        ally.free(env);
    }
    ally.free(bookmarkPath);

    clearBinds();
    binds.deinit();
}

pub fn clearBinds() void {
    for (binds.items) |bind| {
        ally.free(bind.command);
    }
    binds.clearRetainingCapacity();
}

pub fn loadFile(path: []const u8) !void {
    var str = std.fs.cwd().readFileAlloc(ally, path, std.math.maxInt(usize)) catch {
        return;
    };
    defer ally.free(str);
    var parser = std.json.Parser.init(ally, false);
    defer parser.deinit();
    var tree = parser.parse(str) catch {
        goodParse = false;
        return;
    };
    defer tree.deinit();
    var root = tree.root;
    if (root.Object.get("shell")) |myShell| {
        shell = try ally.dupeZ(u8, myShell.String);
    }
    if (root.Object.get("opener")) |myOpener| {
        opener = try ally.dupeZ(u8, myOpener.String);
    }
    if (root.Object.get("drawBg")) |myDrawBg| {
        drawBg = myDrawBg.Bool;
    }

    if (root.Object.get("binds")) |myBinds| {
        var it = myBinds.Object.iterator();
        while (it.next()) |pair| {
            if (pair.key_ptr.len == 0) {
                continue;
            }
            const bind = Bind{
                .key = pair.key_ptr.*[0],
                .command = try ally.dupeZ(u8, pair.value_ptr.String),
            };

            try binds.append(bind);
        }
    }
}

pub fn loadEnv() !void {
    if (std.os.getenv("SPIDER-OPENER")) |env| {
        openerEnv = try ally.dupeZ(u8, env);
    }
    if (std.os.getenv("SHELL")) |env| {
        shellEnv = try ally.dupeZ(u8, env);
    }
    if (std.os.getenv("HOME")) |env| {
        home = env;
    }
    bookmarkPath = try utils.prependHomeAlloc(".spider-bookmarks", home, ally);
}
