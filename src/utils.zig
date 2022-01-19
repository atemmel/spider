const std = @import("std");

pub fn clamp(value: i32, min: i32, max: i32) i32 {
    if(value < min) {
        return min;
    } else if(value > max) {
        return max;
    }
    return value;
}

pub fn caseInsensitiveComparison(lhs: []u8, rhs: []u8) bool {
    var i: usize = 0;
    while(i < lhs.len and i < rhs.len) : (i += 1) {
        const l = std.ascii.toUpper(lhs[i]);
        const r = std.ascii.toUpper(rhs[i]);
        if(l < r) {
            return true;
        } else if(l > r) {
            return false;
        }
    }
    return lhs.len < rhs.len;
}
