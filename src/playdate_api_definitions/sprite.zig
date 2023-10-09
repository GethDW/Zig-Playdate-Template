const pdapi = @import("../playdate_api_definitions.zig");
const graphics = pdapi.graphics;

var spr: *const PlaydateSprite = undefined;
pub fn init(pdspr: *const PlaydateSprite) void {
    spr = pdspr;
}
pub const SpriteCollisionResponseType = enum(c_int) {
    CollisionTypeSlide,
    CollisionTypeFreeze,
    CollisionTypeOverlap,
    CollisionTypeBounce,
};
pub const PDRect = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub fn PDRectMake(x: f32, y: f32, width: f32, height: f32) callconv(.C) PDRect {
    return .{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };
}

pub const CollisionPoint = extern struct {
    x: f32,
    y: f32,
};
pub const CollisionVector = extern struct {
    x: c_int,
    y: c_int,
};

pub const SpriteCollisionInfo = extern struct {
    sprite: ?*Sprite, // The sprite being moved
    other: ?*Sprite, // The sprite being moved
    responseType: SpriteCollisionResponseType, // The result of collisionResponse
    overlaps: u8, // True if the sprite was overlapping other when the collision started. False if it didn’t overlap but tunneled through other.
    ti: f32, // A number between 0 and 1 indicating how far along the movement to the goal the collision occurred
    move: CollisionPoint, // The difference between the original coordinates and the actual ones when the collision happened
    normal: CollisionVector, // The collision normal; usually -1, 0, or 1 in x and y. Use this value to determine things like if your character is touching the ground.
    touch: CollisionPoint, // The coordinates where the sprite started touching other
    spriteRect: PDRect, // The rectangle the sprite occupied when the touch happened
    otherRect: PDRect, // The rectangle the sprite being collided with occupied when the touch happened
};

pub const SpriteQueryInfo = extern struct {
    sprite: ?*Sprite, // The sprite being intersected by the segment
    // ti1 and ti2 are numbers between 0 and 1 which indicate how far from the starting point of the line segment the collision happened
    ti1: f32, // entry point
    ti2: f32, // exit point
    entryPoint: CollisionPoint, // The coordinates of the first intersection between sprite and the line segment
    exitPoint: CollisionPoint, // The coordinates of the second intersection between sprite and the line segment
};

pub const CWCollisionInfo = opaque {};
pub const CWItemInfo = opaque {};
const SpriteDrawFunction = ?*const fn (sprite: *Sprite, bounds: PDRect, drawrect: PDRect) callconv(.C) void;
const SpriteUpdateFunction = ?*const fn (sprite: *Sprite) callconv(.C) void;
const SpriteCollisionFilterProc = ?*const fn (sprite: *Sprite, other: *Sprite) callconv(.C) SpriteCollisionResponseType;

