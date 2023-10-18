const std = @import("std");
const pdapi = @import("../api.zig");
const system = pdapi.system;

pub const File = opaque {
    pub const OpenOptions = packed struct(FileOptions) {
        read: bool = false,
        read_data: bool = false,
        write: bool = false,
        append: bool = false,
        _: u28 = 0,
    };
    // open: *const fn (path: [*:0]const u8, options: FileOptions) callconv(.C) ?*File,
    pub fn open(path: [*:0]const u8, options: OpenOptions) error{OpenFail}!*File {
        if (fs.open(path, @bitCast(options))) |file| {
            return file;
        } else {
            system.err("error: %s", fs.geterr());
            return error.OpenFail;
        }
    }

    // close: *const fn (file: *File) callconv(.C) c_int,
    pub fn close(self: *File) error{CloseFail}!void {
        if (fs.close(self) != 0) {
            system.err("error: %s", fs.geterr());
            return error.CloseFail;
        }
    }

    // read: *const fn (file: *File, buf: *anyopaque, len: c_uint) callconv(.C) c_int,
    pub fn read(self: *File, bytes: []u8) ReadError!usize {
        const len = fs.read(self, bytes.ptr, bytes.len);
        if (len >= 0) {
            return len;
        } else {
            system.err("error: %s", fs.geterr());
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
        const len = fs.write(self, bytes.ptr, @intCast(bytes.len));
        if (len >= 0) {
            return @intCast(len);
        } else {
            system.err("error: %s", fs.geterr());
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
        const len = fs.flush(self);
        if (len >= 0) {
            return @intCast(len);
        } else {
            system.err("error: %s", fs.geterr());
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
        const offset = fs.tell(self);
        if (offset >= 0) {
            return offset;
        } else {
            system.err("error: %s", fs.geterr());
            return error.TellFail;
        }
    }

    // seek: *const fn (file: *File, pos: c_int, whence: c_int) callconv(.C) c_int,
    pub fn seek(self: *File, pos: i32, whence: enum { set, current, end }) error{SeekFail}!void {
        if (fs.seek(self, pos, switch (whence) {
            .set => SEEK_SET,
            .current => SEEK_CUR,
            .end => SEEK_END,
        }) != 0) {
            system.err("error: %s", fs.geterr());
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
    fs.listfiles(path, listCallback, context, if (show_hidden) 1 else 0);
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
    fs.listfiles(path, listCallback, null, if (show_hidden) 1 else 0);
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
    var s: FileStat = undefined;
    if (fs.stat(path, &s) != 0) {
        system.err("error: %s", fs.geterr());
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
    if (fs.mkdir(path) != 0) {
        system.err("error: %s", fs.geterr());
        return error.MkdirFail;
    }
}

// unlink: *const fn (path: [*:0]const u8, recursive: c_int) callconv(.C) c_int,
pub fn unlink(path: [*:0]const u8, recursive: bool) error{UnlinkFail}!void {
    if (fs.unlink(path, @intFromBool(recursive)) != 0) {
        system.err("error: %s", fs.geterr());
        return error.UnlinkFail;
    }
}

// rename: *const fn (from: [*:0]const u8, to: [*c]const u8) callconv(.C) c_int,
pub fn rename(from: [*:0]const u8, to: [*c]const u8) error{RenameFail}!void {
    if (fs.rename(from, to) != 0) {
        system.err("error: %s", fs.geterr());
        return error.RenameFail;
    }
}

///// RAW BINDINGS /////
var fs: *const PlaydateFile = undefined;
pub fn init(pdfile: *const PlaydateFile) void {
    fs = pdfile;
}

const FileOptions = c_int;
const FILE_READ = (1 << 0);
const FILE_READ_DATA = (1 << 1);
const FILE_WRITE = (1 << 2);
const FILE_APPEND = (2 << 2);

const SEEK_SET = 0;
const SEEK_CUR = 1;
const SEEK_END = 2;

const FileStat = extern struct {
    isdir: c_int,
    size: c_uint,
    m_year: c_int,
    m_month: c_int,
    m_day: c_int,
    m_hour: c_int,
    m_minute: c_int,
    m_second: c_int,
};

pub const PlaydateFile = extern struct {
    geterr: *const fn () callconv(.C) [*:0]const u8,

    listfiles: *const fn (
        path: [*:0]const u8,
        callback: *const fn (path: [*:0]const u8, userdata: ?*anyopaque) callconv(.C) void,
        userdata: ?*anyopaque,
        showhidden: c_int,
    ) callconv(.C) c_int,
    stat: *const fn (path: [*:0]const u8, stat: *FileStat) callconv(.C) c_int,
    mkdir: *const fn (path: [*:0]const u8) callconv(.C) c_int,
    unlink: *const fn (path: [*:0]const u8, recursive: c_int) callconv(.C) c_int,
    rename: *const fn (from: [*:0]const u8, to: [*:0]const u8) callconv(.C) c_int,

    open: *const fn (path: [*:0]const u8, options: FileOptions) callconv(.C) ?*File,
    close: *const fn (file: *File) callconv(.C) c_int,
    read: *const fn (file: *File, buf: *anyopaque, len: c_uint) callconv(.C) c_int,
    write: *const fn (file: *File, buf: *const anyopaque, len: c_uint) callconv(.C) c_int,
    flush: *const fn (file: *File) callconv(.C) c_int,
    tell: *const fn (file: *File) callconv(.C) c_int,
    seek: *const fn (file: *File, pos: c_int, whence: c_int) callconv(.C) c_int,
};
