const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));
const utils = @import("utils.zig");

pub const Browser = struct {
    const FileEntry = struct {
        kind: std.fs.File.Kind,
        mode: std.fs.File.Mode,
        name: [:0]u8,
        size: u64,
        sizeStr: ?[:0]u8,
    };

    const Entries = std.ArrayList(FileEntry);

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
    ally: *std.mem.Allocator,
    entries: Entries = undefined,

    pub fn init(ally: *std.mem.Allocator) !Browser {
        var browser = Browser{
            .ally = ally,
            .entries = Entries.init(ally.*),
        };

        browser.cwd = try std.os.getcwd(&browser.cwdBuf);
        browser.cwdBuf[browser.cwd.len] = 0;
        try browser.fillEntries();
        return browser;
    }

    pub fn deinit(self: *Browser) void {
        self.clearEntries();
        self.entries.deinit();
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

        const cwd = @ptrCast([*c]const u8, self.cwd);
        _ = ncurses.attron(@as(c_int, ncurses.A_BOLD) | ncurses.COLOR_PAIR(1));
        _ = ncurses.mvprintw(0, 0, cwd);
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
        while (i + @intCast(usize, limit) < self.entries.items.len) : (i += 1) {
            const current = i + @intCast(usize, limit);
            const entry = &self.entries.items[current];
            //TODO: shorten name here if appropriate
            const printedName = entry.name[0..];
            const printedNamePtr = @ptrCast([*c]const u8, printedName);

            _ = ncurses.attroff(ncurses.A_REVERSE);
            if (self.index == current) {
                _ = ncurses.attron(ncurses.A_REVERSE);
            }

            _ = ncurses.attroff(ncurses.A_BOLD);
            if (entry.kind == .Directory) {
                _ = ncurses.attron(ncurses.A_BOLD);
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %03o %10s %s ", entry.mode & 0o0777, dirStr, printedNamePtr);
            } else if (entry.kind == .SymLink) {
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %03o %10s %s ", entry.mode & 0o0777, lnStr, printedNamePtr);
            } else {
                if(entry.sizeStr) |size| {
                    const sizeStr = @ptrCast([*c]const u8, size);
                    _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %03o %10s %s ", entry.mode & 0o0777, sizeStr, printedNamePtr);
                } else {
                    _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " ??? %10s %s ", "?  ", printedNamePtr);
                }
            }
        }

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
            65, 'k' => {
                if (self.entries.items.len > 0) {
                    if (self.index <= 0) {
                        self.index = self.entries.items.len - 1;
                    } else {
                        self.index -= 1;
                    }
                }
            },
            66, 'j' => {
                if (self.entries.items.len > 0) {
                    if (self.index >= self.entries.items.len - 1) {
                        self.index = 0;
                    } else {
                        self.index += 1;
                    }
                }
            },
            67, 'l' => {
                self.enterDir();
            },
            68, 'h' => {
                try self.exitDir();
            },
            else => {},
        }
        return true;
    }
};