/// updateAndDrawSprites: *const fn () callconv(.C) void,
pub fn updateAndDrawSprites() void {
    spr.updateAndDrawSprites();
}
pub const Sprite = opaque {
    /// newSprite: *const fn () callconv(.C) ?*Sprite,
    pub fn new() error{OutOfMemory}!*Sprite {
        return spr.newSprite() orelse error.OutOfMemory;
    }
    /// freeSprite: *const fn (sprite: *Sprite) callconv(.C) void,
    pub fn destroy(self: *Sprite) void {
        spr.freeSprite(self);
    }
    /// copy: *const fn (sprite: *Sprite) callconv(.C) ?*Sprite,
    pub fn copy(self: *Sprite) error{OutOfMemory}!*Sprite {
        return spr.copy(self) orelse error.OutOfMemory;
    }

    /// addSprite: *const fn (sprite: *Sprite) callconv(.C) void,
    pub fn add(self: *Sprite) void {
        spr.addSprite(self);
    }
    /// removeSprite: *const fn (sprite: *Sprite) callconv(.C) void,
    pub fn remove(self: *Sprite) void {
        spr.removeSprite(self);
    }
    /// setBounds: *const fn (sprite: *Sprite, bounds: PDRect) callconv(.C) void,
    pub fn setBounds(self: *Sprite, bounds: PDRect) void {
        spr.setBounds(self, bounds);
    }
    /// getBounds: *const fn (sprite: *Sprite) callconv(.C) PDRect,
    pub fn getBounds(self: *Sprite) PDRect {
        return spr.getBounds(self);
    }
    /// moveTo: *const fn (sprite: *Sprite, x: f32, y: f32) callconv(.C) void,
    pub fn moveTo(self: *Sprite, x: f32, y: f32) void {
        spr.moveTo(self, x, y);
    }
    // moveBy: *const fn (sprite: *Sprite, dx: f32, dy: f32) callconv(.C) void,
    pub fn moveBy(self: *Sprite, dx: f32, dy: f32) void {
        spr.moveBy(self, dx, dy);
    }
    /// setImage: *const fn (sprite: *Sprite, image: *Bitmap, flip: BitmapFlip) callconv(.C) void,
    pub fn setImage(self: *Sprite, image: *graphics.Bitmap, flip: graphics.BitmapFlip) void {
        spr.setImage(self, image, flip);
    }
    /// getImage: *const fn (sprite: *Sprite) callconv(.C) ?*Bitmap,
    pub fn getImage(self: *Sprite) ?*graphics.Bitmap {
        return spr.getImage(self);
    }

    /// drawSprites: *const fn () callconv(.C) void,
    pub fn drawSprites() void {
        spr.drawSprites();
    }
};

