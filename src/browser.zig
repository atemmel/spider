const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));
const utils = @import("utils.zig");

pub const Browser = struct {
    const FileEntry = struct {
        kind: std.fs.File.Kind,
        mode: std.fs.File.Mode,
        name: [:0]u8,
        size: u64,
        sizeStr: [:0]u8,
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
            self.ally.free(std.mem.span(e.sizeStr));
        }
        self.entries.clearRetainingCapacity();
    }

    fn fillEntries(self: *Browser) !void {
        self.clearEntries();

        var dir = try std.fs.openDirAbsolute(
            self.cwd,
            .{ .iterate = true },
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

            const st = try dir.statFile(entry.name);
            newEntry.size = st.size;
            newEntry.sizeStr = try utils.sizeToString(self.ally, st.size);
            newEntry.mode = st.mode;

            try self.entries.append(newEntry);
        }

        std.sort.sort(FileEntry, self.entries.items, {}, compByEntryKind);
        _ = ncurses.erase();
    }

    pub fn draw(self: *Browser) !void {
        _ = ncurses.erase();
        self.printHeader();
        try self.printDirs();
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

        var upperLimit = @intCast(i32, try std.math.absInt(@intCast(i64, self.entries.items.len) - @intCast(i64, @divTrunc(height, 2))));
        var limit = @intCast(i32, @intCast(i64, oy + self.index) - @intCast(i64, @divTrunc(height, 2)));

        if (self.entries.items.len < height - oy) {
            upperLimit = 0;
        }

        limit = utils.clamp(limit, 0, upperLimit);

        var i: usize = 0;
        while (i + @intCast(usize, limit) < self.entries.items.len) : (i += 1) {
            const current = i + @intCast(usize, limit);
            const entry = &self.entries.items[current];
            const printedName = entry.name[0..dirStr.len];
            const printedNamePtr = @ptrCast([*c]const u8, printedName);

            _ = ncurses.attroff(ncurses.A_REVERSE);
            if (self.index == current) {
                _ = ncurses.attron(ncurses.A_REVERSE);
            }

            _ = ncurses.attroff(ncurses.A_BOLD);
            if (entry.kind == .Directory) {
                _ = ncurses.attron(ncurses.A_BOLD);
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %o %10s %s ", entry.mode & 0o0777, dirStr, printedNamePtr);
            } else if (entry.kind == .SymLink) {
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %o %10s %s ", entry.mode & 0o0777, lnStr, printedNamePtr);
            } else {
                const sizeStr = @ptrCast([*c]const u8, entry.sizeStr);
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %o %10s %s ", entry.mode & 0o0777, sizeStr, printedNamePtr);
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
        try self.fillEntries();
        //self.fillEntries() catch {
        //TODO: Be responsible
        //};
    }

    pub fn update(self: *Browser, key: i32) !bool {
        switch (key) {
            // die
            4, 'q' => {
                return false;
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
                _ = ncurses.printw("right");
            },
            68, 'h' => {
                try self.exitDir();
            },
            else => {},
        }
        return true;
    }
};
