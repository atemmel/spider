const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));
const utils = @import("utils.zig");
const prompt = @import("prompt.zig");

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

    pub fn init(browser: *Browser, ally: *std.mem.Allocator) !void {
        browser.ally = ally;
        browser.entries = Entries.init(ally.*);
        browser.marks = Marks.init(ally.*);
        browser.cwd = try std.os.getcwd(&browser.cwdBuf);
        browser.cwdBuf[browser.cwd.len] = 0;
        try browser.fillEntries();
    }

    pub fn deinit(self: *Browser) void {
        self.clearEntries();
        self.entries.deinit();
        self.clearMarks();
        self.marks.deinit();
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
        while(it.next()) |mark| {
            self.ally.free(mark.*);
        }
        self.marks.clearRetainingCapacity();
    }

    fn fillEntries(self: *Browser) !void {
        self.clearEntries();

        var dir = try std.fs.openDirAbsolute(
            self.cwd,
            .{ .iterate = true, .no_follow = true },
        );
        defer dir.close();

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
        _ = ncurses.erase();
    }

    pub fn draw(self: *Browser) void {
        _ = ncurses.erase();
        self.printHeader();
        self.printDirs() catch unreachable;
    }

    fn printHeader(self: *Browser) void {
        var x = ncurses.getmaxx(ncurses.stdscr);
        var i: i32 = 0;
        while (i < x) : (i += 1) {
            _ = ncurses.mvprintw(0, i, " ");
        }

        _ = ncurses.attron(@as(c_int, ncurses.A_BOLD) | ncurses.COLOR_PAIR(1));
        _ = ncurses.mvprintw(0, 0, self.cwd.ptr);
        _ = ncurses.attroff(@as(c_int, ncurses.A_BOLD) | ncurses.COLOR_PAIR(1));
    }

    fn printDirs(self: *Browser) !void {
        const dirStr = "/  ";
        const lnStr = "~> ";
        const ox = 0;
        const oy = 1;
        const height = @intCast(i32, ncurses.getmaxy(ncurses.stdscr));

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

            _ = ncurses.attroff(ncurses.A_REVERSE);
            if (self.index == current) {
                _ = ncurses.attron(ncurses.A_REVERSE);
            }

            std.mem.copy(u8, self.cwdBuf[self.cwd.len + 1..], entry.name);
            const key = self.cwdBuf[0..self.cwd.len + 1 + entry.name.len];

            const mark = self.marks.get(key);
            const markStr = if(mark == null) "" else " ";

            _ = ncurses.attroff(ncurses.A_BOLD);
            if (entry.kind == .Directory) {
                _ = ncurses.attron(ncurses.A_BOLD);
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %03o %10s %s%s ",
                        entry.mode & 0o0777,
                        dirStr, 
                        markStr.ptr,
                        printedName.ptr);
            } else if (entry.kind == .SymLink) {
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %03o %10s %s%s ",
                        entry.mode & 0o0777,
                        lnStr, 
                        markStr.ptr,
                        printedName.ptr);
            } else {
                if(entry.sizeStr) |size| {
                    _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %03o %10s %s%s ",
                            entry.mode & 0o0777,
                            size.ptr,
                            markStr.ptr,
                            printedName.ptr);
                } else {
                    _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " ??? %10s %s%s ", 
                            "?  ", 
                            markStr.ptr, 
                            printedName.ptr);
                }
            }
        }
        self.cwdBuf[self.cwd.len] = 0;

        _ = ncurses.attroff(ncurses.A_REVERSE);
        _ = ncurses.attroff(ncurses.A_BOLD);
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
        const oldLen = self.cwd.len;
        var newLen = self.cwd.len + entry.name.len;
        if(self.cwdBuf[self.cwd.len] != std.fs.path.sep) {
            self.cwdBuf[self.cwd.len] = std.fs.path.sep;
            newLen += 1;
        }
        var remainder = self.cwdBuf[self.cwd.len + 1..];
        std.mem.copy(u8, remainder, entry.name);
        self.cwdBuf[newLen] = 0;
        self.cwd = self.cwdBuf[0..newLen];

        std.os.chdir(self.cwd) catch {
            self.cwdBuf[oldLen] = 0;
            self.cwd = self.cwdBuf[0..oldLen];
            return;
        };

        self.fillEntries() catch {
            self.cwdBuf[oldLen] = 0;
            self.cwd = self.cwdBuf[0..oldLen];
        };

        //if(self.index >= self.entries.items.len) {
            //self.index = self.entries.items.len - 1;
        //}
        self.index = 0;
    }

    fn createFile(self: *Browser) !void {
        const str = prompt.getString("Name of file:");
        if(str == null) {
            return;
        }

        var dir = try std.fs.openDirAbsolute(self.cwd, .{});
        errdefer dir.close();
        var file = dir.createFile(str.?, .{.exclusive = true}) catch {
            return;
        };
        defer file.close();
    }

    fn createFolder(self: *Browser) !void {
        const str = prompt.getString("Name of folder:");
        if(str == null) {
            return;
        }

        var dir = try std.fs.openDirAbsolute(self.cwd, .{});
        defer dir.close();
        std.os.mkdirat(dir.fd, str.?, 0o755) catch {};  //TODO: Be responsible
    }

    fn deleteEntry(self: *Browser) !void {
        const char = prompt.get("", "Delete entry? Y/N:");
        if(char == null or (char.? != 'y' and char.? != 'Y')) {
            return;
        }

        var dir = try std.fs.openDirAbsolute(self.cwd, .{});
        defer dir.close();

        const entry = self.entries.items[self.index];
        if(entry.kind == .File) {
            try dir.deleteFile(entry.name);
        } else if(entry.kind == .Directory) {
            try dir.deleteDir(entry.name);
        }
    }

    fn findFile(self: *Browser) !void {
        var input: [128:0]u8 = undefined;
        var i: usize = 0;

        input[0] = 0;

        while(true) {
            var c = prompt.get(input[0..i:0], "Go:");

            if(c == null) {
                continue;
            }

            if(c.? == 127 and i > 0) {    // backspace
                i -= 1;
                input[i] = 0;
            } else if(c.? == 27) {    // escape
                break;
            } else if(std.ascii.isPrint(@intCast(u8, c.?))) {
                input[i] = @intCast(u8, c.?);
                i += 1;
                input[i] = 0;
            }

            for(self.entries.items) |_, index| {
                if(!self.entryStartsWith(index, input[0..i])) {
                    continue;
                }

                // if no more matching entries
                if(index + 1 >= self.entries.items.len or !self.entryStartsWith(index + 1, input[0..i])) {
                    self.index = index;
                    self.enterDir();
                    return;
                }
                break;
            }

            self.printHeader();
            try self.printDirs();
        }
    }

    fn entryStartsWith(self: *Browser, entryIndex: usize, value: []const u8) bool {
        const entry = &self.entries.items[entryIndex];

        for(value) |char, index| {
            if(entry.name.len <= index or entry.name[index] != char) {
                return false;
            }
        }
        return true;
    }

    fn renameEntry(self: *Browser) !void {
        const str = prompt.getString("New name:");
        if(str == null) {
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
        std.mem.copy(u8, mark[self.cwd.len+1..], entry.name);
        mark[self.cwd.len] = std.fs.path.sep;

        // try to put mark
        var existing = self.marks.getKey(mark);
        if(existing == null) {
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
        while(it.next()) |markPtr| {
            const mark = markPtr.*;
            var i: usize = mark.len - 1;
            // find last sep
            while(mark[i] != std.fs.path.sep) : (i -= 1) {}
            const dirName = mark[i..];
            std.mem.copy(u8, self.cwdBuf[self.cwd.len..], dirName);

            const from = mark;
            const to = self.cwdBuf[0..self.cwd.len + dirName.len];


            const kind = try utils.entryKindAbsolute(from);
            switch(kind) {
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
                }
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
            _ = prompt.get(errStr, "Could not copy file: ");
            self.ally.free(errStr);
        };
    }

    fn copyDirMark(self: *Browser, from: []const u8, to: []const u8) !void {
        utils.copyDirAbsolute(from, to) catch |err| {
            var errStr = try std.fmt.allocPrintZ(self.ally.*, "{s}, {s}", .{
                from,
                @errorName(err),
            });
            _ = prompt.get(errStr, "Could not copy directory: ");
            self.ally.free(errStr);
        };
    }

    pub fn update(self: *Browser, key: i32) !bool {
        switch (key) {
            // die
            4, 'q' => {
                return false;
            },
            's' => {
                _ = ncurses.endwin();
                utils.spawn("bash") catch {};   //TODO: Repsonsible, yes
                _ = ncurses.initscr();
            },
            259, 'k' => {
                if (self.entries.items.len > 0) {
                    if (self.index <= 0) {
                        self.index = self.entries.items.len - 1;
                    } else {
                        self.index -= 1;
                    }
                }
            },
            258, 'j' => {
                if (self.entries.items.len > 0) {
                    if (self.index >= self.entries.items.len - 1) {
                        self.index = 0;
                    } else {
                        self.index += 1;
                    }
                }
            },
            261, 'l' => {
                self.enterDir();
            },
            260, 'h' => {
                try self.exitDir();
            },
            'c' => {
                try self.createFile();
                try self.fillEntries();
            },
            'C' => {
                try self.createFolder();
                try self.fillEntries();
            },
            'D' => {
                try self.deleteEntry();
                try self.fillEntries();
            },
            'f' => {
                try self.findFile();
            },
            ' ' => {
                try self.addMark();
                if(self.index < self.entries.items.len - 1) {
                    self.index += 1;
                }
                try self.printDirs();
            },
            'R' => {
                try self.renameEntry();
                try self.fillEntries();
            },
            'G' => {},  //TODO: Git mode(?)
            'm' => {
                self.clearMarks();
            },
            'a' => {},  //TODO: File info
            'p' => {
                try self.copyMarks();
                self.clearMarks();
            },
            'v' => {},  //TODO: Move marks
            'b' => {},  //TODO: Add to bookmarks
            'g' => {},  //TODO: Show bookmarks
            else => {
                //_ = ncurses.mvprintw(20, 10, "%d", self.marks.count());
                //_ = ncurses.getch();
            },
        }
        return true;
    }
};
