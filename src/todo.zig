const std = @import("std");

pub const Todo = struct {
    pub const TodoItem = struct {
        priority: u32,
        origin: []const u8,
        line: u32,
    };

    const TodoItems = std.ArrayList(TodoItem);

    todos: TodoItems = .{},
    ally: std.mem.Allocator = undefined,

    pub fn init(self: *Todo, ally: std.mem.Allocator) void {
        self.ally = ally;
        self.todos = TodoItems.init(ally);
    }

    pub fn deinit(self: *Todo) void {
        self.todos.deinit();
    }
};
