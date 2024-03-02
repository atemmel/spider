const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));
const c_locale = @cImport(@cInclude("locale.h"));

pub const reverse = ncurses.A_REVERSE;
pub const bold = ncurses.A_BOLD;

pub const Key = struct {
    pub const enter = 10;
    pub const space = ' ';
    pub const esc = 27;
    pub const eof = 4;

    pub const down = 259;
    pub const up = 258;
    pub const right = 261;
    pub const left = 260;
};

pub fn init() void {
    _ = c_locale.setlocale(c_locale.LC_ALL, "");
    enable();
    _ = ncurses.noecho();
    _ = ncurses.curs_set(0);
    _ = ncurses.start_color(); // TODO: Check for return
    _ = ncurses.init_pair(1, ncurses.COLOR_YELLOW, ncurses.COLOR_BLACK);
    _ = ncurses.init_pair(2, 8, ncurses.COLOR_BLACK);
    _ = ncurses.init_pair(3, 15, ncurses.COLOR_BLACK);
    _ = ncurses.keypad(ncurses.stdscr, true);
    timeout(1000);
}

pub fn enable() void {
    _ = ncurses.initscr();
}

pub fn disable() void {
    _ = ncurses.endwin();
}

pub fn color(id: u32) u32 {
    return @intCast(ncurses.COLOR_PAIR(@intCast(id)));
}

pub fn erase() void {
    _ = ncurses.erase();
}

pub fn getWidth() u32 {
    return @intCast(ncurses.getmaxx(ncurses.stdscr));
}

pub fn getHeight() u32 {
    return @intCast(ncurses.getmaxy(ncurses.stdscr));
}

pub fn attrOn(flags: u32) void {
    _ = ncurses.attron(@intCast(flags));
}

pub fn attrOff(flags: u32) void {
    _ = ncurses.attroff(@intCast(flags));
}

pub fn mvprintf(y: u32, x: u32, fmt: [*]const u8, args: anytype) void {
    const callargs = .{ @as(c_int, @intCast(y)), @as(c_int, @intCast(x)), fmt } ++ args;
    _ = @call(.auto, ncurses.mvprintw, callargs);
}

var mvprintBuf: [2048]u8 = undefined;

pub fn mvprint(y: u32, x: u32, comptime fmt: []const u8, args: anytype) void {
    const slice = std.fmt.bufPrint(&mvprintBuf, fmt, args) catch unreachable;
    mvSlice(y, x, slice);
}

pub fn move(y: u32, x: u32) void {
    _ = ncurses.move(@intCast(y), @intCast(x));
}

pub fn addChar(char: u8) void {
    _ = ncurses.addch(char);
}

pub fn mvSlice(y: u32, x: u32, str: []const u8) void {
    move(y, x);
    for (str) |char| {
        addChar(char);
    }
}

pub fn timeout(time: i32) void {
    _ = ncurses.timeout(time);
}

pub fn getChar() i32 {
    return @intCast(ncurses.getch());
}

pub fn footer(str: []const u8) void {
    const w = getWidth();
    const w2 = w / 2;
    const y = getHeight() - 1;
    const width2: u32 = @as(u32, @intCast(str.len)) / 2;

    attrOn(bold | color(1) | reverse);
    var i: u32 = 0;
    while (i < w) : (i += 1) {
        move(y, i);
        addChar(' ');
    }

    if (w2 >= width2) {
        mvSlice(y, w2 - width2, str);
    }

    attrOff(bold | color(1) | reverse);
}
