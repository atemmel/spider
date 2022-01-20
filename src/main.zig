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

pub fn initCurses() void {
    _ = ncurses.initscr();
    _ = ncurses.noecho();
    _ = ncurses.curs_set(0);
    _ = ncurses.start_color(); // TODO: Check for return
    _ = ncurses.init_pair(1, ncurses.COLOR_YELLOW, ncurses.COLOR_BLACK);
}

pub fn main() anyerror!void {
    initCurses();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer std.debug.assert(!gpa.deinit());
    var browser = try Browser.init(&ally);
    defer browser.deinit();

    while (true) {
        browser.draw();
        const ch = ncurses.getch();
        if (!try browser.update(ch)) {
            break;
        }
    }

    _ = ncurses.endwin();
}
