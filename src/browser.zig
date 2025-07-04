const std = @import("std");
const term = @import("term.zig");
const utils = @import("utils.zig");
const prompt = @import("prompt.zig");
const config = @import("config.zig");
const logo = @import("logo.zig");
const module = @import("module.zig");

pub const Browser = struct {
    const FileEntry = struct {
        kind: std.fs.File.Kind,
        mode: std.fs.File.Mode,
        name: []u8,
        size: u64,
        sizeStr: ?[]u8,
    };

    const Entries = std.ArrayList(FileEntry);
    const Marks = std.StringHashMap(void);
    const Bookmarks = std.StringHashMap(void);

    fn compByEntryKind(_: void, lhs: FileEntry, rhs: FileEntry) bool {
        if (rhs.kind == .directory) {
            if (lhs.kind == .directory) {
                return utils.caseInsensitiveComparison(lhs.name, rhs.name);
            } else {
                return false;
            }
        } else if (lhs.kind == .directory) {
            return true;
        }
        return utils.caseInsensitiveComparison(lhs.name, rhs.name);
    }

    index: usize = 0,
    cwdBuf: [std.fs.max_path_bytes]u8 = undefined,
    cwd: []u8 = undefined,
    ally: std.mem.Allocator = undefined,
    entries: Entries = undefined,
    marks: Marks = undefined,
    bookmarks: Bookmarks = undefined,

    pub fn init(browser: *Browser, ally: std.mem.Allocator) !void {
        browser.ally = ally;
        browser.entries = Entries.init(ally);
        browser.marks = Marks.init(ally);
        browser.bookmarks = Bookmarks.init(ally);
        browser.cwd = try std.posix.getcwd(&browser.cwdBuf);

        try browser.loadBookmarks();
        try browser.fillEntries();
    }

    pub fn deinit(self: *Browser) void {
        self.clearEntries();
        self.entries.deinit();
        self.clearMarks();
        self.marks.deinit();
        self.clearBookmarks();
        self.bookmarks.deinit();
    }

    fn clearEntries(self: *Browser) void {
        for (self.entries.items) |e| {
            self.ally.free(e.name);
            if (e.sizeStr) |ptr| {
                self.ally.free(ptr);
            }
        }
        self.entries.clearRetainingCapacity();
    }

    fn clearMarks(self: *Browser) void {
        var it = self.marks.keyIterator();
        while (it.next()) |mark| {
            self.ally.free(mark.*);
        }
        self.marks.clearRetainingCapacity();
    }

    fn clearBookmarks(self: *Browser) void {
        var it = self.bookmarks.keyIterator();
        while (it.next()) |mark| {
            self.ally.free(mark.*);
        }
        self.bookmarks.clearRetainingCapacity();
    }

    fn fillEntries(self: *Browser) !void {
        var dir = try std.fs.openDirAbsolute(self.cwd, .{ .no_follow = true, .iterate = true });
        defer dir.close();

        self.clearEntries();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            var newEntry = FileEntry{
                .kind = entry.kind,
                .mode = undefined,
                .name = try self.ally.dupe(u8, entry.name),
                .size = undefined,
                .sizeStr = undefined,
            };
            errdefer self.ally.free(newEntry.name);

            const st = dir.statFile(entry.name) catch {
                newEntry.sizeStr = null;
                newEntry.size = 0;
                newEntry.mode = 0;
                try self.entries.append(newEntry);
                continue;
            };
            newEntry.size = st.size;
            newEntry.sizeStr = try utils.sizeToString(self.ally, st.size);
            newEntry.mode = st.mode;

            try self.entries.append(newEntry);
        }

        std.sort.pdq(FileEntry, self.entries.items, {}, compByEntryKind);
        term.erase();
    }

    pub fn draw(self: *Browser) void {
        term.erase();
        term.attrOn(term.color(2));
        logo.dumpCenter();
        term.attrOff(term.color(2));
        self.printHeader();
        term.footer("browser");
        self.printDirs() catch unreachable;

        if (!config.goodParse) {
            _ = prompt.get("", "Error: Could not parse config!");
            config.goodParse = true;
        }
    }

    fn printHeader(self: *Browser) void {
        const x = term.getWidth();
        var i: u32 = 0;
        while (i < x) : (i += 1) {
            term.mvSlice(0, i, " ");
        }

        term.attrOn(term.bold | term.color(1));
        term.mvSlice(0, 0, self.cwd);
        term.attrOff(term.bold | term.color(1));
    }

    fn printDirs(self: *Browser) !void {
        const dirStr = "/  ";
        const lnStr = "~> ";
        const ox = 0;
        const oy = 1;
        const height = term.getHeight() - 1;

        var upperLimit: i32 = @intCast(@abs((@as(i64, @intCast(self.entries.items.len)) - @as(i64, @intCast(@divFloor(height, 2))))));
        var limit: i32 = @intCast(@as(i64, @intCast(oy + self.index)) - @as(i64, @intCast(@divFloor(height, 2))));

        if (self.entries.items.len < height - oy) {
            upperLimit = 0;
        }

        limit = utils.clamp(limit, 0, upperLimit);

        var i: usize = 0;
        self.cwdBuf[self.cwd.len] = std.fs.path.sep;

        while (i + @as(usize, @intCast(limit)) < self.entries.items.len and i + oy < height) : (i += 1) {
            const current = i + @as(usize, @intCast(limit));
            const entry = &self.entries.items[current];
            //TODO: shorten name here if appropriate
            const printedName = entry.name[0..];

            term.attrOff(term.reverse);
            if (self.index == current) {
                term.attrOn(term.reverse);
            }

            std.mem.copyForwards(u8, self.cwdBuf[self.cwd.len + 1 ..], entry.name);
            const key = self.cwdBuf[0 .. self.cwd.len + 1 + entry.name.len];

            const mark = self.marks.get(key);
            const markStr = if (mark == null) "" else " ";
            const y: u32 = @as(u32, @intCast(i)) + oy;

            const fmt = " {o:03} {s:10} {s}{s} ";

            term.attrOff(term.bold);
            if (entry.kind == .directory) {
                term.attrOn(term.bold);
                term.mvprint(y, ox, fmt, .{ entry.mode & 0o0777, dirStr, markStr, printedName });
            } else if (entry.kind == .sym_link) {
                term.mvprint(y, ox, fmt, .{ entry.mode & 0o0777, lnStr, markStr, printedName });
            } else {
                if (entry.sizeStr) |size| {
                    term.mvprint(y, ox, fmt, .{ entry.mode & 0o0777, size, markStr, printedName });
                } else {
                    term.mvprint(y, ox, " ??? {s:10} {s}{s} ", .{ "?  ", markStr, printedName });
                }
            }
        }
        self.cwdBuf[self.cwd.len] = 0;

        term.attrOff(term.reverse);
        term.attrOff(term.bold);
    }

    fn exitDir(self: *Browser) !void {
        const lastIndex = std.mem.lastIndexOf(u8, self.cwd, &[1]u8{std.fs.path.sep});
        const firstIndex = std.mem.indexOf(u8, self.cwd, &[1]u8{std.fs.path.sep});
        if (lastIndex == null or firstIndex == null) {
            return;
        }

        if (lastIndex.? == firstIndex.?) {
            self.cwd = self.cwdBuf[0 .. lastIndex.? + 1];
        } else {
            self.cwd = self.cwdBuf[0..lastIndex.?];
        }
        self.cwdBuf[self.cwd.len] = 0;
        self.index = 0;

        try std.posix.chdir(self.cwd);
        try self.fillEntries();
    }

    fn enterDir(self: *Browser) void {
        const entry = &self.entries.items[self.index];
        var oldLen = self.cwd.len;
        var newLen = self.cwd.len + entry.name.len;

        if (self.cwdBuf[oldLen - 1] != std.fs.path.sep) {
            self.cwdBuf[oldLen] = std.fs.path.sep;
            newLen += 1;
            oldLen += 1;
        }
        const remainder = self.cwdBuf[oldLen..];
        std.mem.copyForwards(u8, remainder, entry.name);
        self.cwdBuf[newLen] = 0;
        self.cwd = self.cwdBuf[0..newLen];

        std.posix.chdir(self.cwd) catch |err| {
            _ = prompt.get(@errorName(err), "Could not enter dir: ");
            self.cwdBuf[oldLen] = 0;
            self.cwd = self.cwdBuf[0..oldLen];
            return;
        };

        self.fillEntries() catch |err| {
            _ = prompt.get(@errorName(err), "Could not read dir: ");
            self.cwdBuf[oldLen] = 0;
            self.cwd = self.cwdBuf[0..oldLen];
            return;
        };

        self.index = 0;
    }

    fn createFile(self: *Browser) !void {
        const str = prompt.getString("Name of file:");
        if (str == null) {
            return;
        }

        var dir = try std.fs.openDirAbsolute(self.cwd, .{});
        errdefer dir.close();
        var file = dir.createFile(str.?, .{ .exclusive = true }) catch {
            return;
        };
        defer file.close();
    }

    fn createDir(self: *Browser) !void {
        const str = prompt.getString("Name of folder:");
        if (str == null) {
            return;
        }

        var dir = try std.fs.openDirAbsolute(self.cwd, .{});
        defer dir.close();
        std.posix.mkdirat(dir.fd, str.?, 0o755) catch {}; //TODO: Be responsible
    }

    fn deleteEntry(self: *Browser) !void {
        if (self.marks.count() == 0) {
            try self.deleteEntryImpl();
        } else {
            try self.deleteEntriesMarked();
        }
    }

    fn deleteEntryImpl(self: *Browser) !void {
        const char = prompt.get("", "Delete entry? Y/N:");
        if (char == null or (char.? != 'y' and char.? != 'Y')) {
            return;
        }

        var dir = try std.fs.openDirAbsolute(self.cwd, .{});
        defer dir.close();

        const entry = self.entries.items[self.index];
        if (entry.kind == .file) {
            try dir.deleteFile(entry.name);
        } else if (entry.kind == .directory) {
            try dir.deleteTree(entry.name);
        }
    }

    fn deleteEntriesMarked(self: *Browser) !void {
        const promptStr = try std.fmt.allocPrint(self.ally, "Delete ({d}) marked entries? Y/N", .{
            self.marks.count(),
        });
        defer self.ally.free(promptStr);
        const char = prompt.get("", promptStr);

        if (char == null or (char.? != 'y' and char.? != 'Y')) {
            return;
        }

        var it = self.marks.keyIterator();
        while (it.next()) |markPtr| {
            const mark = markPtr.*;
            try std.fs.deleteTreeAbsolute(mark);
        }
        self.clearMarks();
    }

    fn findFile(self: *Browser) !void {
        var input: [128:0]u8 = undefined;
        var i: usize = 0;

        input[0] = 0;

        while (true) {
            const c = prompt.get(input[0..i :0], "Go:");

            if (c == null) {
                continue;
            }

            if (c.? == 263 and i > 0) { // backspace
                i -= 1;
                input[i] = 0;
            } else if (c.? == 27) { // escape
                break;
            } else if (std.ascii.isPrint(@intCast(c.?))) {
                input[i] = @intCast(c.?);
                i += 1;
                input[i] = 0;
            }

            for (self.entries.items, 0..) |_, index| {
                if (!self.entryStartsWith(index, input[0..i])) {
                    continue;
                }
                self.index = index;

                // if no more matching entries
                if (index + 1 >= self.entries.items.len or !self.entryStartsWith(index + 1, input[0..i])) {
                    self.enterDir();
                    return;
                }
                break;
            }

            self.printHeader();
            self.printDirs() catch unreachable;
        }
    }

    fn entryStartsWith(self: *Browser, entryIndex: usize, value: []const u8) bool {
        const entry = &self.entries.items[entryIndex];

        for (value, 0..) |char, index| {
            if (entry.name.len <= index or entry.name[index] != char) {
                return false;
            }
        }
        return true;
    }

    fn renameEntry(self: *Browser) !void {
        const str = prompt.getString("New name:");
        if (str == null) {
            return;
        }

        const entry = &self.entries.items[self.index];
        var dir = try std.fs.openDirAbsolute(self.cwd, .{});
        defer dir.close();
        dir.rename(entry.name, str.?) catch {};
    }

    fn addMark(self: *Browser) !void {
        const entry = &self.entries.items[self.index];
        const totalLen = self.cwd.len + 1 + entry.name.len;

        // create mark
        var mark: []u8 = try self.ally.alloc(u8, totalLen);
        std.mem.copyForwards(u8, mark, self.cwd);
        std.mem.copyForwards(u8, mark[self.cwd.len + 1 ..], entry.name);
        mark[self.cwd.len] = std.fs.path.sep;

        // try to put mark
        const existing = self.marks.getKey(mark);
        if (existing == null) {
            try self.marks.put(mark, undefined);
        } else { // remove mark
            _ = self.marks.remove(mark);
            self.ally.free(existing.?);
            self.ally.free(mark);
        }
    }

    fn copyMarks(self: *Browser) !void {
        var it = self.marks.keyIterator();
        self.cwdBuf[self.cwd.len] = std.fs.path.sep;
        while (it.next()) |markPtr| {
            const mark = markPtr.*;
            var i: usize = mark.len - 1;
            // find last sep
            while (mark[i] != std.fs.path.sep) : (i -= 1) {}
            const dirName = mark[i..];
            std.mem.copyForwards(u8, self.cwdBuf[self.cwd.len..], dirName);

            const from = mark;
            const to = self.cwdBuf[0 .. self.cwd.len + dirName.len];
            const kind = try utils.entryKindAbsolute(from);

            switch (kind) {
                .file => try self.copyFileMark(from, to),
                .directory => try self.copyDirMark(from, to),
                .sym_link => try self.copyFileMark(from, to),
                else => {
                    //TODO: Present error message (responsible)
                },
            }
        }
        self.cwdBuf[self.cwd.len] = 0;
    }

    fn copyFileMark(self: *Browser, from: []const u8, to: []const u8) !void {
        std.fs.copyFileAbsolute(from, to, .{}) catch |err| {
            const errStr = try std.fmt.allocPrint(self.ally, "{s}, {s}", .{
                from,
                @errorName(err),
            });
            defer self.ally.free(errStr);
            _ = prompt.get(errStr, "Could not copy file: ");
        };
    }

    fn copyDirMark(self: *Browser, from: []const u8, to: []const u8) !void {
        utils.copyDirAbsolute(from, to) catch |err| {
            const errStr = try std.fmt.allocPrint(self.ally, "{s}, {s}", .{
                from,
                @errorName(err),
            });
            defer self.ally.free(errStr);
            _ = prompt.get(errStr, "Could not copy directory: ");
        };
    }

    fn moveMarks(self: *Browser) !void {
        const to = std.fs.cwd();
        var it = self.marks.keyIterator();
        while (it.next()) |markPtr| {
            const mark = markPtr.*;
            const sep = utils.findLastSep(mark);
            if (sep == null) {
                continue;
            }

            const basePath = mark[0..sep.?];
            const filePath = mark[sep.? + 1 ..];
            var from = try std.fs.openDirAbsolute(basePath, .{});
            defer from.close();
            try std.fs.rename(from, filePath, to, filePath);
        }
    }

    fn loadBookmarks(self: *Browser) !void {
        self.clearBookmarks();
        const bookmarksStr = try utils.readFileOrCreateAlloc(config.bookmarkPath, self.ally);
        defer self.ally.free(bookmarksStr);
        var it = std.mem.tokenizeScalar(u8, bookmarksStr, '\n');
        while (it.next()) |slice| {
            const bookmark = try self.ally.dupe(u8, slice);
            try self.bookmarks.put(bookmark, void{});
        }
    }

    fn saveBookmarks(self: *Browser) !void {
        var file = try std.fs.cwd().createFile(config.bookmarkPath, .{});
        defer file.close();
        var it = self.bookmarks.keyIterator();
        while (it.next()) |slice| {
            try file.writer().writeAll(slice.*);
            try file.writer().writeByte('\n');
        }
    }

    fn addBookmark(self: *Browser) !void {
        try self.loadBookmarks();
        {
            const newBookmark = try self.ally.dupe(u8, self.cwd);
            errdefer self.ally.free(newBookmark);

            const existing = self.bookmarks.getKey(newBookmark);
            if (existing == null) {
                if (self.bookmarks.count() >= 'z' - 'a') {
                    _ = prompt.get("", "Cannot add more bookmarks!");
                    self.ally.free(newBookmark);
                } else {
                    try self.bookmarks.put(newBookmark, void{});
                    _ = prompt.get("", "Added bookmark!");
                }
            } else {
                _ = self.bookmarks.remove(newBookmark);
                self.ally.free(existing.?);
                self.ally.free(newBookmark);
                _ = prompt.get("", "Removed bookmark!");
            }
        }
        try self.saveBookmarks();
    }

    fn showBookmarks(self: *Browser) !void {
        var it = self.bookmarks.keyIterator();
        var y: u32 = 0;

        term.erase();

        while (it.next()) |bookmark| {
            term.move(y, 0);
            term.addChar(@intCast('a' + y));
            term.mvSlice(y, 2, bookmark.*);
            y += 1;
        }

        const c = prompt.get("", "Select bookmark:");

        if (c == null or c.? < 'a' or c.? > 'z') {
            return;
        }

        const ch = c.? - 'a';

        it = self.bookmarks.keyIterator();
        var i: i32 = 0;
        while (i < ch - 1) {
            _ = it.next();
            i += 1;
        }

        const key = it.next().?;

        self.setNewCwd(key.*) catch {
            _ = prompt.get(key.*[0.. :0], "Cannot go to ");
            return;
        };
        try self.fillEntries();
    }

    fn setNewCwd(self: *Browser, newCwd: []const u8) !void {
        self.cwdBuf[newCwd.len] = 0;
        std.mem.copyForwards(u8, self.cwdBuf[0..], newCwd);
        self.cwd = self.cwdBuf[0..newCwd.len];

        try std.posix.chdir(self.cwd);
        self.index = 0;
    }

    fn startShell() void {
        const shell = config.shell orelse return;

        term.disable();
        const code = utils.spawn(shell) catch 128;
        term.enable();
        handleSpawnResult(code);
    }

    pub fn update(self: *Browser, key: i32) !module.Result {
        switch (key) {
            's' => { // open shell
                startShell();
            },
            term.Key.down, 'k' => { // down
                if (self.entries.items.len > 0) {
                    if (self.index <= 0) {
                        self.index = self.entries.items.len - 1;
                    } else {
                        self.index -= 1;
                    }
                }
            },
            term.Key.up, 'j' => { // up
                if (self.entries.items.len > 0) {
                    if (self.index >= self.entries.items.len - 1) {
                        self.index = 0;
                    } else {
                        self.index += 1;
                    }
                }
            },
            term.Key.right, 'l' => { // right
                self.enterDir();
            },
            term.Key.left, 'h' => { // left
                try self.exitDir();
            },
            'c' => { // create file
                try self.createFile();
                try self.fillEntries();
            },
            'C' => { // create dir
                try self.createDir();
                try self.fillEntries();
            },
            'D' => { // delete
                try self.deleteEntry();
                try self.fillEntries();
            },
            'f' => { // find
                try self.findFile();
            },
            term.Key.space => { // mark/unmark
                try self.addMark();
                if (self.index < self.entries.items.len - 1) {
                    self.index += 1;
                }
                self.printDirs() catch unreachable;
            },
            'R' => { // rename
                try self.renameEntry();
                try self.fillEntries();
            },
            'm' => {
                self.clearMarks();
            },
            'p' => { // paste marks
                try self.copyMarks();
                self.clearMarks();
                try self.fillEntries();
            },
            'v' => { // move marks
                try self.moveMarks();
                self.clearMarks();
                try self.fillEntries();
            },
            'b' => { // add to bookmarks
                try self.addBookmark();
            },
            'g' => { // show all bookmarks
                try self.showBookmarks();
            },
            '?' => {
                self.showLogo();
            },
            else => {
                if (!try self.checkBindings(key)) {
                    return module.Result{
                        .running = true,
                        .used_input = false,
                    };
                }
            },
        }
        return module.Result{
            .running = true,
            .used_input = true,
        };
    }

    fn showLogo(_: *Browser) void {
        term.erase();
        term.attrOn(term.color(3) | term.bold);
        logo.dumpCenter();
        _ = term.getChar();
        term.attrOff(term.color(3) | term.bold);
    }

    fn handleSpawnResult(code: u32) void {
        if (code == 128) {
            _ = prompt.get("", "Unable to fork process!");
        } else if (code != 0) {
            _ = prompt.get("", "Unable to open shell!");
        }
    }

    fn checkBindings(self: *Browser, key: i32) !bool {
        for (config.binds.items) |bind| {
            if (bind.key == key) {
                try self.doBinding(bind);
                return true;
            }
        }
        return false;
    }

    fn doBinding(self: *Browser, bind: config.Bind) !void {
        const currentDirEscape = "%F";
        const newSize = std.mem.replacementSize(u8, bind.command, currentDirEscape, self.cwd);
        var code: u32 = undefined;
        if (newSize == bind.command.len) {
            term.disable();
            code = utils.spawnShCommand(bind.command) catch 128;
        } else {
            var newCommand = try self.ally.alloc(u8, newSize + 1);
            defer self.ally.free(newCommand);
            _ = std.mem.replace(u8, bind.command, currentDirEscape, self.cwd, newCommand);
            newCommand[newSize] = 0;
            term.disable();
            const slice = newCommand[0..newSize :0];
            code = utils.spawnShCommand(slice) catch 128;
        }
        term.enable();
        try self.fillEntries();
        handleSpawnResult(code);
    }
};
