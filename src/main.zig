const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));
const Browser = @import("browser.zig").Browser;
const utils = @import("utils.zig");
const config = @import("config.zig");

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    _ = ncurses.endwin();
    std.debug.print("{s}\n", .{msg});
    if (error_return_trace) |trace| {
        std.debug.dumpStackTrace(trace.*);
    } else {
        std.debug.print("No trace lmao\n", .{});
    }
    std.os.exit(0);
}

pub fn initCurses() void {
    _ = ncurses.initscr();
    _ = ncurses.noecho();
    _ = ncurses.curs_set(0);
    _ = ncurses.start_color(); // TODO: Check for return
    _ = ncurses.init_pair(1, ncurses.COLOR_YELLOW, ncurses.COLOR_BLACK);
    _ = ncurses.keypad(ncurses.stdscr, true);
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

    initCurses();
    while (true) {
        browser.draw();
        const ch: i32 = ncurses.getch();
        if (!try browser.update(ch)) {
            break;
        }
    }

    _ = ncurses.endwin();
}
