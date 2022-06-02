const std = @import("std");
const term = @import("term.zig");
const Browser = @import("browser.zig").Browser;
const Todo = @import("todo.zig").Todo;
const utils = @import("utils.zig");
const config = @import("config.zig");
const Modules = @import("module.zig").Modules;

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    term.disable();
    std.debug.panicImpl(error_return_trace, @returnAddress(), msg);
}

pub fn createDefaultConfigPath(ally: std.mem.Allocator) ![]u8 {
    return try utils.prependHomeAlloc(".config/spider/config.json", config.home, ally);
}

pub fn createDefaultTodoPath(ally: std.mem.Allocator) ![]u8 {
    return try utils.prependHomeAlloc(".local/spider/notes.json", config.home, ally);
}

pub fn createTodoDir(ally: std.mem.Allocator) !void {
    var local = try utils.prependHomeAlloc(".local", config.home, ally);
    defer ally.free(local);
    _ = std.fs.cwd().statFile(local) catch {
        try std.fs.makeDirAbsolute(local);
    };
    var spider = try utils.prependHomeAlloc(".local/spider", config.home, ally);
    defer ally.free(spider);
    _ = std.fs.cwd().statFile(spider) catch {
        try std.fs.makeDirAbsolute(spider);
    };
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    //defer std.debug.assert(!gpa.deinit());
    defer _ = gpa.deinit();

    config.init(ally);
    defer config.deinit();
    try config.loadEnv();

    const confPath = try createDefaultConfigPath(ally);
    defer ally.free(confPath);
    try config.loadFile(confPath);

    try createTodoDir(ally);

    const todoPath = try createDefaultTodoPath(ally);
    defer ally.free(todoPath);

    var browser: Browser = .{};
    try browser.init(ally);
    defer browser.deinit();

    var todo: Todo = .{};
    try todo.init(ally, todoPath);
    defer todo.deinit();

    term.init();
    defer term.disable();
    errdefer term.disable();

    var module = Modules.Browser;
    var running = true;

    while (running) {
        switch (module) {
            .Browser => browser.draw(),
            .Todo => todo.draw(),
        }

        const input: i32 = term.getChar();

        const output = switch (module) {
            .Browser => try browser.update(input),
            .Todo => try todo.update(input),
        };

        running = output.running;

        // if unused input
        if (!output.used_input) {
            module = switch (input) {
                't' => Modules.Todo, // open todo
                'b' => Modules.Browser, // open browser
                else => module,
            };
            running = switch (input) {
                'q', term.Key.eof => false, // exit
                else => true, // keep running
            };
        }
    }
}
