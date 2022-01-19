const std = @import("std");
const ncurses = @cImport(@cInclude("ncurses.h"));
const utils = @import("utils.zig");

pub const Browser = struct {
    const FileEntry = struct {
        kind: std.fs.File.Kind,
        mode: std.fs.File.Mode,
        name: []u8,
        size: i64,
        sizeStr: []u8,
    };
    const Entries = std.ArrayList(FileEntry);

    fn compByEntryKind(_: void, lhs: FileEntry, rhs: FileEntry) bool {
        if(lhs.kind == .Directory) {
            if(rhs.kind == .Directory) {
                return utils.caseInsensitiveComparison(lhs.name, rhs.name);
            } else {
                return false;
            }
        } else if(rhs.kind == .Directory) {
            return true;
        }
        return utils.caseInsensitiveComparison(lhs.name, rhs.name);
    }

    index: usize = 0,
    cwdBuf: [std.fs.MAX_PATH_BYTES]u8 = undefined,
    cwd: []u8 = undefined,
    ally: *std.mem.Allocator,
    entries: Entries = undefined,

    pub fn init(ally: *std.mem.Allocator) !Browser {
        var browser = Browser{
            .ally = ally,
            .entries = Entries.init(ally.*),
        };

        browser.cwd = try std.os.getcwd(&browser.cwdBuf);
        try browser.fillEntries();
        return browser;
    }

    pub fn deinit(self: *Browser) void {
        for (self.entries.items) |e| self.ally.free(e.name);
        self.entries.deinit();
    }

    fn fillEntries(self: *Browser) !void {
        self.entries.clearRetainingCapacity();

        const dir = try std.fs.cwd().openDir(
            ".",
            .{.iterate = true},
        );

        var it = dir.iterate();
        while (try it.next()) |entry| {
            var newEntry = FileEntry{
                .kind = entry.kind,
                .mode = undefined,
                .name = try self.ally.dupeZ(u8, entry.name),
                .size = undefined,
                .sizeStr = undefined,
            };

            var fd = try std.os.openZ(@ptrCast([*:0]const u8, entry.name), std.os.O.RDONLY | std.os.O.CLOEXEC, 0);
            defer std.os.close(fd);

            const st = try std.os.fstat(fd);
            newEntry.size = st.size;
            newEntry.mode = st.mode;

            try self.entries.append(newEntry);
        }

        std.sort.sort(FileEntry, self.entries.items, {}, compByEntryKind);

        _= ncurses.erase();
    }

    pub fn draw(self: *Browser) !void {
        self.printHeader();
        try self.printDirs();
    }

    fn printHeader(self: *Browser) void {
        var x = ncurses.getmaxx(ncurses.stdscr);
        var i: i32 = 0;
        while(i < x) : (i += 1) {
            _= ncurses.mvprintw(0, i, " ");
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
        //const width = @intCast(i32, ncurses.getmaxx(ncurses.stdscr));
        const height = @intCast(i32, ncurses.getmaxy(ncurses.stdscr));

        var upperLimit = @intCast(i32, try std.math.absInt(@intCast(i64, self.entries.items.len) - @intCast(i64, @divTrunc(height, 2))));
        var limit = @intCast(i32, @intCast(i64, oy + self.index) - @intCast(i64, @divTrunc(height, 2)));

        if(self.entries.items.len < height - oy) {
            upperLimit = 0;
        }

        limit = utils.clamp(limit, 0, upperLimit);

        var i: usize = 0;
        while(i + @intCast(usize, limit) < self.entries.items.len) : (i += 1) {
            const current = i + @intCast(usize, limit);
            const entry = self.entries.items[current];
            const printedName = entry.name[0..dirStr.len];
            const printedNamePtr = @ptrCast([*c]const u8, printedName);
            _ = ncurses.attroff(ncurses.A_REVERSE);
            if(self.index == current) {
                _ = ncurses.attron(ncurses.A_REVERSE);
            } else {
                _ = ncurses.attroff(ncurses.A_REVERSE);
            }

            _ = ncurses.attroff(ncurses.A_BOLD);
            if(entry.kind == .Directory) {
                _ = ncurses.attron(ncurses.A_BOLD);
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %o %10s %s ",
                        entry.mode & 0o0777,
                        dirStr,
                        printedNamePtr);
            } else if(entry.kind == .SymLink) {
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %o %10s %s ",
                        entry.mode & 0o0777,
                        lnStr,
                        printedNamePtr);
            } else {
                _ = ncurses.mvprintw(@intCast(c_int, i + oy), ox, " %o %10s %s ",
                        entry.mode & 0o0777,
                        "",
                        printedNamePtr);
            }

                    
        }
    }

    pub fn update(_: *Browser, key: i32) bool {
        switch(key) {
            // die
            4, 'q' => {
                return false;
            },
            ncurses.KEY_RIGHT, 'l' => {
                _ = ncurses.printw("right");
            },
            ncurses.KEY_LEFT, 'h' => {
                _ = ncurses.printw("left");
            },
            ncurses.KEY_UP, 'k' => {
                _ = ncurses.printw("up");
            },
            ncurses.KEY_DOWN, 'j' => {
                _ = ncurses.printw("down");
            },
            else => {},
        }
        return true;
    }
};
