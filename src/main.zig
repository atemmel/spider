const std = @import("std");
const term = @import("term.zig");
const Browser = @import("browser.zig").Browser;
const Todo = @import("todo.zig").Todo;
const utils = @import("utils.zig");
const config = @import("config.zig");
const consts = @import("consts.zig");
const Modules = @import("module.zig").Modules;
const Web = @import("web.zig").Web;

const assert = std.debug.assert;

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    term.disable();
    std.debug.panicImpl(error_return_trace, @returnAddress(), msg);
}

pub fn main() anyerror!void {
    const debug = std.debug.runtime_safety;

    var base_allocator = switch (debug) {
        true => std.heap.GeneralPurposeAllocator(.{}){},
        false => std.heap.page_allocator,
    };

    defer switch (debug) {
        true => std.debug.assert(base_allocator.deinit() == .ok),
        false => {},
    };

    var ally = switch (debug) {
        true => base_allocator.allocator(),
        false => std.heap.page_allocator,
    };

    try config.init(ally);
    defer config.deinit();

    const confPath = try consts.createDefaultConfigPath(ally);
    defer ally.free(confPath);
    try config.loadFile(confPath);

    try utils.createTodoDir(ally);
    const todoPath = try consts.createDefaultTodoPath(ally);
    defer ally.free(todoPath);

    var browser = Browser{};
    try browser.init(ally);
    defer browser.deinit();

    var todo = try Todo.init(ally, todoPath);
    defer todo.deinit();

    var web = try Web.init(ally);
    defer web.deinit();

    term.init();
    defer term.disable();

    var module = Modules.Browser;
    var running = true;

    while (running) {
        switch (module) {
            .Browser => browser.draw(),
            .Todo => todo.draw(),
            .Web => web.draw(),
        }

        const input: i32 = term.getChar();

        const output = switch (module) {
            .Browser => try browser.update(input),
            .Todo => try todo.update(input),
            .Web => web.update(input),
        };

        running = output.running;

        // if unused input
        if (!output.used_input) {
            module = switch (input) {
                'b' => Modules.Browser, // open browser
                't' => Modules.Todo, // open todo
                'w' => Modules.Web, // open web
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
    _ = @import("html.zig");
    _ = @import("http.zig");
    std.testing.refAllDecls(@This());
}
