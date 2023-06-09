const std = @import("std");
const html = @import("html.zig");
const http = @import("http.zig");
const term = @import("term.zig");
const logo = @import("logo.zig");
const module = @import("module.zig");

pub const Web = struct {
    ally: std.mem.Allocator,
    root: html.Root,

    pub fn init(ally: std.mem.Allocator) !Web {
        const src = try http.get("https://www.wikipedia.org", ally);
        defer ally.free(src);
        return Web{
            .ally = ally,
            .root = try html.parse(ally, src),
        };
    }

    pub fn deinit(self: *Web) void {
        self.root.deinit();
    }

    pub fn draw(self: *Web) void {
        term.erase();
        term.attrOn(term.color(2));
        logo.dumpCenter();
        term.attrOff(term.color(2));
        term.footer("web");
        self.drawHtml();
    }

    fn drawHtml(self: *Web) void {
        const max_y = term.getHeight();
        var y: u32 = 0;
        for (self.root.elements) |node| {
            term.mvSlice(y, 0, "h:");
            term.mvSlice(y, 3, node.inner_html);
            y += 1;
            if (y >= max_y) {
                break;
            }
        }
    }

    pub fn update(self: *Web, input: i32) module.Result {
        _ = input;
        _ = self;
        return module.Result{
            .running = true,
            .used_input = false,
        };
    }
};
