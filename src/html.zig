const std = @import("std");
const c = @cImport({
    @cInclude("tidy.h");
    @cInclude("tidybuffio.h");
});

const assert = std.debug.assert;

const Allocator = std.mem.Allocator;

pub const Root = struct {
    pub const Node = struct {
        inner_html: ?[]const u8,
    };

    ally: Allocator,
    elements: []const Node,
    title: ?[]const u8,

    pub fn deinit(self: *Root) void {
        if (self.title) |title| {
            self.ally.free(title);
        }
        for (self.elements) |element| {
            if (element.inner_html) |inner_html| {
                self.ally.free(inner_html);
            }
        }
        self.ally.free(self.elements);
    }
};

const ParseCtx = struct {
    ally: Allocator,
    elements: std.ArrayList(Root.Node),
    title: ?[]const u8,
};

pub fn parse(ally: Allocator, html: [:0]const u8) !Root {
    var buffer = makeBuffer();
    defer c.tidyBufFree(&buffer);
    var doc = c.tidyCreate();
    defer c.tidyRelease(doc);

    _ = c.tidySetErrorBuffer(doc, &buffer);
    _ = c.tidyParseString(doc, &html[0]);

    var ctx = ParseCtx{
        .ally = ally,
        .elements = std.ArrayList(Root.Node).init(ally),
        .title = null,
    };

    var maybe_root = c.tidyGetRoot(doc);
    if (maybe_root) |root| {
        try parseRecurse(&ctx, doc, root);
    }

    return Root{
        .ally = ally,
        .elements = try ctx.elements.toOwnedSlice(),
        .title = ctx.title,
    };
}

fn parseRecurse(ctx: *ParseCtx, doc: c.TidyDoc, node: c.TidyNode) !void {
    var child = c.tidyGetChild(node);
    while (child != null) {
        defer child = c.tidyGetNext(child);
        var maybe_name = c.tidyNodeGetName(child);
        if (maybe_name) |name| {
            const name_slice = std.mem.span(name);
            if (ctx.title == null and std.mem.eql(u8, "title", name_slice)) {
                try parseTitle(ctx, doc, child);
                continue;
            }
            try ctx.elements.append(Root.Node{
                .inner_html = null,
            });
        } else {
            var buffer = makeBuffer();
            defer c.tidyBufFree(&buffer);
            _ = c.tidyNodeGetText(doc, child, &buffer);
            var elements = ctx.elements.items;
            elements[elements.len - 1].inner_html = try dupeZ(ctx.ally, buffer);
        }
        try parseRecurse(ctx, doc, child);
    }
}

fn parseTitle(ctx: *ParseCtx, doc: c.TidyDoc, node: c.TidyNode) !void {
    var child = c.tidyGetChild(node);
    var buffer = makeBuffer();
    defer c.tidyBufFree(&buffer);
    _ = c.tidyNodeGetText(doc, child, &buffer);
    ctx.title = try dupeZ(ctx.ally, buffer);
}

fn makeBuffer() c.TidyBuffer {
    var buffer: c.TidyBuffer = undefined;
    c.tidyBufInit(&buffer);
    return buffer;
}

fn dupeZ(ally: Allocator, buffer: c.TidyBuffer) ![]u8 {
    assert(buffer.size > 0);
    const sentinel_slice = std.mem.span(buffer.bp);
    const slice = std.mem.trimRight(u8, sentinel_slice, " \n\r\t");
    return try ally.dupe(u8, slice);
}

const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "html parse" {
    const html = @embedFile("resources/test.html");
    var tree = try parse(std.testing.allocator, html);
    defer tree.deinit();

    //std.debug.print("title: {?s}\n", .{tree.title});
    //for (tree.elements) |e| {
    //std.debug.print("inner_html: {?s}\n", .{e.inner_html});
    //}

    try expectEqual(true, tree.title != null);
    try expectEqualStrings("Cool title", tree.title.?);
}
