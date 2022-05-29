const std = @import("std");
const term = @import("term.zig");
const Browser = @import("browser.zig").Browser;
const utils = @import("utils.zig");
const config = @import("config.zig");

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    term.disable();
    std.debug.panicImpl(error_return_trace, @returnAddress(), msg);
}

pub fn createDefaultConfigPath(ally: std.mem.Allocator) ![]u8 {
    return try utils.prependHomeAlloc(".config/spider/config.json", config.home, ally);
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer std.debug.assert(!gpa.deinit());

    config.init(ally);
    defer config.deinit();
    try config.loadEnv();

    const confPath = try createDefaultConfigPath(ally);
    defer ally.free(confPath);
    try config.loadFile(confPath);

    var browser: Browser = .{};
    try browser.init(&ally);
    defer browser.deinit();

    term.init();

    while (true) {
        browser.draw();
        const ch: u32 = term.getChar();
        if (!try browser.update(ch)) {
            break;
        }
    }

    term.disable();
}
