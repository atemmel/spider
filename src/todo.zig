const std = @import("std");
const ModuleUpdateResult = @import("module.zig").ModuleUpdateResult;
const term = @import("term.zig");
const logo = @import("logo.zig");
const ui = @import("ui.zig");

pub const Todo = struct {
    pub const TodoItem = struct {
        //priority: u32,
        //origin: []const u8,
        //line: ?u32,
        content: []const u8,
    };

    pub const TodoCategory = struct {
        title: []const u8,
        todos: TodoItems,
    };

    const TodoItems = std.ArrayList(TodoItem);
    const TodoCategories = std.ArrayList(TodoCategory);

    categories: TodoCategories = undefined,
    todoCategoryIndex: usize = undefined,
    ally: std.mem.Allocator = undefined,

    pub fn init(self: *Todo, ally: std.mem.Allocator) !void {
        self.ally = ally;
        self.categories = TodoCategories.init(ally);
        self.todoCategoryIndex = 0;

        try self.categories.append(.{
            .title = "Todo category 1",
            .todos = TodoItems.init(ally),
        });

        try self.categories.items[0].todos.append(.{
            .content = "Do the gaming",
        });
        try self.categories.items[0].todos.append(.{
            .content = "Do more gaming",
        });
        try self.categories.items[0].todos.append(.{
            .content = "Do even more gaming (inspiring)",
        });
        try self.categories.items[0].todos.append(.{
            .content = "This gaming won't displaying",
        });

        try self.categories.append(.{
            .title = "Very cool long pog category by me",
            .todos = TodoItems.init(ally),
        });
    }

    pub fn deinit(self: *Todo) void {
        for (self.categories.items) |*cat| {
            cat.todos.deinit();
        }
        self.categories.deinit();
    }

    pub fn draw(self: *Todo) void {
        term.erase();
        logo.dumpCenter();
        var x: u32 = 2;
        var y: u32 = 2;
        for (self.categories.items) |*cat, i| {
            const bounds = categoryBounds(cat, x, y);
            drawCategory(cat, bounds, i == self.todoCategoryIndex);
            if (y == bounds.y) {
                x += max_grid_item_width + 2;
            } else {
                x = bounds.x;
                y = bounds.y;
            }

            if (y > term.getHeight()) {
                break;
            }
        }
    }

    const Bounds = struct {
        x: u32,
        y: u32,
        w: u32,
        h: u32,
    };

    const min_grid_item_height = 5;
    const max_grid_item_height = 8;
    const min_grid_item_width = 19;
    const max_grid_item_width = 33;

    fn categoryBounds(cat: *TodoCategory, x: u32, y: u32) Bounds {
        const proposed_grid_item_height = @intCast(u32, min_grid_item_height + cat.todos.items.len);
        const proposed_grid_item_width = @intCast(u32, min_grid_item_width + cat.title.len);

        const w = if (proposed_grid_item_width > max_grid_item_width) max_grid_item_width else proposed_grid_item_width;
        const h = if (proposed_grid_item_height > max_grid_item_height) max_grid_item_height else proposed_grid_item_height;

        var x_out = x;
        var y_out = y;

        if (x_out + w > term.getWidth()) {
            x_out = 2;
            y_out += max_grid_item_height + 2;
        }

        return .{
            .x = x_out,
            .y = y_out,
            .w = w,
            .h = h,
        };
    }

    var buffer: [max_grid_item_width - 4]u8 = undefined;

    fn ellipize(str: []const u8) u32 {
        if (buffer.len >= str.len) {
            std.mem.copy(u8, &buffer, str);
            return @intCast(u32, str.len);
        }
        std.mem.copy(u8, &buffer, str[0..buffer.len]);
        buffer[buffer.len - 3] = '.';
        buffer[buffer.len - 2] = '.';
        buffer[buffer.len - 1] = '.';
        return @intCast(u32, buffer.len);
    }

    fn drawCategory(cat: *TodoCategory, bounds: Bounds, focused: bool) void {
        if (focused) {
            term.attrOn(term.color(1));
        }
        ui.draw(bounds.x, bounds.y, bounds.w, bounds.h);
        var len = ellipize(cat.title);
        var str = buffer[0..len];

        term.attrOn(term.Bold);
        term.mvSlice(bounds.y + 1, bounds.x + 2, str);
        term.attrOff(term.Bold);
        for (cat.todos.items) |*todo, j| {
            const i = @intCast(u32, j);
            len = ellipize(todo.content);
            str = buffer[0..len];
            term.mvSlice(bounds.y + 3 + i, bounds.x + 2, str);
            if (i + max_grid_item_height - 1 > bounds.h) {
                break;
            }
        }
        term.attrOff(term.color(1));
    }

    pub fn update(self: *Todo, input: i32) ModuleUpdateResult {
        _ = self;
        _ = input;
        switch (input) {
            'q', 4 => return .{
                .running = false,
                .used_input = true,
            },
            else => return .{
                .running = true,
                .used_input = false,
            },
        }
        return .{
            .running = true,
            .used_input = true,
        };
    }
};
