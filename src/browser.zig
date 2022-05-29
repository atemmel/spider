const std = @import("std");
const term = @import("term.zig");
const utils = @import("utils.zig");
const prompt = @import("prompt.zig");
const config = @import("config.zig");
const logo = @import("logo.zig");

pub const Browser = struct {
    const FileEntry = struct {
        kind: std.fs.File.Kind,
        mode: std.fs.File.Mode,
        name: [:0]u8,
        size: u64,
        sizeStr: ?[:0]u8,
    };

    const Entries = std.ArrayList(FileEntry);
    const Marks = std.StringHashMap(void);
    const Bookmarks = std.StringHashMap(void);

    fn compByEntryKind(_: void, lhs: FileEntry, rhs: FileEntry) bool {
        if (rhs.kind == .Directory) {
            if (lhs.kind == .Directory) {
                return utils.caseInsensitiveComparison(lhs.name, rhs.name);
            } else {
                return false;
            }
        } else if (lhs.kind == .Directory) {
            return true;
        }
        return utils.caseInsensitiveComparison(lhs.name, rhs.name);
    }

    index: usize = 0,
    //TODO: These should be marked 0-terminated
    cwdBuf: [std.fs.MAX_PATH_BYTES + 1]u8 = undefined,
    cwd: []u8 = undefined,
    ally: *std.mem.Allocator = undefined,
    entries: Entries = undefined,
    marks: Marks = undefined,
    bookmarks: Bookmarks = undefined,

    pub fn init(browser: *Browser, ally: *std.mem.Allocator) !void {
        browser.ally = ally;
        browser.entries = Entries.init(ally.*);
        browser.marks = Marks.init(ally.*);
        browser.bookmarks = Bookmarks.init(ally.*);
        browser.cwd = try std.os.getcwd(&browser.cwdBuf);
        browser.cwdBuf[browser.cwd.len] = 0;

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
            if (e.sizeStr != null) {
                const ptr = e.sizeStr.?;
                self.ally.free(std.mem.span(ptr));
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
        var dir = try std.fs.openDirAbsolute(
            self.cwd,
            //.{ .iterate = true, .no_follow = true },
            .{ .iterate = true, .no_follow = false },
        );
        defer dir.close();

        self.clearEntries();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            var newEntry = FileEntry{
                .kind = entry.kind,
                .mode = undefined,
                .name = try self.ally.dupeZ(u8, entry.name),
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

        std.sort.sort(FileEntry, self.entries.items, {}, compByEntryKind);
        term.erase();
    }

    pub fn draw(self: *Browser) void {
        term.erase();
        term.attrOn(term.color(2));
        logo.dumpCenter();
        term.attrOff(term.color(2));
        self.printHeader();
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
            term.mvprint(0, i, " ", .{});
        }

        term.attrOn(term.Bold | term.color(1));
        term.mvprint(0, 0, self.cwd.ptr, .{});
        term.attrOff(term.Bold | term.color(1));
    }

    fn printDirs(self: *Browser) !void {
        const dirStr = "/  ";
        const lnStr = "~> ";
        const ox = 0;
        const oy = 1;
        const height = term.getHeight();

        var upperLimit = @intCast(i32, try std.math.absInt(@intCast(i64, self.entries.items.len) - @intCast(i64, @divFloor(height, 2))));
        var limit = @intCast(i32, @intCast(i64, oy + self.index) - @intCast(i64, @divFloor(height, 2)));

        if (self.entries.items.len < height - oy) {
            upperLimit = 0;
        }

        limit = utils.clamp(limit, 0, upperLimit);

        var i: usize = 0;
        self.cwdBuf[self.cwd.len] = std.fs.path.sep;

        while (i + @intCast(usize, limit) < self.entries.items.len) : (i += 1) {
            const current = i + @intCast(usize, limit);
            const entry = &self.entries.items[current];
            //TODO: shorten name here if appropriate
            const printedName = entry.name[0..];

            term.attrOff(term.Reverse);
            if (self.index == current) {
                term.attrOn(term.Reverse);
            }

            std.mem.copy(u8, self.cwdBuf[self.cwd.len + 1 ..], entry.name);
            const key = self.cwdBuf[0 .. self.cwd.len + 1 + entry.name.len];

            const mark = self.marks.get(key);
            const markStr = if (mark == null) "" else " ";

            term.attrOff(term.Bold);
            if (entry.kind == .Directory) {
                term.attrOn(term.Bold);
                term.mvprint(@intCast(u32, i + oy), ox, " %03o %10s %s%s ", .{ entry.mode & 0o0777, dirStr, markStr.ptr, printedName.ptr });
            } else if (entry.kind == .SymLink) {
                term.mvprint(@intCast(u32, i + oy), ox, " %03o %10s %s%s ", .{ entry.mode & 0o0777, lnStr, markStr.ptr, printedName.ptr });
            } else {
                if (entry.sizeStr) |size| {
                    term.mvprint(@intCast(u32, i + oy), ox, " %03o %10s %s%s ", .{ entry.mode & 0o0777, size.ptr, markStr.ptr, printedName.ptr });
                } else {
                    term.mvprint(@intCast(u32, i + oy), ox, " ??? %10s %s%s ", .{ "?  ", markStr.ptr, printedName.ptr });
                }
            }
        }
        self.cwdBuf[self.cwd.len] = 0;

        term.attrOff(term.Reverse);
        term.attrOff(term.Bold);
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

        try std.os.chdir(self.cwd);
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
        std.mem.copy(u8, remainder, entry.name);
        self.cwdBuf[newLen] = 0;
        self.cwd = self.cwdBuf[0..newLen];

        std.os.chdir(self.cwd) catch |err| {
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

        //if(self.index >= self.entries.items.len) {
        //self.index = self.entries.items.len - 1;
        //}
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
        std.os.mkdirat(dir.fd, str.?, 0o755) catch {}; //TODO: Be responsible
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
        if (entry.kind == .File) {
            try dir.deleteFile(entry.name);
        } else if (entry.kind == .Directory) {
            try dir.deleteTree(entry.name);
        }
    }

    fn deleteEntriesMarked(self: *Browser) !void {
        var promptStr = try std.fmt.allocPrintZ(self.ally.*, "Delete ({d}) marked entries? Y/N", .{
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
            var c = prompt.get(input[0..i :0], "Go:");

            if (c == null) {
                continue;
            }

            if (c.? == 127 and i > 0) { // backspace
                i -= 1;
                input[i] = 0;
            } else if (c.? == 27) { // escape
                break;
            } else if (std.ascii.isPrint(@intCast(u8, c.?))) {
                input[i] = @intCast(u8, c.?);
                i += 1;
                input[i] = 0;
            }

            for (self.entries.items) |_, index| {
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

        for (value) |char, index| {
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
        var entry = &self.entries.items[self.index];
        const totalLen = self.cwd.len + 1 + entry.name.len;

        // create mark
        var mark: []u8 = try self.ally.alloc(u8, totalLen);
        std.mem.copy(u8, mark, self.cwd);
        std.mem.copy(u8, mark[self.cwd.len + 1 ..], entry.name);
        mark[self.cwd.len] = std.fs.path.sep;

        // try to put mark
        var existing = self.marks.getKey(mark);
        if (existing == null) {
            try self.marks.put(mark, .{});
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
            std.mem.copy(u8, self.cwdBuf[self.cwd.len..], dirName);

            const from = mark;
            const to = self.cwdBuf[0 .. self.cwd.len + dirName.len];
            const kind = try utils.entryKindAbsolute(from);

            switch (kind) {
                .File => {
                    try self.copyFileMark(from, to);
                },
                .Directory => {
                    try self.copyDirMark(from, to);
                },
                .SymLink => {
                    try self.copyFileMark(from, to);
                },
                else => {
                    //TODO: Present error message (responsible)
                },
            }
        }
        self.cwdBuf[self.cwd.len] = 0;
    }

    fn copyFileMark(self: *Browser, from: []const u8, to: []const u8) !void {
        std.fs.copyFileAbsolute(from, to, .{}) catch |err| {
            var errStr = try std.fmt.allocPrintZ(self.ally.*, "{s}, {s}", .{
                from,
                @errorName(err),
            });
            defer self.ally.free(errStr);
            _ = prompt.get(errStr, "Could not copy file: ");
        };
    }

    fn copyDirMark(self: *Browser, from: []const u8, to: []const u8) !void {
        utils.copyDirAbsolute(from, to) catch |err| {
            var errStr = try std.fmt.allocPrintZ(self.ally.*, "{s}, {s}", .{
                from,
                @errorName(err),
            });
            defer self.ally.free(errStr);
            _ = prompt.get(errStr, "Could not copy directory: ");
        };
    }

    fn moveMarks(self: *Browser) !void {
        var to = std.fs.cwd();
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
        var bookmarksStr = try utils.readFileOrCreateAlloc(config.bookmarkPath, self.ally.*);
        defer self.ally.free(bookmarksStr);
        var it = std.mem.tokenize(u8, bookmarksStr, "\n");
        while (it.next()) |slice| {
            var bookmark = try self.ally.dupeZ(u8, slice);
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
            var newBookmark = try self.ally.dupeZ(u8, self.cwd);
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
            term.mvprint(y, 0, "%c %s", .{ 'a' + y, bookmark.ptr });
            y += 1;
        }

        var c = prompt.get("", "Select bookmark:");

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
        std.mem.copy(u8, self.cwdBuf[0..], newCwd);
        self.cwd = self.cwdBuf[0..newCwd.len];

        try std.os.chdir(self.cwd);
        self.index = 0;
    }

    fn startShell() void {
        const shell = config.shell orelse config.shellEnv orelse return;

        term.disable();
        const code = utils.spawn(shell) catch 128;
        term.enable();
        handleSpawnResult(code);
        //if(code == 128) {
        //_ = prompt.get("", "Unable to fork process!");
        //} else if(code != 0) {
        //_ = prompt.get("", "Unable to open shell!");
        //}
    }

    pub fn update(self: *Browser, key: u32) !bool {
        switch (key) {
            4, 'q' => { // die
                return false;
            },
            's' => { // open shell
                startShell();
            },
            259, 'k' => { // down
                if (self.entries.items.len > 0) {
                    if (self.index <= 0) {
                        self.index = self.entries.items.len - 1;
                    } else {
                        self.index -= 1;
                    }
                }
            },
            258, 'j' => { // up
                if (self.entries.items.len > 0) {
                    if (self.index >= self.entries.items.len - 1) {
                        self.index = 0;
                    } else {
                        self.index += 1;
                    }
                }
            },
            261, 'l' => { // right
                self.enterDir();
            },
            260, 'h' => { // left
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
            ' ' => { // mark/unmark
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
            'G' => {}, //TODO: Git mode(?)
            'm' => {
                self.clearMarks();
            },
            'a' => {}, //TODO: File info
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
                try self.checkBindings(key);
                // printf debugging :)))
                //_ = ncurses.mvprintw(20, 10, "%d", self.marks.count());
                //_ = ncurses.getch();
            },
        }
        return true;
    }

    fn showLogo(_: *Browser) void {
        term.erase();
        term.attrOn(term.color(3) | term.Bold);
        logo.dumpCenter();
        _ = term.getChar();
        term.attrOff(term.color(3) | term.Bold);
    }

    fn handleSpawnResult(code: u32) void {
        if (code == 128) {
            _ = prompt.get("", "Unable to fork process!");
        } else if (code != 0) {
            _ = prompt.get("", "Unable to open shell!");
        }
    }

    fn checkBindings(self: *Browser, key: u32) !void {
        for (config.binds.items) |bind| {
            if (bind.key == key) {
                try self.doBinding(bind);
                break;
            }
        }
    }

    fn doBinding(self: *Browser, bind: config.Bind) !void {
        const newSize = std.mem.replacementSize(u8, bind.command, "%F", self.cwd);
        var code: u32 = undefined;
        if (newSize == bind.command.len) {
            term.disable();
            code = utils.spawnShCommand(bind.command) catch 128;
            term.enable();
        } else {
            var newCommand = try self.ally.alloc(u8, newSize + 1);
            defer self.ally.free(newCommand);
            _ = std.mem.replace(u8, bind.command, "%F", self.cwd, newCommand);
            newCommand[newSize] = 0;
            term.disable();
            const slice = newCommand[0..newSize :0];
            code = utils.spawnShCommand(slice) catch 128;
            term.enable();
        }
        handleSpawnResult(code);
    }
};
