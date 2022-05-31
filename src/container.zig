const term = @import("term.zig");

pub fn draw(x: u32, y: u32) void {
    term.mvprint(y, x, "─", .{});
}
