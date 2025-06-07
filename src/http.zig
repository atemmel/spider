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
    const ctx = c.curl_easy_init() orelse @panic("Unable to init curl");
    defer c.curl_easy_cleanup(ctx);

    var data = CallbackData{
        .content = try std.ArrayList(u8).initCapacity(ally, 2048),
    };

    _ = c.curl_easy_setopt(ctx, c.CURLOPT_MAXREDIRS, @as(c_int, 50));
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_POSTFIELDSIZE, url.len);
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_TCP_KEEPALIVE, @as(c_int, 1));
    _ = c.curl_easy_setopt(ctx, c.CURLOPT_URL, &url[0]);
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
    var data: *CallbackData = @alignCast(@ptrCast(userp));
    const all = size * nmemb;
    const slice = contents[0..all];
    data.content.appendSlice(slice) catch unreachable;
    return all;
}

test "url get" {
    const data = try get("https://news.ycombinator.com/news", std.testing.allocator);
    defer std.testing.allocator.free(data);
    try std.testing.expect(data.len > 0);
}
