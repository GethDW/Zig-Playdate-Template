const std = @import("std");
const pdapi = @import("../playdate_api_definitions.zig");
const graphics = pdapi.graphics;

const assert = std.debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;

pub fn allocator() Allocator {
    return Allocator{
        .ptr = @ptrCast(@constCast(sys.realloc)),
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .free = free,
        },
    };
}

fn getHeader(ptr: [*]u8) *[*]u8 {
    return @as(*[*]u8, @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize)));
}

fn alignedAlloc(len: usize, log2_align: u8) ?[*]u8 {
    const alignment = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_align));

    // Thin wrapper around regular malloc, overallocate to account for
    // alignment padding and store the original malloc()'ed pointer before
    // the aligned address.
    var unaligned_ptr = @as([*]u8, @ptrCast(sys.realloc(null, len + alignment - 1 + @sizeOf(usize)) orelse return null));
    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment);
    var aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
    getHeader(aligned_ptr).* = unaligned_ptr;

    return aligned_ptr;
}

fn alignedFree(ptr: [*]u8) void {
    const unaligned_ptr = getHeader(ptr).*;
    _ = sys.realloc(unaligned_ptr, 0);
}

fn alloc(_: *anyopaque, len: usize, log2_align: u8, _: usize) ?[*]u8 {
    assert(len > 0);
    return alignedAlloc(len, log2_align);
}

fn resize(_: *anyopaque, buf: []u8, _: u8, new_len: usize, _: usize) bool {
    return new_len <= buf.len;
}

fn free(_: *anyopaque, buf: []u8, _: u8, _: usize) void {
    alignedFree(buf.ptr);
}

pub const Buttons = packed struct(c_int) {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
    b: bool = false,
    a: bool = false,
    _: u26 = 0,

    const BUTTON_LEFT = (1 << 0);
    const BUTTON_RIGHT = (1 << 1);
    const BUTTON_UP = (1 << 2);
    const BUTTON_DOWN = (1 << 3);
    const BUTTON_B = (1 << 4);
    const BUTTON_A = (1 << 5);

    pub fn getButtons() struct {
        current: Buttons,
        pushed: Buttons,
        released: Buttons,
    } {
        var current, var pushed, var released = [_]Buttons{undefined} ** 3;
        sys.getButtonState(&current, &pushed, &released);
        return .{
            .current = current,
            .pushed = pushed,
            .released = released,
        };
    }

    comptime {
        assert(@as(c_int, @bitCast(Buttons{ .left = true })) == BUTTON_LEFT);
        assert(@as(c_int, @bitCast(Buttons{ .right = true })) == BUTTON_RIGHT);
        assert(@as(c_int, @bitCast(Buttons{ .up = true })) == BUTTON_UP);
        assert(@as(c_int, @bitCast(Buttons{ .down = true })) == BUTTON_DOWN);
        assert(@as(c_int, @bitCast(Buttons{ .b = true })) == BUTTON_B);
        assert(@as(c_int, @bitCast(Buttons{ .a = true })) == BUTTON_A);
    }
};

pub const Peripherals = struct {
    accelerometer: bool = false,
};
pub fn setPeripheralsEnabled(peripherals: Peripherals) void {
    var mask: pdapi.PDPeripherals = pdapi.PERIPHERAL_NONE;
    if (peripherals.accelerometer) mask |= pdapi.PERIPHERAL_ACCELEROMETER;
    sys.setPeripheralsEnabled(mask);
}

pub fn getAccelerometer() struct { x: f32, y: f32, z: f32 } {
    var x, var y, var z = [_]f32{undefined} ** 3;
    sys.getAccelerometer(&x, &y, &z);
    return .{ .x = x, .y = y, .z = z };
}

pub fn getCrankChange() f32 {
    return sys.getCrankChange();
}
pub fn getCrankAngle() f32 {
    return sys.getCrankAngle();
}
pub fn isCrankDocked() bool {
    return sys.isCrankDocked() == 1;
}

