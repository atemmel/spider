const std = @import("std");

pub fn clamp(value: i32, min: i32, max: i32) i32 {
    if (value < min) {
        return min;
    } else if (value > max) {
        return max;
    }
    return value;
}

pub fn caseInsensitiveComparison(lhs: []u8, rhs: []u8) bool {
    var i: usize = 0;
    while (i < lhs.len and i < rhs.len) : (i += 1) {
        const l = std.ascii.toUpper(lhs[i]);
        const r = std.ascii.toUpper(rhs[i]);
        if (l < r) {
            return true;
        } else if (l > r) {
            return false;
        }
    }
    return lhs.len < rhs.len;
}

pub fn sizeToString(ally: std.mem.Allocator, sizeInBytes: u64) ![:0]u8 {
    const prefix = [_]*const [3:0]u8{
        "Byt",
        "KiB",
        "MiB",
        "GiB",
        "TiB",
    };

    var size = sizeInBytes;
    var remainder: u64 = 0;
    var index: usize = 0;

    while (size > 1024) {
        remainder = size & 1023;
        size >>= 10;
        index += 1;
    }

    var right = @intToFloat(f32, remainder);
    right /= 1024; // normalize
    right *= 10; // scale so that 0 < right < 10

    var buffer: [:0]u8 = undefined;

    if (right > 1) {
        buffer = try std.fmt.allocPrintZ(ally, "{d}.{d:.0}{s}", .{
            size,
            right,
            prefix[index],
        });
    } else {
        buffer = try std.fmt.allocPrintZ(ally, "{d}{s}", .{
            size,
            prefix[index],
        });
    }

    return buffer;
}

pub fn spawn(what: [:0]const u8) !u32 {
    const pid = try std.os.fork();
    if (pid == 0) { // offspring
        const env = std.c.environ;
        const args = [_:null]?[*:0]const u8{ what, null };
        const argsSlice = args[0..];
        _ = std.os.execvpeZ(what, argsSlice, env) catch {};
        std.os.exit(127);
    } else { // parent
        const result = std.os.waitpid(pid, 0);
        return result.status;
    }
    unreachable;
}

pub fn spawnShCommand(what: [:0]const u8) !u32 {
    const pid = try std.os.fork();
    if (pid == 0) {
        const env = std.c.environ;
        const args = [_:null]?[*:0]const u8{ "sh", "-c", what, null };
        _ = std.os.execvpeZ("sh", &args, env) catch {};
        std.os.exit(127);
    } else {
        const result = std.os.waitpid(pid, 0);
        return result.status;
    }
    unreachable;
}

pub const CopyDirError = std.fs.Dir.StatError || std.fs.File.OpenError || std.os.MakeDirError || error{SystemResources} || std.os.CopyFileRangeError || std.os.SendFileError || error{RenameAcrossMountPoints};

pub fn copyDirAbsolute(from: []const u8, to: []const u8) CopyDirError!void {
    const lastSep = findLastSep(to);
    if (lastSep == null) {
        return error.BadPathName; // Not absolute
    }
    const toBase = to[0..lastSep.?];
    const toName = to[lastSep.? + 1 ..];

    // create target dir
    {
        var toBaseDir = try std.fs.openDirAbsolute(toBase, .{});
        errdefer toBaseDir.close();
        try std.os.mkdirat(toBaseDir.fd, toName, 0o755);
    }

    // open target dir
    var toDir = try std.fs.openDirAbsolute(to, .{});
    errdefer toDir.close();

    // begin iterating from source
    var fromDir = try std.fs.openIterableDirAbsolute(from, .{ .no_follow = true });
    errdefer fromDir.close();
    var it = fromDir.iterate();

    while (try it.next()) |entry| {
        try copyEntry(fromDir.dir, entry, toDir);
    }
}

fn copyEntry(from: std.fs.Dir, entry: std.fs.IterableDir.Entry, to: std.fs.Dir) CopyDirError!void {
    switch (entry.kind) {
        .File => try copyFileImpl(from, entry, to),
        .Directory => try copyDirImpl(from, entry, to),
        .SymLink => try copyFileImpl(from, entry, to),
        else => {},
    }
}

fn copyFileImpl(from: std.fs.Dir, entry: std.fs.IterableDir.Entry, to: std.fs.Dir) !void {
    try from.copyFile(entry.name, to, entry.name, .{});
}

fn copyDirImpl(from: std.fs.Dir, entry: std.fs.IterableDir.Entry, to: std.fs.Dir) CopyDirError!void {
    var fromDir = try from.openIterableDir(entry.name, .{ .no_follow = true });
    errdefer fromDir.close();

    try std.os.mkdirat(to.fd, entry.name, 0o755);
    var toDir = try to.openDir(entry.name, .{});
    errdefer toDir.close();

    var it = fromDir.iterate();
    while (try it.next()) |subEntry| {
        try copyEntry(fromDir.dir, subEntry, toDir);
    }
}

pub fn findLastSep(in: []const u8) ?usize {
    var i: usize = in.len - 1;
    while (i > 0 and in[i] != std.fs.path.sep) : (i -= 1) {}
    return if (i >= 0) i else null;
}

pub fn entryKindAbsolute(path: []const u8) !std.fs.File.Kind {
    const lastSep = findLastSep(path);
    if (lastSep == null) {
        return error.BadPathName;
    }
    const basePath = path[0..lastSep.?];
    const entryPath = path[lastSep.? + 1 ..];
    var dir = try std.fs.openDirAbsolute(basePath, .{});
    defer dir.close();
    const stat = try dir.statFile(entryPath);
    return stat.kind;
}

pub fn readFileOrCreateAlloc(path: []const u8, ally: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().createFile(path, .{
        .read = true,
        .truncate = false,
    });
    defer file.close();
    const contents = try file.reader().readAllAlloc(ally, std.math.maxInt(usize));
    return contents;
}

pub fn escapeHomeAlloc(original: []const u8, home: []const u8, ally: std.mem.Allocator) ![]u8 {
    if (original[0] == '~') {
        return prependHomeAlloc(original, home, ally);
    }
    return ally.dupe(original);
}

pub fn prependHomeAlloc(original: []const u8, home: []const u8, ally: std.mem.Allocator) ![]u8 {
    var totalLen = home.len + original.len + 1;
    var buf = try ally.alloc(u8, totalLen);
    std.mem.copy(u8, buf[0..], home);
    std.mem.copy(u8, buf[home.len + 1 ..], original);
    buf[home.len] = std.fs.path.sep;
    return buf;
}

pub fn splitLine(comptime str: []const u8) []const []const u8 {
    @setEvalBranchQuota(str.len * 4);
    var iter = std.mem.split(u8, str, "\n");
    var lines_split: []const []const u8 = &.{};
    while (iter.next()) |line| {
        lines_split = lines_split ++ [_][]const u8{line};
    }
    return lines_split;
}

pub fn wrapLeft(u: usize, max: usize) usize {
    if (u == 0) {
        return max - 1;
    }
    return u - 1;
}

pub fn wrapRight(u: usize, max: usize) usize {
    if (u + 1 >= max) {
        return 0;
    }
    return u + 1;
}
