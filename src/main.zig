const std = @import("std");
const pd = @import("playdate");
const Sprite = pd.sprite.Sprite;
const AnySprite = pd.sprite.AnySprite;

fn callback(y: *u32) void {
    switch (c.getChecked()) {
        .checked => pd.system.log("c = checked"),
        .unchecked => pd.system.log("c = unchecked"),
    }
    pd.system.log("o = %s", options[o.getOption()]);
    y.* += 1;
}
var x: u32 = 0;
var m: *pd.system.MenuItem(u32) = undefined;
var c: *pd.system.AnyCheckmarkMenuItem = undefined;
const options = [_][*:0]const u8{ "a", "b", "c" };
var o: *pd.system.AnyOptionsMenuItem = undefined;
pub fn init() !void {
    _ = pd.system.allocator();
    m = pd.system.MenuItem(u32).newWithCallback("normal", callback, &x);
    c = pd.system.AnyCheckmarkMenuItem.new("checkmark", .unchecked);
    o = pd.system.AnyOptionsMenuItem.new("options", &options);
    var s = try Sprite(u32).new();
    defer s.destroy();
    var u: *AnySprite = @ptrCast(try s.copy());
    defer u.destroy();
}

pub fn update() !void {
    pd.system.log("%d", x);
}
