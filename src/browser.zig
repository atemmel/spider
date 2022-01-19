const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));

pub const Browser = struct {
    index: i32 = 0,
    cwdBuf: [std.fs.MAX_PATH_BYTES]u8 = undefined,
    cwd: []u8 = undefined,

    pub fn init(self: *Browser) !void {
        self.cwd = try std.os.getcwd(&self.cwdBuf);
    }

    pub fn draw(self: *Browser) void {
        self.printHeader();
        _ = ncurses.mvprintw(5, 5, "Toof");
    }

    fn printHeader(self: *Browser) void {
        var x = ncurses.getmaxx(ncurses.stdscr);
        var i: i32 = 0;
        while(i < x) : (i += 1) {
            _= ncurses.mvprintw(0, i, " ");
        }

        const cwd = @ptrCast([*c]const u8, self.cwd);
        _ = ncurses.attron(@as(c_int, ncurses.A_BOLD) | ncurses.COLOR_PAIR(1));
        _ = ncurses.mvprintw(0, 0, cwd);
        _ = ncurses.attroff(@as(c_int, ncurses.A_BOLD) | ncurses.COLOR_PAIR(1));
    }

    pub fn update(_: *Browser, key: i32) bool {
        switch(key) {
            // die
            4, 'q' => {
                return false;
            },
            ncurses.KEY_RIGHT, 'l' => {
                _ = ncurses.printw("right");
            },
            ncurses.KEY_LEFT, 'h' => {
                _ = ncurses.printw("left");
            },
            ncurses.KEY_UP, 'k' => {
                _ = ncurses.printw("up");
            },
            ncurses.KEY_DOWN, 'j' => {
                _ = ncurses.printw("down");
            },
            else => {},
        }
        return true;
    }
};
