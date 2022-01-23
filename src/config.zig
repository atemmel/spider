const std = @import("std");
const utils = @import("utils.zig");

pub var bookmarkPath: []u8 = undefined;
pub var opener: ?[:0]const u8 = null;
pub var shell: ?[:0]const u8 = null;
pub var openerEnv: ?[:0]const u8 = null;
pub var shellEnv: ?[:0]const u8 = null;
pub var home: []const u8 = "" ;
pub var ally: std.mem.Allocator = undefined;

//TODO: Port this
//pub var editor: ?[:0]u8 = undefined;

pub const File = struct {
    opener: ?[]u8 = null,
    shell: ?[]u8 = null,
};

pub fn init(allyo: std.mem.Allocator) void {
    ally = allyo;
}

pub fn deinit() void {
    if(openerEnv) |env| {
        ally.free(env);
    }
    if(shellEnv) |env| {
        ally.free(env);
    }
    if(opener) |env| {
        ally.free(env);
    }
    if(shell) |env| {
        ally.free(env);
    }
    ally.free(bookmarkPath);
}

pub fn loadFile(path: []const u8) !void {
    var str = std.fs.cwd().readFileAlloc(ally, path, std.math.maxInt(usize)) catch {
        return;
    };
    defer ally.free(str);
    var jsonStream = std.json.TokenStream.init(str);
    var dummy: File = .{};
    dummy = try std.json.parse(File, &jsonStream, .{ .allocator = ally});
    defer std.json.parseFree(File, dummy, .{ .allocator = ally});

    if(dummy.opener) |set| {
        opener = try ally.dupeZ(u8, set);
    }
    if(dummy.shell) |set| {
        shell = try ally.dupeZ(u8, set);
    }
}

pub fn loadEnv() !void {
    if(std.os.getenv("SPIDER-OPENER")) |env| {
        openerEnv = try ally.dupeZ(u8, env);
    }
    if(std.os.getenv("SHELL")) |env| {
        shellEnv = try ally.dupeZ(u8, env);
    }
    if(std.os.getenv("HOME")) |env| {
        home = env;
    }
    bookmarkPath = try utils.prependHomeAlloc(".spider-bookmarks", home, ally);
}