pub const PlaydateSprite = extern struct {
    setAlwaysRedraw: *const fn (flag: c_int) callconv(.C) void,
    addDirtyRect: *const fn (dirtyRect: graphics.LCDRect) callconv(.C) void,
    drawSprites: *const fn () callconv(.C) void,
    updateAndDrawSprites: *const fn () callconv(.C) void,

    newSprite: *const fn () callconv(.C) ?*Sprite,
    freeSprite: *const fn (sprite: *Sprite) callconv(.C) void,
    copy: *const fn (sprite: *Sprite) callconv(.C) ?*Sprite,

    addSprite: *const fn (sprite: *Sprite) callconv(.C) void,
    removeSprite: *const fn (sprite: *Sprite) callconv(.C) void,
    removeSprites: *const fn (sprite: [*]*Sprite, count: c_int) callconv(.C) void,
    removeAllSprites: *const fn () callconv(.C) void,
    getSpriteCount: *const fn () callconv(.C) c_int,

    setBounds: *const fn (sprite: *Sprite, bounds: PDRect) callconv(.C) void,
    getBounds: *const fn (sprite: *Sprite) callconv(.C) PDRect,
    moveTo: *const fn (sprite: *Sprite, x: f32, y: f32) callconv(.C) void,
    moveBy: *const fn (sprite: *Sprite, dx: f32, dy: f32) callconv(.C) void,

    setImage: *const fn (sprite: *Sprite, image: *graphics.Bitmap, flip: graphics.BitmapFlip) callconv(.C) void,
    getImage: *const fn (sprite: *Sprite) callconv(.C) ?*graphics.Bitmap,
    setSize: *const fn (s: *Sprite, width: f32, height: f32) callconv(.C) void,
    setZIndex: *const fn (s: *Sprite, zIndex: i16) callconv(.C) void,
    getZIndex: *const fn (sprite: *Sprite) callconv(.C) i16,

    setDrawMode: *const fn (sprite: *Sprite, mode: graphics.BitmapDrawMode) callconv(.C) void,
    setImageFlip: *const fn (sprite: *Sprite, flip: graphics.BitmapFlip) callconv(.C) void,
    getImageFlip: *const fn (sprite: *Sprite) callconv(.C) graphics.BitmapFlip,
    setStencil: *const fn (sprite: *Sprite, mode: ?*graphics.Bitmap) callconv(.C) void, // deprecated in favor of setStencilImage()

    setClipRect: *const fn (sprite: *Sprite, clipRect: graphics.LCDRect) callconv(.C) void,
    clearClipRect: *const fn (sprite: *Sprite) callconv(.C) void,
    setClipRectsInRange: *const fn (clipRect: graphics.LCDRect, startZ: c_int, endZ: c_int) callconv(.C) void,
    clearClipRectsInRange: *const fn (startZ: c_int, endZ: c_int) callconv(.C) void,

    setUpdatesEnabled: *const fn (sprite: *Sprite, flag: c_int) callconv(.C) void,
    updatesEnabled: *const fn (sprite: *Sprite) callconv(.C) c_int,
    setCollisionsEnabled: *const fn (sprite: *Sprite, flag: c_int) callconv(.C) void,
    collisionsEnabled: *const fn (sprite: *Sprite) callconv(.C) c_int,
    setVisible: *const fn (sprite: *Sprite, flag: c_int) callconv(.C) void,
    isVisible: *const fn (sprite: *Sprite) callconv(.C) c_int,
    setOpaque: *const fn (sprite: *Sprite, flag: c_int) callconv(.C) void,
    markDirty: *const fn (sprite: *Sprite) callconv(.C) void,

    setTag: *const fn (sprite: *Sprite, tag: u8) callconv(.C) void,
    getTag: *const fn (sprite: *Sprite) callconv(.C) u8,

    setIgnoresDrawOffset: *const fn (sprite: *Sprite, flag: c_int) callconv(.C) void,

    setUpdateFunction: *const fn (sprite: *Sprite, func: SpriteUpdateFunction) callconv(.C) void,
    setDrawFunction: *const fn (sprite: *Sprite, func: SpriteDrawFunction) callconv(.C) void,

    getPosition: *const fn (s: *Sprite, x: ?*f32, y: ?*f32) callconv(.C) void,

    // Collisions
    resetCollisionWorld: *const fn () callconv(.C) void,

    setCollideRect: *const fn (sprite: *Sprite, collideRect: PDRect) callconv(.C) void,
    getCollideRect: *const fn (sprite: *Sprite) callconv(.C) PDRect,
    clearCollideRect: *const fn (sprite: *Sprite) callconv(.C) void,

    // caller is responsible for freeing the returned array for all collision methods
    setCollisionResponseFunction: *const fn (sprite: ?*Sprite, func: SpriteCollisionFilterProc) callconv(.C) void,
    checkCollisions: *const fn (sprite: ?*Sprite, goalX: f32, goalY: f32, actualX: ?*f32, actualY: ?*f32, len: ?*c_int) callconv(.C) [*c]SpriteCollisionInfo, // access results using const info = &results[i];
    moveWithCollisions: *const fn (sprite: ?*Sprite, goalX: f32, goalY: f32, actualX: ?*f32, actualY: ?*f32, len: ?*c_int) callconv(.C) [*c]SpriteCollisionInfo,
    querySpritesAtPoint: *const fn (x: f32, y: f32, len: ?*c_int) callconv(.C) [*c]?*Sprite,
    querySpritesInRect: *const fn (x: f32, y: f32, width: f32, height: f32, len: ?*c_int) callconv(.C) [*c]?*Sprite,
    querySpritesAlongLine: *const fn (x1: f32, y1: f32, x2: f32, y2: f32, len: ?*c_int) callconv(.C) [*c]?*Sprite,
    querySpriteInfoAlongLine: *const fn (x1: f32, y1: f32, x2: f32, y2: f32, len: ?*c_int) callconv(.C) [*c]SpriteQueryInfo, // access results using const info = &results[i];
    overlappingSprites: *const fn (sprite: ?*Sprite, len: ?*c_int) callconv(.C) [*c]?*Sprite,
    allOverlappingSprites: *const fn (len: ?*c_int) callconv(.C) [*c]?*Sprite,

    // added in 1.7
    setStencilPattern: *const fn (sprite: ?*Sprite, pattern: [*c]u8) callconv(.C) void, //pattern is 8 bytes
    clearStencil: *const fn (sprite: ?*Sprite) callconv(.C) void,

    setUserdata: *const fn (sprite: ?*Sprite, userdata: ?*anyopaque) callconv(.C) void,
    getUserdata: *const fn (sprite: ?*Sprite) callconv(.C) ?*anyopaque,

    // added in 1.10
    setStencilImage: *const fn (sprite: ?*Sprite, stencil: ?*graphics.Bitmap, tile: c_int) callconv(.C) void,
};
