const std = @import("std");
const pdapi = @import("../api.zig");
const raw = @import("playdate_raw");
const plt = @import("plt.zig");
const graphics = pdapi.graphics;

const assert = std.debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;

// TODO: pub fn print(comptime fmt: []const u8, args: anytype) void
//       creates a c-style fmt string at comptime and with type checking
//       then calls log with @call.
pub var log: *const fn (fmt: [*:0]const u8, ...) callconv(.C) void = undefined;
pub var err: *const fn (fmt: [*:0]const u8, ...) callconv(.C) void = undefined;

pub fn allocator() Allocator {
    return Allocator{
        .ptr = undefined,
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
    var unaligned_ptr = @as([*]u8, @ptrCast(plt.pd.system_realloc(null, len + alignment - 1 + @sizeOf(usize)) orelse return null));
    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment);
    var aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
    getHeader(aligned_ptr).* = unaligned_ptr;

    return aligned_ptr;
}

fn alignedFree(ptr: [*]u8) void {
    const unaligned_ptr = getHeader(ptr).*;
    _ = plt.pd.system_realloc(unaligned_ptr, 0);
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

    pub fn get() struct {
        current: Buttons,
        pushed: Buttons,
        released: Buttons,
    } {
        var current, var pushed, var released = [_]Buttons{undefined} ** 3;
        plt.pd.system_getButtonState(@ptrCast(&current), @ptrCast(&pushed), @ptrCast(&released));
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

pub const Peripherals = packed struct(c_int) {
    accelerometer: bool = false,
    _: u31 = false,
};
pub fn setPeripheralsEnabled(peripherals: Peripherals) void {
    var mask: raw.PDPeripherals = raw.PERIPHERAL_NONE;
    if (peripherals.accelerometer) mask |= pdapi.PERIPHERAL_ACCELEROMETER;
    plt.pd.system_setPeripheralsEnabled(mask);
}

pub fn getAccelerometer() struct { x: f32, y: f32, z: f32 } {
    var x, var y, var z = [_]f32{undefined} ** 3;
    plt.pd.system_getAccelerometer(&x, &y, &z);
    return .{ .x = x, .y = y, .z = z };
}

pub fn getCrankChange() f32 {
    return plt.pd.system_getCrankChange();
}
pub fn getCrankAngle() f32 {
    return plt.pd.system_getCrankAngle();
}
pub fn isCrankDocked() bool {
    return plt.pd.system_isCrankDocked() == 1;
}

pub const AnyMenuItem = opaque {
    pub fn new(title: [*:0]const u8) *AnyMenuItem {
        return plt.pd.system_addMenuItem(title, null, null);
    }
    pub fn newWithCallback(title: [*:0]const u8, comptime callback: fn () void) *AnyMenuItem {
        return plt.pd.system_addMenuItem(title, &inner(callback), null);
    }
    pub fn getTitle(self: *const AnyMenuItem) [*:0]const u8 {
        plt.pd.system_getMenuItemTitle(self);
    }
    pub fn setTitle(self: *AnyMenuItem, title: [*:0]const u8) void {
        plt.pd.system_setMenuItemTitle(self, title);
    }
    pub fn remove(self: *AnyMenuItem) void {
        plt.pd.system_removeMenuItem(self);
    }

    fn inner(comptime callback: fn () void) raw.PlaydateSys.PDMenuItemCallbackFunction {
        return struct {
            pub fn f(_: ?*anyopaque) callconv(.C) void {
                callback();
            }
        }.f;
    }
};
pub fn MenuItem(comptime Userdata: type) type {
    return opaque {
        const Self = @This();

        pub fn new(title: [*:0]const u8, userdata: *Userdata) *Self {
            return @ptrCast(plt.pd.system_addMenuItem(title, null, userdata));
        }
        pub fn newWithCallback(title: [*:0]const u8, comptime callback: fn (*Userdata) void, userdata: *Userdata) *Self {
            return @ptrCast(plt.pd.system_addMenuItem(title, &inner(callback), userdata));
        }
        pub fn getTitle(self: *const Self) [*:0]const u8 {
            return AnyMenuItem.getTitle(@ptrCast(self));
        }
        pub fn setTitle(self: *Self, title: [*:0]const u8) void {
            AnyMenuItem.setTitle(@ptrCast(self), title);
        }
        pub fn remove(self: *Self) void {
            AnyMenuItem.remove(@ptrCast(self));
        }
        pub fn getUserdata(self: *Self) *Userdata {
            return @ptrCast(plt.pd.system_getMenuItemUserdata(self));
        }
        pub fn setUserdata(self: *Self, userdata: *Userdata) void {
            plt.pd.system_setMenuItemUserdata(self.any(), userdata);
        }

        fn inner(comptime callback: fn (*Userdata) void) raw.PDMenuItemCallbackFunction {
            return struct {
                pub fn f(ptr: ?*anyopaque) callconv(.C) void {
                    callback(@ptrCast(@alignCast(ptr.?)));
                }
            }.f;
        }
    };
}

pub const Checked = enum(u1) { unchecked = 0, checked = 1 };
pub const AnyCheckmarkMenuItem = opaque {
    pub fn new(title: [*:0]const u8, checked: Checked) *AnyCheckmarkMenuItem {
        return @ptrCast(plt.pd.system_addCheckmarkMenuItem(title, @intFromEnum(checked), null, null));
    }
    pub fn newWithCallback(
        title: [*:0]const u8,
        checked: Checked,
        comptime callback: fn () void,
    ) *AnyCheckmarkMenuItem {
        return @ptrCast(plt.pd.system_addCheckmarkMenuItem(
            title,
            @intFromEnum(checked),
            &AnyMenuItem.inner(callback),
            null,
        ));
    }
    pub fn getTitle(self: *const AnyCheckmarkMenuItem) [*:0]const u8 {
        return AnyMenuItem.getTitle(@ptrCast(self));
    }
    pub fn setTitle(self: *AnyCheckmarkMenuItem, title: [*:0]const u8) void {
        AnyMenuItem.setTitle(@ptrCast(self), title);
    }
    pub fn remove(self: *AnyCheckmarkMenuItem) void {
        AnyMenuItem.remove(@ptrCast(self));
    }
    pub fn getChecked(self: *const AnyCheckmarkMenuItem) Checked {
        return switch (plt.pd.system_getMenuItemValue(@ptrCast(self))) {
            0, 1 => |i| @enumFromInt(i),
            else => unreachable,
        };
    }
    pub fn setChecked(self: *AnyCheckmarkMenuItem, checked: Checked) void {
        plt.pd.system_setMenuItemValue(self.normal(), @intFromEnum(checked));
    }
};
pub fn CheckmarkMenuItem(comptime Userdata: type) type {
    return opaque {
        const Self = @This();

        pub fn new(title: [*:0]const u8, checked: Checked, userdata: *Userdata) *Self {
            return @ptrCast(plt.pd.system_addCheckmarkMenuItem(title, @intFromEnum(checked), null, userdata));
        }
        pub fn newWithCallback(
            title: [*:0]const u8,
            checked: Checked,
            comptime callback: fn (*Userdata) void,
            userdata: *Userdata,
        ) *Self {
            return @ptrCast(plt.pd.system_addCheckmarkMenuItem(
                title,
                @intFromEnum(checked),
                &MenuItem(Userdata).inner(callback),
                userdata,
            ));
        }
        pub fn getTitle(self: *const Self) [*:0]const u8 {
            return AnyMenuItem.getTitle(@ptrCast(self));
        }
        pub fn setTitle(self: *Self, title: [*:0]const u8) void {
            AnyMenuItem.setTitle(@ptrCast(self), title);
        }
        pub fn remove(self: *Self) void {
            AnyMenuItem.remove(@ptrCast(self));
        }
        pub fn getChecked(self: *const Self) Checked {
            return AnyCheckmarkMenuItem.getChecked(@ptrCast(self));
        }
        pub fn setChecked(self: *Self, checked: Checked) void {
            AnyCheckmarkMenuItem.setChecked(@ptrCast(self), checked);
        }
        pub fn getUserdata(self: *Self) *Userdata {
            return MenuItem(Userdata).getUserdata(@ptrCast(self));
        }
        pub fn setUserdata(self: *Self, userdata: *Userdata) void {
            MenuItem(Userdata).setUserdata(@ptrCast(self), userdata);
        }
    };
}

pub const AnyOptionsMenuItem = opaque {
    pub fn new(title: [*:0]const u8, options: []const [*:0]const u8) *AnyOptionsMenuItem {
        return @ptrCast(plt.pd.system_addOptionsMenuItem(title, options.ptr, @intCast(options.len), null, null));
    }
    pub fn newWithCallback(title: [*:0]const u8, options: []const [*:0]const u8, comptime callback: fn () void) *AnyOptionsMenuItem {
        return plt.pd.system_addOptionsMenuItem(title, options.ptr, @intCast(options.len), &AnyMenuItem.inner(callback), null);
    }
    pub fn getTitle(self: *const AnyOptionsMenuItem) [*:0]const u8 {
        return AnyMenuItem.getTitle(@ptrCast(self));
    }
    pub fn setTitle(self: *AnyOptionsMenuItem, title: [*:0]const u8) void {
        AnyMenuItem.setTitle(@ptrCast(self), title);
    }
    pub fn remove(self: *AnyOptionsMenuItem) void {
        AnyMenuItem.remove(@ptrCast(self));
    }
    pub fn getOption(self: *const AnyOptionsMenuItem) usize {
        const i = plt.pd.system_getMenuItemValue(@ptrCast(self));
        return if (i >= 0) @intCast(i) else unreachable;
    }
    pub fn setOption(self: *AnyOptionsMenuItem, option: usize) void {
        plt.pd.system_setMenuItemValue(@ptrCast(self), @intCast(option));
    }
};
pub fn OptionsMenuItem(comptime Userdata: type) type {
    return opaque {
        const Self = @This();

        pub fn new(title: [*:0]const u8, options: []const [*:0]const u8, userdata: *Userdata) *Self {
            return @ptrCast(plt.pd.system_addOptionsMenuItem(title, options.ptr, @intCast(options.len), null, userdata));
        }
        pub fn newWithCallback(title: [*:0]const u8, options: []const [*:0]const u8, comptime callback: fn (*Userdata) void, userdata: *Userdata) *Self {
            return @ptrCast(plt.pd.system_addOptionsMenuItem(title, options.ptr, @intCast(options.len), &MenuItem(Userdata).inner(callback), userdata));
        }
        pub fn getTitle(self: *const Self) [*:0]const u8 {
            return AnyMenuItem.getTitle(@ptrCast(self));
        }
        pub fn setTitle(self: *Self, title: [*:0]const u8) void {
            AnyMenuItem.setTitle(@ptrCast(self), title);
        }
        pub fn remove(self: *Self) void {
            AnyMenuItem.remove(@ptrCast(self));
        }
        pub fn getOption(self: *const Self) usize {
            return AnyOptionsMenuItem.getOption(@ptrCast(self));
        }
        pub fn setOption(self: *Self, option: usize) void {
            AnyOptionsMenuItem.setOption(@ptrCast(self), option);
        }
        pub fn getUserdata(self: *Self) *Userdata {
            return MenuItem(Userdata).getUserdata(@ptrCast(self));
        }
        pub fn setUserdata(self: *Self, userdata: *Userdata) void {
            MenuItem(Userdata).setUserdata(@ptrCast(self), userdata);
        }
    };
}
