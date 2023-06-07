const std = @import("std");
const c = @cImport({
    @cInclude("tidy.h");
    @cInclude("tidybuffio.h");
});

const assert = std.debug.assert;
const span = std.mem.span;
const eql = std.mem.eql;

const Allocator = std.mem.Allocator;

pub const Error = error{
    DomParseError,
    NameParseError,
    TitleParseError,
};

pub const Root = struct {
    pub const Node = struct {
        href: ?[]const u8,
        inner_html: []const u8,
    };

    ally: Allocator,
    elements: []const Node,
    title: ?[]const u8,

    pub fn deinit(self: *Root) void {
        if (self.title) |title| {
            self.ally.free(title);
        }
        for (self.elements) |element| {
            self.ally.free(element.inner_html);
        }
        self.ally.free(self.elements);
    }
};

const ParseCtx = struct {
    ally: Allocator,
    elements: std.ArrayList(Root.Node),
    enter_body: bool,
    title: ?[]const u8,
    doc: c.TidyDoc,
    node: c.TidyNode,
};

pub fn parse(ally: Allocator, html: [:0]const u8) !Root {
    var buffer = makeBuffer();
    defer c.tidyBufFree(&buffer);
    var doc = c.tidyCreate();
    defer c.tidyRelease(doc);

    _ = c.tidySetErrorBuffer(doc, &buffer);
    if (c.tidyParseString(doc, &html[0]) != 0) {
        return error.DomParseError;
    }

    var ctx = ParseCtx{
        .ally = ally,
        .elements = std.ArrayList(Root.Node).init(ally),
        .enter_body = false,
        .title = null,
        .doc = doc,
        .node = undefined,
    };

    var maybe_root = c.tidyGetRoot(doc);
    if (maybe_root) |root| {
        ctx.node = root;
        try parseHtml(&ctx);
    }

    return Root{
        .ally = ally,
        .elements = try ctx.elements.toOwnedSlice(),
        .title = ctx.title,
    };
}

fn parseHtml(ctx: *ParseCtx) !void {
    var child = c.tidyGetChild(ctx.node);
    while (child != null) {
        const name = c.tidyNodeGetName(child) orelse {
            return error.NameParseError;
        };
        const name_slice = span(name);
        if (eql(u8, "head", name_slice)) {
            try parseHead(ctx, child);
        } else if (eql(u8, "body", name_slice)) {
            try parseBody(ctx, child);
        } else if (eql(u8, "html", name_slice)) {
            child = c.tidyGetChild(child);
            continue;
        }
        child = c.tidyGetNext(child);
    }
}

fn parseHead(ctx: *ParseCtx, head: c.TidyNode) !void {
    var child = c.tidyGetChild(head);
    while (child != null) {
        defer child = c.tidyGetNext(child);
        const maybe_name = c.tidyNodeGetName(child);
        if (maybe_name) |name| {
            const name_slice = span(name);
            if (eql(u8, "title", name_slice)) {
                if (c.tidyGetChild(child)) |title_child| {
                    ctx.title = try parseInnerHtml(ctx, title_child);
                }
            }
        }
    }
}

fn parseInnerHtml(ctx: *ParseCtx, node: c.TidyNode) ![]u8 {
    var buffer = makeBuffer();
    defer c.tidyBufFree(&buffer);
    _ = c.tidyNodeGetText(ctx.doc, node, &buffer);
    return try dupeBuff(ctx.ally, buffer);
}

fn parseBody(ctx: *ParseCtx, body: c.TidyNode) !void {
    var child = c.tidyGetChild(body);
    while (child != null) {
        defer child = c.tidyGetNext(child);
        try parseBodyElement(ctx, child);
    }
}

fn parseBodyElement(ctx: *ParseCtx, parent: c.TidyNode) !void {
    var child = c.tidyGetChild(parent);
    while (child != null) {
        defer child = c.tidyGetNext(child);
        const maybe_name = c.tidyNodeGetName(child);
        if (maybe_name) |_| {
            try parseBodyElement(ctx, child);
        } else {
            const inner_html = try parseInnerHtml(ctx, child);
            try ctx.elements.append(.{
                .href = null,
                .inner_html = inner_html,
            });
        }
    }
}

fn parseTitle(ctx: *ParseCtx, doc: c.TidyDoc, node: c.TidyNode) !void {
    var child = c.tidyGetChild(node);
    var buffer = makeBuffer();
    defer c.tidyBufFree(&buffer);
    if (c.tidyNodeGetText(doc, child, &buffer) != 0) {
        return error.TitleParseError;
    }
    ctx.title = try dupeBuff(ctx.ally, buffer);
}

fn makeBuffer() c.TidyBuffer {
    var buffer: c.TidyBuffer = undefined;
    c.tidyBufInit(&buffer);
    return buffer;
}

fn dupeBuff(ally: Allocator, buffer: c.TidyBuffer) ![]u8 {
    assert(buffer.size > 0);
    const sentinel_slice = span(buffer.bp);
    const slice = std.mem.trimRight(u8, sentinel_slice, " \n\r\t");
    return try ally.dupe(u8, slice);
}

const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "html parse" {
    const html = @embedFile("resources/test.html");
    var tree = try parse(std.testing.allocator, html);
    defer tree.deinit();

    const elements = tree.elements;

    std.debug.print("title: {?s}\n", .{tree.title});
    for (elements) |e| {
        std.debug.print("inner_html: {s}\n", .{e.inner_html});
    }

    try expectEqual(true, tree.title != null);
    try expectEqualStrings("Cool title", tree.title.?);
    try expectEqual(@as(usize, 4), elements.len);
    try expectEqualStrings("The header", elements[0].inner_html);
    try expectEqualStrings("The paragraph", elements[1].inner_html);
    try expectEqualStrings("The other paragraph", elements[2].inner_html);
    try expectEqualStrings("To google", elements[3].inner_html);
}
