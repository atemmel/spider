const std = @import("std");
const c = @cImport({
    @cInclude("curl/curl.h");
    @cInclude("tidy.h");
    @cInclude("tidybuffio.h");
});

const Allocator = std.mem.Allocator;

const CallbackData = struct {
    content: std.ArrayList(u8),
};

pub fn get(url: []const u8, ally: Allocator) ![:0]u8 {
    var ctx = c.curl_easy_init() orelse @panic("Unable to init curl");
    defer c.curl_easy_cleanup(ctx);

    var data = CallbackData{
        .content = try std.ArrayList(u8).initCapacity(ally, 2048),
    };

    _ = c.curl_easy_setopt(ctx, c.CURLOPT_MAXREDIRS, @as(c_int, 50));
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_TCP_KEEPALIVE, @as(c_int, 1));
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_URL, &url[0]);
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_POSTFIELDSIZE, url.len);
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_USERAGENT, "spider");
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_WRITEDATA, &data);
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_WRITEFUNCTION, curlWriteCallback);

    const res = c.curl_easy_perform(ctx);
    if (res != c.CURLE_OK) {
        @panic("Ooopsie");
    }
    try data.content.append(0);
    var slice = try data.content.toOwnedSlice();
    return slice[0 .. slice.len - 1 :0];
}

fn curlWriteCallback(
    contents: [*]const u8,
    size: c_uint,
    nmemb: c_uint,
    userp: *anyopaque,
) callconv(.C) c_uint {
    var data = @ptrCast(*CallbackData, @alignCast(@alignOf(CallbackData), userp));
    const all = size * nmemb;
    const slice = contents[0..all];
    data.content.appendSlice(slice) catch unreachable;
    return all;
}

pub fn getHtml(url: []const u8, ally: Allocator) !void {
    var data = try get(url, ally);
    defer ally.free(data);
    std.debug.print("len: {}\n", .{data.len});
    //std.debug.print("\n\n{s}\n", .{data});

    var error_buffer: c.TidyBuffer = .{
        .allocated = 0,
        .allocator = null,
        .bp = null,
        .next = 0,
        .size = 0,
    };
    defer c.tidyBufFree(&error_buffer);
    var doc = c.tidyCreate();
    defer c.tidyRelease(doc);

    _ = c.tidySetErrorBuffer(doc, &error_buffer);
    _ = c.tidyParseString(doc, &data[0]);

    var maybe_root = c.tidyGetRoot(doc);
    if (maybe_root) |root| {
        visit(doc, root, 0);
    }
}

fn visit(doc: c.TidyDoc, node: c.TidyNode, depth: usize) void {
    var name = (c.tidyNodeGetName(node));
    if (name != null) {
        pad(depth);
        std.debug.print("{s}\n", .{name});
    }
    var child = c.tidyGetChild(node);
    while (child != null) {
        pad(depth);
        var child_name = c.tidyNodeGetName(child);
        if (child_name != null) {
            std.debug.print("{s}\n", .{child_name});
        } else {
            var buffer: c.TidyBuffer = .{
                .allocated = 0,
                .allocator = null,
                .bp = null,
                .next = 0,
                .size = 0,
            };
            c.tidyBufInit(&buffer);
            _ = c.tidyNodeGetText(doc, child, &buffer);
            std.debug.print("{s}\n", .{buffer.bp});
        }
        visit(doc, child, depth + 1);
        child = c.tidyGetNext(child);
    }
}

fn pad(depth: usize) void {
    var i: usize = 0;
    while (i < depth) : (i += 1) {
        std.debug.print("  ", .{});
    }
}

test "url get" {
    try getHtml("https://news.ycombinator.com/news", std.testing.allocator);
}
