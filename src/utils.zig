const std = @import("std");

pub fn clamp(value: i32, min: i32, max: i32) i32 {
    if (value < min) {
        return min;
    } else if (value > max) {
        return max;
    }
    return value;
}

pub fn caseInsensitiveComparison(lhs: []u8, rhs: []u8) bool {
    var i: usize = 0;
    while (i < lhs.len and i < rhs.len) : (i += 1) {
        const l = std.ascii.toUpper(lhs[i]);
        const r = std.ascii.toUpper(rhs[i]);
        if (l < r) {
            return true;
        } else if (l > r) {
            return false;
        }
    }
    return lhs.len < rhs.len;
}

pub fn sizeToString(ally: *std.mem.Allocator, sizeInBytes: u64) ![:0]u8 {
    const prefix = [_]*const [3:0]u8{
        "Byt",
        "KiB",
        "MiB",
        "GiB",
        "TiB",
    };

    var size = sizeInBytes;
    var remainder: u64 = 0;
    var index: usize = 0;

    while (size > 1024) {
        remainder = size & 1023;
        size >>= 10;
        index += 1;
    }

    var right = @intToFloat(f32, remainder);
    right /= 1024; // normalize
    right *= 10; // scale so that 0 < right < 10

    var buffer: [:0]u8 = undefined;

    if (right > 1) {
        buffer = try std.fmt.allocPrintZ(ally.*, "{d}.{d:.0}{s}", .{
            size,
            right,
            prefix[index],
        });
    } else {
        buffer = try std.fmt.allocPrintZ(ally.*, "{d}{s}", .{
            size,
            prefix[index],
        });
    }

    return buffer;
}
