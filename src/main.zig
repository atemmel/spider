const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));
const Browser = @import("browser.zig").Browser;

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    _ = ncurses.endwin();
    std.debug.print("{s}\n", .{msg});
    if (error_return_trace) |trace| {
        std.debug.dumpStackTrace(trace.*);
    }
    std.os.exit(0);
}

pub fn main() anyerror!void {
    const window = ncurses.initscr();
    if (window == null) {
        std.log.info("Aww man: {*}\n", .{window});
    }
    _ = ncurses.noecho();
    _ = ncurses.curs_set(0);
    _ = ncurses.start_color(); // TODO: Check for return
    _ = ncurses.init_pair(1, ncurses.COLOR_YELLOW, ncurses.COLOR_BLACK);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    //defer std.debug.assert(!gpa.deinit());
    var browser = try Browser.init(&ally);
    defer browser.deinit();

    while (true) {
        try browser.draw();
        const ch = ncurses.getch();
        if (!browser.update(ch)) {
            break;
        }
    }

    const result = ncurses.endwin();
    if (result != 0) {
        std.log.info("Aww man 2: {d}\n", .{result});
    }
}
