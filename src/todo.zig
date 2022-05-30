const std = @import("std");
const ModuleUpdateResult = @import("module.zig").ModuleUpdateResult;

pub const Todo = struct {
    pub const TodoItem = struct {
        priority: u32,
        origin: []const u8,
        line: u32,
    };

    const TodoItems = std.ArrayList(TodoItem);

    todos: TodoItems = undefined,
    ally: std.mem.Allocator = undefined,

    pub fn init(self: *Todo, ally: std.mem.Allocator) void {
        self.ally = ally;
        self.todos = TodoItems.init(ally);
    }

    pub fn deinit(self: *Todo) void {
        self.todos.deinit();
    }

    pub fn draw(self: *Todo) void {
        _ = self;
    }

    pub fn update(self: *Todo, input: i32) ModuleUpdateResult {
        _ = self;
        _ = input;
        return .{
            .running = false,
            .used_input = true,
        };
    }
};
