const std = @import("std");
const pdapi = @import("../api.zig");
const plt = @import("plt.zig");
const system = pdapi.system;

const raw = @import("playdate_raw");

pub const File = opaque {
    pub const OpenOptions = packed struct(raw.FileOptions) {
        read: bool = false,
        read_data: bool = false,
        write: bool = false,
        append: bool = false,
        _: u28 = 0,
    };
    // open: *const fn (path: [*:0]const u8, options: FileOptions) callconv(.C) ?*File,
    pub fn open(path: [*:0]const u8, options: OpenOptions) error{OpenFail}!*File {
        if (plt.pd.file_open(path, @bitCast(options))) |file| {
            return file;
        } else {
            system.err("error: %s", plt.pd.file_geterr());
            return error.OpenFail;
        }
    }

    // close: *const fn (file: *File) callconv(.C) c_int,
    pub fn close(self: *File) error{CloseFail}!void {
        if (plt.pd.file_close(self) != 0) {
            system.err("error: %s", plt.pd.file_geterr());
            return error.CloseFail;
        }
    }

    // read: *const fn (file: *File, buf: *anyopaque, len: c_uint) callconv(.C) c_int,
    pub fn read(self: *File, bytes: []u8) ReadError!usize {
        const len = plt.pd.file_read(self, bytes.ptr, bytes.len);
        if (len >= 0) {
            return len;
        } else {
            system.err("error: %s", plt.pd.file_geterr());
            return error.ReadFail;
        }
    }
    pub const ReadError = error{ReadFail};
    pub const Reader = std.io.Reader(*File, ReadError, read);
    pub fn reader(self: *File) Reader {
        return Reader{ .context = self };
    }

    // write: *const fn (file: *File, buf: *const anyopaque, len: c_uint) callconv(.C) c_int,
    pub fn write(self: *File, bytes: []const u8) WriteError!usize {
        const len = plt.pd.file_write(self, bytes.ptr, @intCast(bytes.len));
        if (len >= 0) {
            return @intCast(len);
        } else {
            system.err("error: %s", plt.pd.file_geterr());
            return error.WriteFail;
        }
    }
    pub const WriteError = error{WriteFail};
    pub const BufferedWriter = std.io.Writer(*File, WriteError, write);
    pub fn bufferedWriter(self: *File) BufferedWriter {
        return BufferedWriter{ .context = self };
    }

    // flush: *const fn (file: *File) callconv(.C) c_int,
    pub fn flush(self: *File) WriteError!usize {
        const len = plt.pd.file_flush(self);
        if (len >= 0) {
            return @intCast(len);
        } else {
            system.err("error: %s", plt.pd.file_geterr());
            return error.WriteFail;
        }
    }
    pub fn flushAll(self: *File) WriteError!void {
        while (true) {
            const len = try self.flush();
            if (len == 0) return;
        }
    }
    pub fn flushWrite(self: *File, bytes: []const u8) WriteError!usize {
        const len = try self.write(bytes);
        try self.flushAll();
        return len;
    }
    pub const Writer = std.io.Writer(*File, WriteError, flushWrite);
    pub fn writer(self: *File) Writer {
        return Writer{ .context = self };
    }

    // tell: *const fn (file: *File) callconv(.C) c_int,
    pub fn tell(self: *File) error{TellFail}!usize {
        const offset = plt.pd.file_tell(self);
        if (offset >= 0) {
            return offset;
        } else {
            system.err("error: %s", plt.pd.file_geterr());
            return error.TellFail;
        }
    }

    // seek: *const fn (file: *File, pos: c_int, whence: c_int) callconv(.C) c_int,
    pub fn seek(self: *File, pos: i32, whence: enum { set, current, end }) error{SeekFail}!void {
        if (plt.pd.file_seek(self, pos, switch (whence) {
            .set => raw.SEEK_SET,
            .current => raw.SEEK_CUR,
            .end => raw.SEEK_END,
        }) != 0) {
            system.err("error: %s", plt.pd.file_geterr());
            return error.SeekFail;
        }
    }
};

/// listfiles: *const fn (
///     path: [*:0]const u8,
///     callback: *const fn (path: [*:0]const u8, userdata: ?*anyopaque) callconv(.C) void,
///     userdata: ?*anyopaque,
///     showhidden: c_int,
/// ) callconv(.C) c_int,
pub fn listFilesContext(
    /// Context should be a container with a method `callback(ctx: *Context, path: [*:0]const u8) void`.
    comptime Context: type,
    path: [*:0]const u8,
    context: *Context,
    show_hidden: bool,
) error{FailedToOpenPath}!void {
    const listCallback = struct {
        pub fn f(p: [*:0]const u8, userdata: ?*anyopaque) callconv(.C) void {
            const ctx: *Context = @ptrCast(userdata.?);
            Context.callback(ctx, p);
        }
    }.f;
    plt.pd.file_listfiles(path, listCallback, context, if (show_hidden) 1 else 0);
}

pub fn listFiles(
    path: [*:0]const u8,
    callback: fn (p: [*:0]const u8) void,
    show_hidden: bool,
) error{FailedToOpenPath}!void {
    const listCallback = struct {
        pub fn f(p: [*:0]const u8, _: ?*anyopaque) callconv(.C) void {
            callback(p);
        }
    }.f;
    plt.pd.file_listfiles(path, listCallback, null, if (show_hidden) 1 else 0);
}

// stat: *const fn (path: [*:0]const u8, stat: ?*FileStat) callconv(.C) c_int,
pub const Stat = struct {
    is_dir: bool,
    size: u32,
    year: u16,
    month: u16,
    day: u16,
    hour: u16,
    minute: u16,
    second: u16,
};
pub fn stat(path: [*:0]const u8) error{StatFail}!Stat {
    var s: raw.FileStat = undefined;
    if (plt.pd.file_stat(path, &s) != 0) {
        system.err("error: %s", plt.pd.file_geterr());
        return error.StatFail;
    }
    return Stat{
        .is_dir = s.isdir == 1,
        .size = s.size,
        .year = @intCast(s.m_year),
        .month = @intCast(s.m_month),
        .day = @intCast(s.m_day),
        .hour = @intCast(s.m_hour),
        .minute = @intCast(s.m_minute),
        .second = @intCast(s.m_second),
    };
}

// mkdir: *const fn (path: [*:0]const u8) callconv(.C) c_int,
pub fn mkdir(path: [*:0]const u8) error{MkdirFail}!void {
    if (plt.pd.file_mkdir(path) != 0) {
        system.err("error: %s", plt.pd.file_geterr());
        return error.MkdirFail;
    }
}

// unlink: *const fn (path: [*:0]const u8, recursive: c_int) callconv(.C) c_int,
pub fn unlink(path: [*:0]const u8, recursive: bool) error{UnlinkFail}!void {
    if (plt.pd.file_unlink(path, @intFromBool(recursive)) != 0) {
        system.err("error: %s", plt.pd.file_geterr());
        return error.UnlinkFail;
    }
}

// rename: *const fn (from: [*:0]const u8, to: [*c]const u8) callconv(.C) c_int,
pub fn rename(from: [*:0]const u8, to: [*:0]const u8) error{RenameFail}!void {
    if (plt.pd.file_rename(from, to) != 0) {
        system.err("error: %s", plt.pd.file_geterr());
        return error.RenameFail;
    }
}
