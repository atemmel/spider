const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));

const maxPromptSize = 128;
var promptBuf: [maxPromptSize]u8 = undefined;
var prompt: []u8 = undefined;

fn clear(x: i32, y: i32) void {
    _ = ncurses.move(y - 1, 0);
    var i: i32 = 0;
    while(i < x) : (i += 1) {
        _ = ncurses.addch(' ');
    }
}

fn print(y: i32, value: []const u8, message: []const u8) void {
    const valueC = @ptrCast([*c]const u8, value);
    const messageC = @ptrCast([*c]const u8, message);
    _ = ncurses.mvprintw(y - 1, 0, "%s%s", messageC, valueC);
}

fn exit(x: i32, y: i32) void {
    clear(x, y);
    _ = ncurses.noecho();
    _ = ncurses.timeout(10);
}

pub fn getString(message: [:0]const u8) ?[]u8 {
    var x: i32 = undefined; 
    var y: i32 = undefined;
    var c: i32 = undefined;

    x = ncurses.getmaxx(ncurses.stdscr);
    y = ncurses.getmaxy(ncurses.stdscr);
    _ = ncurses.timeout(-1);

    clear(x, y);
    promptBuf[0] = 0;
    prompt = promptBuf[0..0];

    print(y, prompt, message);

    while(true) {
        c = ncurses.getch();

        switch(c) {
            '\t' => {
                continue;
            },
            127 => {  // backspce
                if(prompt.len > 0) {
                    prompt = promptBuf[0..prompt.len - 1];
                    promptBuf[prompt.len] = 0;
                }
            },
            27 => { // escape
                exit(x, y);
                return null;
            },
            '\n' => {   // return
                exit(x, y);
                return prompt;
            },
            else => {
                if(prompt.len < maxPromptSize) {
                    promptBuf[prompt.len] = @intCast(u8, c);
                    prompt = promptBuf[0..prompt.len + 1];
                    promptBuf[prompt.len] = 0;
                }
            },
        }

        clear(x, y);
        print(y, prompt, message);
    }

    unreachable;
}