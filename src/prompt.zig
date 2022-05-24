const std = @import("std");
const term = @import("term.zig");

const maxPromptSize = 128;
var promptBuf: [maxPromptSize]u8 = undefined;
var prompt: [:0]u8 = undefined;

fn clear(x: u32, y: u32) void {
    term.move(y - 1, 0);

    var i: u32 = 0;
    while (i < x) : (i += 1) {
        term.addChar(' ');
    }
}

fn print(y: u32, value: [:0]const u8, message: [:0]const u8) void {
    term.mvprint(y - 1, 0, "%s%s", .{ message.ptr, value.ptr });
}

fn exit(x: u32, y: u32) void {
    clear(x, y);
    term.timeout(1000);
}

pub fn getString(message: [:0]const u8) ?[]u8 {
    var x: u32 = undefined;
    var y: u32 = undefined;
    var c: u32 = undefined;

    x = term.getWidth();
    y = term.getHeight();
    term.timeout(-1);

    clear(x, y);
    promptBuf[0] = 0;
    prompt = promptBuf[0..0 :0];

    print(y, prompt, message);

    while (true) {
        c = term.getChar();

        switch (c) {
            '\t' => {
                continue;
            },
            127 => { // backspce
                if (prompt.len > 0) {
                    prompt = promptBuf[0 .. prompt.len - 1 :0];
                    promptBuf[prompt.len] = 0;
                }
            },
            27 => { // escape
                exit(x, y);
                return null;
            },
            '\n' => { // return
                exit(x, y);
                if (prompt.len == 0) {
                    return null;
                }
                return prompt;
            },
            else => {
                if (prompt.len < maxPromptSize) {
                    promptBuf[prompt.len + 1] = 0;
                    promptBuf[prompt.len] = @intCast(u8, c);
                    prompt = promptBuf[0 .. prompt.len + 1 :0];
                }
            },
        }

        clear(x, y);
        print(y, prompt, message);
    }

    unreachable;
}

pub fn get(value: [:0]const u8, message: [:0]const u8) ?u32 {
    var x: u32 = undefined;
    var y: u32 = undefined;
    var c: u32 = undefined;

    x = term.getWidth();
    y = term.getHeight();
    term.timeout(-1);

    print(y, value, message);
    c = term.getChar();
    exit(x, y);

    if (c > 127) {
        return null;
    }

    return c;
}
