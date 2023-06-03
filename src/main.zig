const std = @import("std");
const term = @import("term.zig");
const Browser = @import("browser.zig").Browser;
const Todo = @import("todo.zig").Todo;
const utils = @import("utils.zig");
const config = @import("config.zig");
const consts = @import("consts.zig");
const Modules = @import("module.zig").Modules;

const assert = std.debug.assert;

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    term.disable();
    std.debug.panicImpl(error_return_trace, @returnAddress(), msg);
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer {
        assert(gpa.deinit() == .ok);
    }

    config.init(ally);
    defer config.deinit();
    try config.loadEnv();

    const confPath = try consts.createDefaultConfigPath(ally);
    defer ally.free(confPath);
    try config.loadFile(confPath);

    try utils.createTodoDir(ally);
    const todoPath = try consts.createDefaultTodoPath(ally);
    defer ally.free(todoPath);

    var browser: Browser = .{};
    try browser.init(ally);
    defer browser.deinit();

    var todo: Todo = .{};
    try todo.init(ally, todoPath);
    defer todo.deinit();

    term.init();
    defer term.disable();

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
                'b' => Modules.Browser, // open browser
                't' => Modules.Todo, // open todo
                else => module,
            };
            running = switch (input) {
                'q', term.Key.eof => false, // exit
                else => true, // keep running
            };
        }
    }
}

test {
    _ = @import("http.zig");
    std.testing.refAllDecls(@This());
}
