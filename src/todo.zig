const std = @import("std");
const logo = @import("logo.zig");
const module = @import("module.zig");
const prompt = @import("prompt.zig");
const term = @import("term.zig");
const ui = @import("ui.zig");
const utils = @import("utils.zig");

pub const Todo = struct {
    const State = enum {
        ViewingCategories,
        ViewingCategory,
    };
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

    const TodoCategoryJson = struct {
        title: []const u8,
        todos: []TodoItem,
    };

    const TodoItems = std.ArrayList(TodoItem);
    const TodoCategories = std.ArrayList(TodoCategory);

    state: State = State.ViewingCategories,
    categories: TodoCategories = undefined,
    todoCategoryIndex: usize = undefined,
    todoIndex: usize = undefined,
    jsonPath: []const u8 = undefined,
    ally: std.mem.Allocator = undefined,

    fn clearCategories(self: *Todo) void {
        for (self.categories.items) |*cat| {
            for (cat.todos.items) |todo| {
                self.ally.free(todo.content);
            }
            self.ally.free(cat.title);
            cat.todos.clearAndFree();
        }
        self.categories.clearRetainingCapacity();
    }

    fn readTodoList(self: *Todo, from: []const u8) !void {
        var str = std.fs.cwd().readFileAlloc(self.ally, from, std.math.maxInt(usize)) catch {
            return;
        };
        defer self.ally.free(str);
        var parsedData = try std.json.parseFromSlice([]TodoCategoryJson, self.ally, str, .{});
        try self.categories.resize(parsedData.len);
        for (self.categories.items, 0..) |*cat, i| {
            cat.title = parsedData[i].title;
            cat.todos = TodoItems.fromOwnedSlice(self.ally, parsedData[i].todos);
        }
        self.ally.free(parsedData);
    }

    fn writeTodoList(self: *Todo) !void {
        var string = std.ArrayList(u8).init(self.ally);
        defer string.deinit();

        var categories = std.ArrayList(TodoCategoryJson).init(self.ally);
        defer categories.deinit();
        try categories.resize(self.categories.items.len);
        for (categories.items, 0..) |*cat, i| {
            cat.title = self.categories.items[i].title;
            cat.todos = self.categories.items[i].todos.items;
        }
        try std.json.stringify(categories.items, .{}, string.writer());
        try std.fs.cwd().writeFile(self.jsonPath, string.items);
    }

    pub fn init(ally: std.mem.Allocator, path: []const u8) !Todo {
        var todo = Todo{
            .ally = ally,
            .categories = TodoCategories.init(ally),
            .jsonPath = path,
            .todoCategoryIndex = 0,
            .todoIndex = 0,
        };
        try todo.readTodoList(path);
        return todo;
    }

    pub fn deinit(self: *Todo) void {
        self.clearCategories();
        for (self.categories.items) |*cat| {
            cat.todos.deinit();
        }
        self.categories.deinit();
    }

    pub fn draw(self: *Todo) void {
        term.erase();
        term.attrOn(term.color(2));
        logo.dumpCenter();
        term.attrOff(term.color(2));
        term.footer("todo");
        switch (self.state) {
            .ViewingCategories => self.drawCategoriesView(),
            .ViewingCategory => self.drawCategoryView(),
        }
    }

    fn drawCategoriesView(self: *Todo) void {
        var x: u32 = 2;
        var y: u32 = 2;
        for (self.categories.items, 0..) |*cat, i| {
            const bounds = categoryBounds(cat, x, y);

            if (bounds.y + bounds.h > term.getHeight()) {
                break;
            }

            drawCategory(cat, bounds, i == self.todoCategoryIndex);
            if (y == bounds.y) {
                x += max_grid_item_width + 2;
            } else {
                x = bounds.x + max_grid_item_width + 2;
                y = bounds.y;
            }
        }
    }

    fn drawCategoryView(self: *Todo) void {
        const cat = &self.categories.items[self.todoCategoryIndex];

        const title_x = 4;
        const title_y = 2;

        const list_begin_x = title_x;
        const list_begin_y = title_y + 2;

        // print title
        term.attrOn(term.bold);
        term.mvSlice(title_y, title_x, cat.title);
        term.attrOff(term.bold);

        for (cat.todos.items, 0..) |*todo, i| {
            if (i == self.todoIndex) {
                term.attrOn(term.color(1));
            }
            const y = @intCast(u32, list_begin_y + i);
            term.mvSlice(y, list_begin_x, "\u{2022}");
            term.mvSlice(y, list_begin_x + 2, todo.content);
            if (i == self.todoIndex) {
                term.attrOff(term.color(1));
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
        const w = max_grid_item_width;
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

    fn ellipsize(str: []const u8) u32 {
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
        var len = ellipsize(cat.title);
        var str = buffer[0..len];

        term.attrOn(term.bold);
        term.mvSlice(bounds.y + 1, bounds.x + 2, str);
        term.attrOff(term.bold);
        for (cat.todos.items, 0..) |*todo, j| {
            const i = @intCast(u32, j);
            len = ellipsize(todo.content);
            str = buffer[0..len];
            term.mvSlice(bounds.y + 3 + i, bounds.x + 2, str);
            if (i + max_grid_item_height - 1 > bounds.h) {
                break;
            }
        }
        term.attrOff(term.color(1));
    }

    fn move(self: *Todo, x: i32, y: i32) void {
        if (self.categories.items.len == 0) {
            return;
        }
        const bounds = calcGrid();
        const ideal = bounds.w * bounds.h;
        if (y < 0) { // down
            if (self.todoCategoryIndex + bounds.w < self.categories.items.len) {
                self.todoCategoryIndex += bounds.w;
            } else {
                self.todoCategoryIndex %= bounds.w;
            }
        } else if (y > 0) { // up
            if (@intCast(i32, self.todoCategoryIndex) - @intCast(i32, bounds.w) >= 0) {
                self.todoCategoryIndex -= bounds.w;
            } else {
                if (self.todoCategoryIndex < self.categories.items.len % bounds.w) {
                    self.todoCategoryIndex = ideal - bounds.w * 2 + self.todoCategoryIndex;
                } else {
                    self.todoCategoryIndex = self.categories.items.len - bounds.w - (self.categories.items.len % bounds.w) + self.todoCategoryIndex;
                }
            }
        }
        if (x > 0) { // right
            self.todoCategoryIndex += 1;
            if (self.todoCategoryIndex % bounds.w == 0 or self.todoCategoryIndex >= self.categories.items.len) {
                self.todoCategoryIndex -= bounds.w;
            }
        } else if (x < 0) { // left
            if (self.todoCategoryIndex % bounds.w == 0) {
                self.todoCategoryIndex += bounds.w;
            }
            self.todoCategoryIndex -= 1;
        }

        if (self.todoCategoryIndex >= self.categories.items.len) {
            self.todoCategoryIndex = self.categories.items.len - 1;
        }
    }

    fn calcGrid() Bounds {
        const w = (term.getWidth()) / (max_grid_item_width + 2);
        const h = (term.getHeight()) / (max_grid_item_height + 2);
        return Bounds{
            .x = 0,
            .y = 0,
            .w = w,
            .h = h,
        };
    }

    fn createCategory(self: *Todo) !void {
        var title = prompt.getString("Create new category: ");
        if (title == null) {
            return;
        }
        try self.categories.append(.{
            .title = try self.ally.dupe(u8, title.?[0..title.?.len]),
            .todos = TodoItems.init(self.ally),
        });
    }

    fn selectCategory(self: *Todo) void {
        if (self.todoCategoryIndex >= self.categories.items.len) {
            _ = prompt.get("No category selected!", "");
            return;
        }
        self.state = .ViewingCategory;
    }

    fn createTodo(self: *Todo) !void {
        var content = prompt.getString("Create new todo: ");
        if (content == null) {
            return;
        }
        var cat = &self.categories.items[self.todoCategoryIndex];
        try cat.todos.append(.{
            .content = try self.ally.dupe(u8, content.?[0..content.?.len]),
        });
    }

    fn deleteCategory(self: *Todo) void {
        if (self.categories.items.len == 0) {
            return;
        }

        const cat = &self.categories.items[self.todoCategoryIndex];
        for (cat.todos.items) |*todo| {
            self.ally.free(todo.content);
        }
        self.ally.free(cat.title);
        cat.todos.clearAndFree();
        _ = self.categories.orderedRemove(self.todoCategoryIndex);
        if (self.todoCategoryIndex >= self.categories.items.len) {
            if (self.todoCategoryIndex != 0) {
                self.todoCategoryIndex -= 1;
            }
        }
    }

    fn deleteTodo(self: *Todo) void {
        var cat = &self.categories.items[self.todoCategoryIndex];
        if (cat.todos.items.len == 0) {
            return;
        }

        self.ally.free(cat.todos.items[self.todoIndex].content);
        _ = cat.todos.orderedRemove(self.todoIndex);
        if (self.todoIndex >= cat.todos.items.len) {
            if (self.todoIndex != 0) {
                self.todoIndex -= 1;
            }
        }
    }

    fn renameCategory(self: *Todo) !void {
        if (self.categories.items.len == 0) {
            return;
        }

        const new_name = prompt.getString("Rename category: ");
        if (new_name == null) {
            return;
        }
        var cat = &self.categories.items[self.todoCategoryIndex];
        self.ally.free(cat.title);
        cat.title = try self.ally.dupe(u8, new_name.?[0..new_name.?.len]);
    }

    fn renameTodo(self: *Todo) !void {
        var cat = &self.categories.items[self.todoCategoryIndex];
        if (cat.todos.items.len == 0) {
            return;
        }

        const new_name = prompt.getString("Rename todo: ");
        if (new_name == null) {
            return;
        }
        var todo = &cat.todos.items[self.todoIndex];
        self.ally.free(todo.content);
        todo.content = try self.ally.dupe(u8, new_name.?[0..new_name.?.len]);
    }

    fn enterCategoriesView(self: *Todo) void {
        self.todoIndex = 0;
        self.state = .ViewingCategories;
    }

    fn nextCategory(self: *Todo) void {
        self.todoIndex = 0;
        self.todoCategoryIndex = utils.wrapRight(self.todoCategoryIndex, self.categories.items.len);
    }

    fn prevCategory(self: *Todo) void {
        self.todoIndex = 0;
        self.todoCategoryIndex = utils.wrapLeft(self.todoCategoryIndex, self.categories.items.len);
    }

    fn nextTodo(self: *Todo) void {
        const cat = &self.categories.items[self.todoCategoryIndex];
        self.todoIndex = utils.wrapRight(self.todoIndex, cat.todos.items.len);
    }

    fn prevTodo(self: *Todo) void {
        const cat = &self.categories.items[self.todoCategoryIndex];
        self.todoIndex = utils.wrapLeft(self.todoIndex, cat.todos.items.len);
    }

    pub fn update(self: *Todo, input: i32) !module.Result {
        switch (input) {
            term.Key.down, 'j' => { // down
                switch (self.state) {
                    .ViewingCategories => self.move(0, -1),
                    .ViewingCategory => self.nextTodo(),
                }
            },
            term.Key.up, 'k' => { // up
                switch (self.state) {
                    .ViewingCategories => self.move(0, 1),
                    .ViewingCategory => self.prevTodo(),
                }
            },
            term.Key.right, 'l' => { // right
                switch (self.state) {
                    .ViewingCategories => self.move(1, 0),
                    .ViewingCategory => self.nextCategory(),
                }
            },
            term.Key.left, 'h' => { // left
                switch (self.state) {
                    .ViewingCategories => self.move(-1, 0),
                    .ViewingCategory => self.prevCategory(),
                }
            },
            'c' => { // create
                switch (self.state) {
                    .ViewingCategories => try self.createCategory(),
                    .ViewingCategory => try self.createTodo(),
                }
            },
            'D' => { // delete
                switch (self.state) {
                    .ViewingCategories => self.deleteCategory(),
                    .ViewingCategory => self.deleteTodo(),
                }
            },
            'R' => { // rename
                switch (self.state) {
                    .ViewingCategories => try self.renameCategory(),
                    .ViewingCategory => try self.renameTodo(),
                }
            },
            term.Key.enter, term.Key.space => {
                self.selectCategory();
            },
            term.Key.eof, term.Key.esc, 'q' => {
                if (self.state == .ViewingCategory) {
                    self.enterCategoriesView();
                } else {
                    return module.Result{
                        .running = true,
                        .used_input = false,
                    };
                }
            },
            else => return module.Result{
                .running = true,
                .used_input = false,
            },
        }

        switch (input) {
            'c', 'D', 'R' => {
                self.writeTodoList() catch |err| {
                    _ = prompt.get(@errorName(err), "Could not save todo items: ");
                };
            },
            else => {},
        }
        return module.Result{
            .running = true,
            .used_input = true,
        };
    }
};