const MenuItemKind = enum {
    plain,
    checkmark,
    options,
};
pub fn MenuItem(comptime Userdata: type, comptime kind: MenuItemKind) type {
    return opaque {
        const Callback = fn (*Userdata) void;
        const Self = @This();
        fn inner(comptime callback: Callback) fn (?*anyopaque) callconv(.C) void {
            return struct {
                pub fn f(userdata: ?*anyopaque) callconv(.C) void {
                    if (@sizeOf(Userdata) != 0) {
                        const ctx: *Userdata = @ptrCast(@alignCast(userdata.?));
                        callback(ctx);
                    } else {
                        callback(undefined);
                    }
                }
            }.f;
        }

        const newUserdataFns = struct {
            pub fn plain(comptime callback: Callback, title: [*:0]const u8, context: *Userdata) *Self {
                return @ptrCast(sys.addMenuItem(title, &inner(callback), context));
            }
            pub fn checkmark(comptime callback: Callback, title: [*:0]const u8, checked: bool, context: *Userdata) *Self {
                return @ptrCast(sys.addCheckmarkMenuItem(title, @intFromBool(checked), &inner(callback), context));
            }
            pub fn option(comptime callback: Callback, title: [*:0]const u8, options: []const [*:0]const u8, context: *Userdata) *Self {
                return @ptrCast(sys.addOptionsMenuItem(title, options.ptr, @intCast(options.len), &inner(callback), context));
            }
        };
        pub const newUserdata = switch (kind) {
            .plain => newUserdataFns.plain,
            .checkmark => newUserdataFns.checkmark,
            .options => newUserdataFns.option,
        };
        const newFns = struct {
            pub fn plain(comptime callback: Callback, title: [*:0]const u8) *Self {
                if (@sizeOf(Userdata) != 0) @compileError("Cannot infer context " ++ @typeName(Userdata) ++ ", call newUserdata instead.");
                return @ptrCast(sys.addMenuItem(title, &inner(callback), null));
            }
            pub fn checkmark(comptime callback: Callback, title: [*:0]const u8, checked: bool) *Self {
                if (@sizeOf(Userdata) != 0) @compileError("Cannot infer context " ++ @typeName(Userdata) ++ ", call newUserdata instead.");
                return @ptrCast(sys.addCheckmarkMenuItem(title, @intFromBool(checked), &inner(callback), null));
            }
            pub fn option(comptime callback: Callback, title: [*:0]const u8, options: []const [*:0]const u8) *Self {
                if (@sizeOf(Userdata) != 0) @compileError("Cannot infer context " ++ @typeName(Userdata) ++ ", call newUserdata instead.");
                return @ptrCast(sys.addOptionsMenuItem(title, options.ptr, @intCast(options.len), &inner(callback), null));
            }
        };
        pub const new = switch (kind) {
            .plain => newFns.plain,
            .checkmark => newFns.checkmark,
            .options => newFns.option,
        };

        pub const Value = switch (kind) {
            .plain => void,
            .checkmark => bool,
            .options => usize,
        };
        pub fn getValue(self: *const Self) Value {
            const val = sys.getMenuItemValue(@ptrCast(@constCast(self)));
            switch (kind) {
                .plain => return {},
                .checkmark => return switch (val) {
                    0 => false,
                    1 => true,
                    else => {
                        err("error: invalid CheckmarkMenuItem value %d", val);
                        @panic("invalid CheckmarkMenuItem value");
                    },
                },
                .options => return switch (val) {
                    0...std.math.maxInt(c_int) => |i| @intCast(i),
                    else => {
                        err("error: invalid OptionsMenuItem value %d", val);
                        @panic("invalid OptionsMenuItem value");
                    },
                },
            }
        }

        pub fn setValue(self: *Self, value: Value) void {
            switch (kind) {
                .plain => {},
                .checkmark => sys.setMenuItemValue(@ptrCast(self), @intFromBool(value)),
                .options => sys.setMenuItemValue(@ptrCast(self), @intCast(value)),
            }
        }

        pub fn getTitle(self: *const Self) [*:0]const u8 {
            return sys.getMenuItemTitle(@ptrCast(@constCast(self)));
        }

        pub fn setTitle(self: *Self, title: [*:0]const u8) void {
            sys.setMenuItemTitle(@ptrCast(self), title);
        }

        pub fn getUserdata(self: *Self) *Userdata {
            if (@sizeOf(Userdata) == 0) return undefined;
            return @ptrCast(@alignCast(sys.getMenuItemUserdata(@ptrCast(self)).?));
        }

        pub fn setUserdata(self: *Self, new_context: *Userdata) void {
            if (@sizeOf(Userdata) != 0) {
                sys.setMenuItemUserdata(@ptrCast(self), new_context);
            }
        }

        pub fn remove(self: *Self) void {
            sys.removeMenuItem(@ptrCast(self));
        }
    };
}

pub const Event = enum(c_int) {
    Init,
    InitLua,
    Lock,
    Unlock,
    Pause,
    Resume,
    Terminate,
    KeyPressed, // arg is keycode
    KeyReleased,
    LowPower,
};
const Language = enum(c_int) {
    English,
    Japanese,
    Unknown,
};

const PDPeripherals = c_int;
const PERIPHERAL_NONE = 0;
const PERIPHERAL_ACCELEROMETER = (1 << 0);
// ...
const PERIPHERAL_ALL = 0xFFFF;

pub const StringEncoding = enum(c_int) {
    ASCII,
    UTF8,
    @"16BitLE",
};

pub const DateTime = extern struct {
    year: u16,
    month: u8, // 1-12
    day: u8, // 1-31
    weekday: u8, // 1=monday-7=sunday
    hour: u8, // 0-23
    minute: u8,
    second: u8,
};

