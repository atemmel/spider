const utils = @import("utils.zig");
const term = @import("term.zig");

const logo_embed = @embedFile("../resources/logo.txt");
const logo_arr = utils.splitLine(logo_embed);
pub const height: u32 = logo_arr.len;
pub const width: u32 = logo_arr[0].len;

pub fn dump(y: u32, x: u32) void {
    for (logo_arr) |line, row| {
        term.mvSlice(y + @intCast(u32, row), x, line);
    }
}

pub fn dumpCenter() void {
    const w2 = term.getWidth() / 2;
    const h2 = term.getHeight() / 2;
    const height2 = height / 2;
    const width2 = width / 2;
    if (w2 < width2 or h2 < height2) {
        return;
    }
    dump(h2 - height2, w2 - width2);
}
