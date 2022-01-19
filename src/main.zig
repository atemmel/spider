const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));
const Browser = @import("browser.zig").Browser;

pub fn main() anyerror!void {
    //std.log.info("All your codebase are belong to us.", .{});
    const window = ncurses.initscr();
    if(window == null) {
        std.log.info("Aww man: {*}\n", .{window});
    }
    _ = ncurses.noecho();
    _ = ncurses.curs_set(0);
    _ = ncurses.start_color();                            // TODO: Check for return
    _ = ncurses.init_pair(1, ncurses.COLOR_YELLOW, ncurses.COLOR_BLACK);

    var browser = Browser{};
    try browser.init();

    while(true) {
        browser.draw();
        const ch = ncurses.getch();
        if(!browser.update(ch)) {
            break;
        }
    }

    const result = ncurses.endwin();
    if(result != 0) {
        std.log.info("Aww man 2: {d}\n", .{result});
    }
}