///// RAW BINDINGS /////
var sys: *const PlaydateSys = undefined;
// TODO: pub fn print(comptime fmt: []const u8, args: anytype) void
//       creates a c-style fmt string at comptime and with type checking
//       then calls log with @call.
pub var log: *const fn (fmt: [*:0]const u8, ...) callconv(.C) void = undefined;
pub var err: *const fn (fmt: [*c]const u8, ...) callconv(.C) void = undefined;
pub fn init(pdsys: *const PlaydateSys) void {
    sys = pdsys;
    log = pdsys.logToConsole;
    err = pdsys.@"error";
}

pub const PlaydateSys = extern struct {
    const AnyMenuItem = opaque {};
    const PDCallbackFunction = fn (userdata: *anyopaque) callconv(.C) c_int;
    const PDMenuItemCallbackFunction = fn (userdata: *anyopaque) callconv(.C) void;

    realloc: *const fn (ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque, // done
    formatString: *const fn (ret: ?*[*c]u8, fmt: [*c]const u8, ...) callconv(.C) c_int,
    logToConsole: *const fn (fmt: [*c]const u8, ...) callconv(.C) void, // done
    @"error": *const fn (fmt: [*c]const u8, ...) callconv(.C) void, // done
    getLanguage: *const fn () callconv(.C) Language,
    getCurrentTimeMilliseconds: *const fn () callconv(.C) c_uint,
    getSecondsSinceEpoch: *const fn (milliseconds: ?*c_uint) callconv(.C) c_uint,
    drawFPS: *const fn (x: c_int, y: c_int) callconv(.C) void,

    setUpdateCallback: *const fn (update: ?*const PDCallbackFunction, userdata: ?*anyopaque) callconv(.C) void,
    getButtonState: *const fn (current: ?*Buttons, pushed: ?*Buttons, released: ?*Buttons) callconv(.C) void, // done
    setPeripheralsEnabled: *const fn (mask: PDPeripherals) callconv(.C) void,
    getAccelerometer: *const fn (outx: ?*f32, outy: ?*f32, outz: ?*f32) callconv(.C) void,
    getCrankChange: *const fn () callconv(.C) f32,
    getCrankAngle: *const fn () callconv(.C) f32,
    isCrankDocked: *const fn () callconv(.C) c_int,
    setCrankSoundsDisabled: *const fn (flag: c_int) callconv(.C) c_int, // returns previous setting

    getFlipped: *const fn () callconv(.C) c_int,
    setAutoLockDisabled: *const fn (disable: c_int) callconv(.C) void,

    setMenuImage: *const fn (bitmap: *graphics.Bitmap, xOffset: c_int) callconv(.C) void,
    addMenuItem: *const fn (title: [*:0]const u8, callback: *const PDMenuItemCallbackFunction, userdata: ?*anyopaque) callconv(.C) *AnyMenuItem,
    addCheckmarkMenuItem: *const fn (title: [*:0]const u8, value: c_int, callback: *const PDMenuItemCallbackFunction, userdata: ?*anyopaque) callconv(.C) ?*AnyMenuItem,
    addOptionsMenuItem: *const fn (title: [*:0]const u8, optionTitles: [*]const [*:0]const u8, optionsCount: c_int, f: *const PDMenuItemCallbackFunction, userdata: ?*anyopaque) callconv(.C) ?*AnyMenuItem,
    removeAllMenuItems: *const fn () callconv(.C) void,
    removeMenuItem: *const fn (menuItem: *AnyMenuItem) callconv(.C) void,
    getMenuItemValue: *const fn (menuItem: *AnyMenuItem) callconv(.C) c_int,
    setMenuItemValue: *const fn (menuItem: *AnyMenuItem, value: c_int) callconv(.C) void,
    getMenuItemTitle: *const fn (menuItem: *AnyMenuItem) callconv(.C) [*c]const u8,
    setMenuItemTitle: *const fn (menuItem: *AnyMenuItem, title: [*:0]const u8) callconv(.C) void,
    getMenuItemUserdata: *const fn (menuItem: *AnyMenuItem) callconv(.C) ?*anyopaque,
    setMenuItemUserdata: *const fn (menuItem: *AnyMenuItem, ud: ?*anyopaque) callconv(.C) void,

    getReduceFlashing: *const fn () callconv(.C) c_int,

    // 1.1
    getElapsedTime: *const fn () callconv(.C) f32,
    resetElapsedTime: *const fn () callconv(.C) void,

    // 1.4
    getBatteryPercentage: *const fn () callconv(.C) f32,
    getBatteryVoltage: *const fn () callconv(.C) f32,

    // 1.13
    getTimezoneOffset: *const fn () callconv(.C) i32,
    shouldDisplay24HourTime: *const fn () callconv(.C) c_int,
    convertEpochToDateTime: *const fn (epoch: u32, datetime: *DateTime) callconv(.C) void,
    convertDateTimeToEpoch: *const fn (datetime: *DateTime) callconv(.C) u32,

    //2.0
    clearICache: *const fn () callconv(.C) void,
};
