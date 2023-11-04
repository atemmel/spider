const std = @import("std");
const html = @import("html.zig");
const http = @import("http.zig");
const term = @import("term.zig");
const logo = @import("logo.zig");
const module = @import("module.zig");

pub const Web = struct {
    ally: std.mem.Allocator,
    root: ?html.Root,
    scroll_y: u32,

    pub fn init(ally: std.mem.Allocator) !Web {
        return Web{
            .ally = ally,
            .root = null,
            .scroll_y = 0,
        };
    }

    pub fn deinit(self: *Web) void {
        if (self.root) |*root| {
            root.deinit();
        }
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
        const max_y = term.getHeight() - 1;
        if (self.root) |*root| {
            var y: u32 = 0;
            const len = if (root.elements.len < max_y) root.elements.len else root.elements.len - max_y;
            const base_y: u32 = @intCast((@min(self.scroll_y, len)));
            while (y < max_y) {
                const cy = base_y + y;
                const node = root.elements[cy];
                term.mvSlice(y, 0, "h:");
                term.mvSlice(y, 3, node.inner_html);
                y += 1;
            }
        }
    }

    fn up(self: *Web) void {
        if (self.scroll_y > 0) {
            self.scroll_y -= 1;
        }
    }

    fn down(self: *Web) void {
        //TODO: if at bottom, should perhaps immediately jump up?
        if (self.root) |*root| {
            if (self.scroll_y < root.elements.len) {
                self.scroll_y += 1;
            }
        }
    }

    fn open(self: *Web, url: []const u8) !void {
        const src = try http.get(url, self.ally);
        defer self.ally.free(src);
        self.root = try html.parse(self.ally, src);
    }

    pub fn update(self: *Web, input: i32) module.Result {
        if (self.root == null) {
            self.open("https://www.wikipedia.org") catch unreachable;
        }
        switch (input) {
            'j' => self.down(),
            'k' => self.up(),
            else => return module.Result{
                .running = true,
                .used_input = false,
            },
        }
        return module.Result{
            .running = true,
            .used_input = true,
        };
    }
};
