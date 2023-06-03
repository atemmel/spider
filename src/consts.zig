const std = @import("std");
const config = @import("config.zig");
const utils = @import("utils.zig");

pub const todo_dir = ".local/spider";
pub const todo_path = todo_dir ++ "/notes.json";

pub const config_dir = ".config/spider";
pub const config_path = config_dir ++ "/config.json";

pub fn createDefaultConfigPath(ally: std.mem.Allocator) ![]u8 {
    return try utils.prependHomeAlloc(config_dir, config.home, ally);
}

pub fn createDefaultTodoPath(ally: std.mem.Allocator) ![]u8 {
    return try utils.prependHomeAlloc(todo_path, config.home, ally);
}
