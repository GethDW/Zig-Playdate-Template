const std = @import("std");
const pd = @import("playdate_api_definitions.zig");
const graphics = pd.graphics;
const Bitmap = graphics.Bitmap;
const Sprite = pd.sprite.Sprite;
const Buttons = pd.input.Buttons;
const filesystem = pd.filesystem;
const File = filesystem.File;

var sprite: *Sprite = undefined;
var i: u32 = undefined;
pub fn init() !void {
    sprite = try Sprite.new();
    const bitmap = try Bitmap.loadBitmap("playdate_image");
    sprite.setImage(bitmap, .BitmapUnflipped);
    sprite.moveTo(200, 120);
    sprite.add();
    i = 0;
}

pub fn update() !void {
    var buttons = Buttons.getButtons().pushed;
    if (buttons.up) {
        sprite.moveBy(0, -5);
        i +|= 1;
    } else if (buttons.down) {
        sprite.moveBy(0, 5);
        i -|= 1;
    }
    graphics.clear(.Black);
    pd.sprite.updateAndDrawSprites();
}

pub fn terminate() !void {
    const file = try File.open("test.txt", .{ .write = true });
    const writer = file.bufferedWriter();
    try writer.print("{d}\n", .{i});
    try file.flushAll();
    try file.close();
}
