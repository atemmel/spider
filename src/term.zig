const ncurses = @cImport(@cInclude("ncurses.h"));

pub const Reverse = ncurses.A_REVERSE;
pub const Bold = ncurses.A_BOLD;

pub fn init() void {
    enable();
    _ = ncurses.noecho();
    _ = ncurses.curs_set(0);
    _ = ncurses.start_color(); // TODO: Check for return
    _ = ncurses.init_pair(1, ncurses.COLOR_YELLOW, ncurses.COLOR_BLACK);
    _ = ncurses.init_pair(2, 8, ncurses.COLOR_BLACK);
    _ = ncurses.init_pair(3, 15, ncurses.COLOR_BLACK);
    _ = ncurses.keypad(ncurses.stdscr, true);
}

pub fn enable() void {
    _ = ncurses.initscr();
}

pub fn disable() void {
    _ = ncurses.endwin();
}

pub fn color(id: u32) u32 {
    return @intCast(u32, ncurses.COLOR_PAIR(@intCast(c_int, id)));
}

pub fn erase() void {
    _ = ncurses.erase();
}

pub fn getWidth() u32 {
    return @intCast(u32, ncurses.getmaxx(ncurses.stdscr));
}

pub fn getHeight() u32 {
    return @intCast(u32, ncurses.getmaxy(ncurses.stdscr));
}

pub fn attrOn(flags: u32) void {
    _ = ncurses.attron(@intCast(c_int, flags));
}

pub fn attrOff(flags: u32) void {
    _ = ncurses.attroff(@intCast(c_int, flags));
}

pub fn mvprint(y: u32, x: u32, fmt: [*]const u8, args: anytype) void {
    const callargs = .{ @intCast(c_int, y), @intCast(c_int, x), fmt } ++ args;
    _ = @call(.{}, ncurses.mvprintw, callargs);
}

pub fn move(y: u32, x: u32) void {
    _ = ncurses.move(@intCast(c_int, y), @intCast(c_int, x));
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
    return @intCast(i32, ncurses.getch());
}

pub fn footer(str: []const u8) void {
    const w = getWidth();
    const w2 = w / 2;
    const y = getHeight() - 1;
    const width2: u32 = @intCast(u32, str.len) / 2;

    attrOn(Bold | color(1) | Reverse);
    var i: u32 = 0;
    while (i < w) : (i += 1) {
        move(y, i);
        addChar(' ');
    }

    if (w2 >= width2) {
        mvSlice(y, w2 - width2, str);
    }

    attrOff(Bold | color(1) | Reverse);
}
