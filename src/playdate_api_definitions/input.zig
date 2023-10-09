const std = @import("std");
const pdapi = @import("../playdate_api_definitions.zig");

var getButtonState: *const fn (?*Buttons, ?*Buttons, ?*Buttons) callconv(.C) void = undefined;
pub fn init(sys: *const pdapi.system.PlaydateSys) void {
    getButtonState = sys.getButtonState;
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
        getButtonState(&current, &pushed, &released);
        return .{
            .current = current,
            .pushed = pushed,
            .released = released,
        };
    }

    comptime {
        const assert = std.debug.assert;
        assert(@as(c_int, @bitCast(Buttons{ .left = true })) == BUTTON_LEFT);
        assert(@as(c_int, @bitCast(Buttons{ .right = true })) == BUTTON_RIGHT);
        assert(@as(c_int, @bitCast(Buttons{ .up = true })) == BUTTON_UP);
        assert(@as(c_int, @bitCast(Buttons{ .down = true })) == BUTTON_DOWN);
        assert(@as(c_int, @bitCast(Buttons{ .b = true })) == BUTTON_B);
        assert(@as(c_int, @bitCast(Buttons{ .a = true })) == BUTTON_A);
    }
};
