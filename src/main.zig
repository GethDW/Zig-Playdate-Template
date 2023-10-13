const std = @import("std");
const pd = @import("playdate_api_definitions.zig");
const graphics = pd.graphics;
const Bitmap = graphics.Bitmap;
const Sprite = pd.sprite.Sprite;
const Buttons = pd.input.Buttons;
const filesystem = pd.filesystem;
const File = filesystem.File;
const lua = pd.lua;

const Thing = struct {
    x: u32,
    pub fn new() c_int {
        const allocator = pd.system.allocator();
        const self = allocator.create(Thing) catch unreachable;
        self.x = 0;
        _ = lua.lua.pushObject(self, "Thing", 0);
        // pd.system.log("created Thing @%p", self);
        return 1;
    }
    pub fn deinit() c_int {
        const self: *Thing = @ptrCast(@alignCast(lua.lua.getArgObject(1, "Thing", null).?));
        const allocator = pd.system.allocator();
        allocator.destroy(self);
        // pd.system.log("collected Thing @%p", self);
        return 0;
    }
    pub fn inc() c_int {
        const self: *Thing = @ptrCast(@alignCast(lua.lua.getArgObject(1, "Thing", null).?));
        self.x += 1;
        return 0;
    }
    pub fn print() c_int {
        const self: *Thing = @ptrCast(@alignCast(lua.lua.getArgObject(1, "Thing", null).?));
        pd.system.log("%d", self.x);
        return 0;
    }
};
pub fn initLua() !void {
    try lua.registerClass("Thing", &.{
        .{ "new", Thing.new },
        .{ "__gc", Thing.deinit },
        .{ "print", Thing.print },
        .{ "inc", Thing.inc },
    }, false);
}

var sprite: *Sprite(u32) = undefined;
var i: u32 = undefined;
fn updateSpr(self: *Sprite(u32)) void {
    const ud = self.getUserdata().?;
    ud.* = 1234;
}
pub fn init() !void {
    i = 0;
    sprite = try Sprite(u32).new();
    sprite.setUserdata(&i);
    sprite.setUpdateFunction(updateSpr);
    const bitmap = try Bitmap.loadBitmap("playdate_image");
    sprite.setImage(bitmap, .BitmapUnflipped);
    sprite.moveTo(200, 120);
    sprite.add();
}

pub fn terminate() !void {
    const file = try File.open("test.txt", .{ .write = true });
    const writer = file.bufferedWriter();
    try writer.print("{d}\n", .{i});
    try file.flushAll();
    try file.close();
    pd.system.log("%u", sprite.getUserdata().?.*);
}
