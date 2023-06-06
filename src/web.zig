const std = @import("std");
const module = @import("module.zig");

pub const Web = struct {
    pub fn init(ally: std.mem.Allocator) !Web {
        _ = ally;
        return Web{};
    }

    pub fn deinit(self: *Web) void {
        _ = self;
    }

    pub fn draw(self: *Web) void {
        _ = self;
    }

    pub fn update(self: *Web, input: i32) module.Result {
        _ = input;
        _ = self;
        return module.Result{
            .running = true,
            .used_input = true,
        };
    }
};
