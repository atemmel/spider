const term = @import("term.zig");

const horizontal_line = "\u{2500}";
const vertical_line = "\u{2502}";

const up_left_corner = "\u{256D}";
const up_right_corner = "\u{256E}";

const down_right_corner = "\u{256F}";
const down_left_corner = "\u{2570}";

pub fn draw(x: u32, y: u32, w: u32, h: u32) void {
    var i: u32 = 0;
    while (i < w) : (i += 1) {
        var j: u32 = 0;
        while (j < h) : (j += 1) {
            term.mvprint(j + y, i + x, " ", .{});
        }
    }

    i = 1;
    while (i < w - 1) : (i += 1) {
        term.mvSlice(y, x + i, horizontal_line);
        term.mvSlice(y + h - 1, x + i, horizontal_line);
    }

    i = 1;
    while (i < h - 1) : (i += 1) {
        term.mvSlice(y + i, x, vertical_line);
        term.mvSlice(y + i, x + w - 1, vertical_line);
    }

    term.mvSlice(y, x, up_left_corner);
    term.mvSlice(y, x + w - 1, up_right_corner);
    term.mvSlice(y + h - 1, x, down_left_corner);
    term.mvSlice(y + h - 1, x + w - 1, down_right_corner);
}
