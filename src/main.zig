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

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var ally = gpa.allocator();
    defer std.debug.assert(!gpa.deinit());

    config.init(ally);
    defer config.deinit();
    try config.loadEnv();

    const confPath = try createDefaultConfigPath(ally);
    defer ally.free(confPath);
    try config.loadFile(confPath);

    var browser: Browser = .{};
    try browser.init(ally);
    defer browser.deinit();

    var todo: Todo = .{};
    todo.init(ally);
    defer todo.deinit();

    term.init();

    //var module = Modules.Browser;
    var module = Modules.Todo;
    var running = true;

    while (running) {
        switch (module) {
            .Browser => browser.draw(),
            .Todo => todo.draw(),
        }

        const input: i32 = term.getChar();

        const output = switch (module) {
            .Browser => try browser.update(input),
            .Todo => todo.update(input),
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
                'q', 4 => false, // exit
                else => true, // keep running
            };
        }
    }

    term.disable();
}
