const std = @import("std");
const pdapi = @import("../playdate_api_definitions.zig");
const graphics = pdapi.graphics;

pub fn setAlwaysRedraw(enable: bool) void {
    spr.setAlwaysRedraw(@intFromBool(enable));
}
pub fn addDirtyRect(rect: graphics.LCDRect) void {
    spr.addDirtyRect(rect);
}
pub fn drawSprites() void {
    spr.drawSprites();
}
pub fn updateAndDrawSprites() void {
    spr.updateAndDrawSprites();
}
pub fn removeSprites(sprites: []*AnySprite) void {
    spr.removeSprites(sprites.ptr, @intCast(sprites.len));
}
pub fn removeAllSprites() void {
    spr.removeAllSprites();
}
pub fn getSpriteCount() u16 {
    return @intCast(spr.getSpriteCount());
}
pub fn setClipRectsInRange(rect: graphics.LCDRect, start_z: c_int, end_z: c_int) void {
    spr.setClipRectsInRange(rect, start_z, end_z);
}
pub fn clearClipRectsInRange(start_z: c_int, end_z: c_int) void {
    spr.clearClipRectsInRange(start_z, end_z);
}
pub fn resetCollisionWorld() void {
    spr.resetCollisionWorld();
}

/// A sprite with `userdata` of type Userdata. This
/// has the same API as AnySprite, but also has methods
/// for setting and getting userdata.
/// If the sprite has no userdata, or userdata is not used, it is
/// recommended to use AnySprite instead.
pub fn Sprite(comptime Userdata: type) type {
    return opaque {
        const Self = @This();

        pub fn setUserdata(self: *Self, userdata: *Userdata) void {
            spr.setUserdata(self.any(), userdata);
        }
        /// returns null if setUserdata has not yet been called
        pub fn getUserdata(self: *Self) ?*Userdata {
            return @ptrCast(@alignCast(spr.getUserdata(self.any())));
        }

        pub fn new() error{OutOfMemory}!*Self {
            return @ptrCast(try AnySprite.new());
        }
        pub fn destroy(self: *Self) void {
            AnySprite.destroy(@ptrCast(self));
        }
        pub fn copy(self: *Self) error{OutOfMemory}!*Self {
            return @ptrCast(try AnySprite.copy(@ptrCast(self)));
        }

        pub fn add(self: *Self) void {
            AnySprite.add(@ptrCast(self));
        }
        pub fn remove(self: *Self) void {
            AnySprite.remove(@ptrCast(self));
        }

        pub fn setBounds(self: *Self, bounds: Rect) void {
            AnySprite.setBounds(@ptrCast(self), bounds);
        }
        pub fn getBounds(self: *Self) Rect {
            return AnySprite.getBounds(@ptrCast(self));
        }

        pub fn moveTo(self: *Self, x: f32, y: f32) void {
            AnySprite.moveTo(@ptrCast(self), x, y);
        }
        pub fn moveBy(self: *Self, dx: f32, dy: f32) void {
            AnySprite.moveBy(@ptrCast(self), dx, dy);
        }

        pub fn setImage(self: *Self, image: *graphics.Bitmap, flip: graphics.BitmapFlip) void {
            AnySprite.setImage(@ptrCast(self), image, flip);
        }
        pub fn getImage(self: *Self) ?*graphics.Bitmap {
            return AnySprite.getImage(@ptrCast(self));
        }

        pub fn setSize(self: *Self, width: f32, height: f32) void {
            AnySprite.setSize(@ptrCast(self), width, height);
        }
        pub fn setZIndex(self: *Self, z_index: i16) void {
            AnySprite.setZIndex(@ptrCast(self), z_index);
        }
        pub fn getZIndex(self: *Self) i16 {
            return AnySprite.getZIndex(@ptrCast(self));
        }

        pub fn setDrawMode(self: *Sprite, mode: graphics.BitmapDrawMode) void {
            AnySprite.setDrawMode(@ptrCast(self), mode);
        }
        pub fn setImageFlip(self: *Sprite, flip: graphics.BitmapFlip) void {
            AnySprite.setImageFlip(@ptrCast(self), flip);
        }
        pub fn getImageFlip(self: *Sprite) graphics.BitmapFlip {
            return AnySprite.getImageFlip(@ptrCast(self));
        }
        pub fn setClipRect(self: *Sprite, clip_rect: graphics.LCDRect) void {
            AnySprite.setClipRect(@ptrCast(self), self, clip_rect);
        }
        pub fn clearClipRect(self: *Sprite) void {
            AnySprite.clearClipRect(@ptrCast(self));
        }
        pub fn setUpdatesEnabled(self: *Sprite, enabled: bool) void {
            self.any().setUpdatesEnabled(enabled);
        }
        pub fn updatesEnabled(self: *Sprite) bool {
            return AnySprite.updatesEnabled(@ptrCast(self));
        }
        pub fn setCollisionsEnabled(self: *Self, enabled: bool) void {
            AnySprite.setCollisionsEnabled(@ptrCast(self), enabled);
        }
        pub fn collisionsEnabled(self: *Self) bool {
            return AnySprite.collisionsEnabled(@ptrCast(self));
        }
        pub fn setVisible(self: *Self, enabled: bool) void {
            AnySprite.setVisible(@ptrCast(self), enabled);
        }
        pub fn isVisible(self: *Self) c_int {
            return AnySprite.isVisible(@ptrCast(self));
        }
        pub fn setOpaque(self: *Self, enabled: bool) void {
            AnySprite.setOpaque(@ptrCast(self), enabled);
        }
        pub fn markDirty(self: *Self) void {
            AnySprite.markDirty(@ptrCast(self));
        }

        pub fn setTag(self: *Self, tag: u8) void {
            AnySprite.setTag(@ptrCast(self), tag);
        }
        pub fn getTag(self: *Self) u8 {
            return AnySprite.getTag(@ptrCast(self));
        }

        pub fn setIgnoresDrawOffset(self: *Self, enabled: bool) void {
            AnySprite.setIgnoresDrawOffset(@ptrCast(self), enabled);
        }

        pub fn setUpdateFunction(
            self: *Self,
            comptime update: fn (self: *Self) void,
        ) void {
            AnySprite.setUpdateFunction(@ptrCast(self), struct {
                pub fn f(s: *AnySprite) void {
                    update(@ptrCast(s));
                }
            }.f);
        }

        pub fn setDrawFunction(
            self: *Self,
            comptime draw: fn (self: *Self, bounds: Rect, drawrect: Rect) void,
        ) void {
            AnySprite.setDrawFunction(@ptrCast(self), struct {
                pub fn f(s: *AnySprite, bounds: Rect, drawrect: Rect) void {
                    draw(@ptrCast(s), bounds, drawrect);
                }
            }.f);
        }

        pub fn getPosition(self: *Self) struct { x: f32, y: f32 } {
            return AnySprite.getPosition(@ptrCast(self));
        }

        pub fn setCollideRect(self: *Self, collide_rect: Rect) void {
            AnySprite.setCollideRect(@ptrCast(self), collide_rect);
        }
        pub fn getCollideRect(self: *Self) Rect {
            return AnySprite.getCollideRect(@ptrCast(self));
        }
        pub fn clearCollideRect(self: *Self) void {
            AnySprite.clearCollideRect(@ptrCast(self));
        }

        pub fn setCollisionResponseFunction(
            self: *Self,
            comptime func: fn (self: *Self, other: *AnySprite) CollisionResponse,
        ) void {
            AnySprite.setCollisionResponseFunction(@ptrCast(self), struct {
                pub fn f(s: *AnySprite, o: *AnySprite) CollisionResponse {
                    return func(@ptrCast(s), o);
                }
            }.f);
        }

        /// caller owns memory
        pub fn checkCollisions(
            self: *Self,
            /// the x position to move to
            x: f32,
            /// the y position to move to
            y: f32,
        ) CollisionResolution {
            return AnySprite.checkCollisions(@ptrCast(self), x, y);
        }

        /// caller owns memory
        pub fn moveWithCollisions(
            self: *Self,
            /// the x position to move to
            x: f32,
            /// the y position to move to
            y: f32,
        ) CollisionResolution {
            return AnySprite.moveWithCollisions(@ptrCast(self), x, y);
        }

        /// caller owns memory
        pub fn overlappingSprites(self: *Self) []*AnySprite {
            return AnySprite.overlappingSprites(@ptrCast(self));
        }

        pub fn setStencilPattern(self: *Self, pattern: [8]u8) void {
            AnySprite.setStencilPattern(@ptrCast(self), pattern);
        }
        pub fn clearStencil(self: *Self) void {
            AnySprite.clearStencil(@ptrCast(self));
        }

        pub fn setStencilImage(self: *Self, stencil: *graphics.Bitmap, tile: bool) void {
            AnySprite.setStencilImage(@ptrCast(self), stencil, tile);
        }
    };
}

/// A sprite who's `userdata` type is not known.
/// Useful for functions that are generic of any kind of sprite
/// such as functions that do not access the sprites userdata.
pub const AnySprite = opaque {
    pub fn new() error{OutOfMemory}!*AnySprite {
        return spr.newSprite() orelse error.OutOfMemory;
    }
    pub fn destroy(self: *AnySprite) void {
        spr.freeSprite(self);
    }
    pub fn copy(self: *AnySprite) error{OutOfMemory}!*AnySprite {
        return spr.copy(self) orelse error.OutOfMemory;
    }
    pub fn add(self: *AnySprite) void {
        spr.addSprite(self);
    }
    pub fn remove(self: *AnySprite) void {
        spr.removeSprite(self);
    }
    pub fn setBounds(self: *AnySprite, bounds: Rect) void {
        spr.setBounds(self, bounds);
    }
    pub fn getBounds(self: *AnySprite) Rect {
        return spr.getBounds(self);
    }
    pub fn moveTo(self: *AnySprite, x: f32, y: f32) void {
        spr.moveTo(self, x, y);
    }
    pub fn moveBy(self: *AnySprite, dx: f32, dy: f32) void {
        spr.moveBy(self, dx, dy);
    }
    pub fn setImage(self: *AnySprite, image: *graphics.Bitmap, flip: graphics.BitmapFlip) void {
        spr.setImage(self, image, flip);
    }
    pub fn getImage(self: *AnySprite) ?*graphics.Bitmap {
        return spr.getImage(self);
    }
    pub fn setSize(self: *AnySprite, width: f32, height: f32) void {
        spr.setSize(self, width, height);
    }
    pub fn setZIndex(self: *AnySprite, z_index: i16) void {
        spr.setZIndex(self, z_index);
    }
    pub fn getZIndex(self: *AnySprite) i16 {
        return spr.getZIndex(self);
    }

    pub fn setDrawMode(self: *AnySprite, mode: graphics.BitmapDrawMode) void {
        spr.setDrawMode(self, mode);
    }
    pub fn setImageFlip(self: *AnySprite, flip: graphics.BitmapFlip) void {
        spr.setImageFlip(self, flip);
    }
    pub fn getImageFlip(self: *AnySprite) graphics.BitmapFlip {
        return spr.getImageFlip(self);
    }
    pub fn setClipRect(self: *AnySprite, clip_rect: graphics.LCDRect) void {
        spr.setClipRect(self, clip_rect);
    }
    pub fn clearClipRect(self: *AnySprite) void {
        spr.clearClipRect(self);
    }
    pub fn setUpdatesEnabled(self: *AnySprite, enabled: bool) void {
        spr.setUpdatesEnabled(self, @intFromBool(enabled));
    }
    pub fn updatesEnabled(self: *AnySprite) bool {
        return switch (spr.updatesEnabled(self)) {
            0 => false,
            1 => true,
            else => unreachable,
        };
    }
    pub fn setCollisionsEnabled(self: *AnySprite, enabled: bool) void {
        spr.setCollisionsEnabled(self, @intFromBool(enabled));
    }
    pub fn collisionsEnabled(self: *AnySprite) bool {
        return switch (spr.collisionsEnabled(self)) {
            0 => false,
            1 => true,
            else => unreachable,
        };
    }
    pub fn setVisible(self: *AnySprite, enabled: bool) void {
        spr.setVisible(self, @intFromBool(enabled));
    }
    pub fn isVisible(self: *AnySprite) bool {
        return switch (spr.isVisible(self)) {
            0 => false,
            1 => true,
            else => unreachable,
        };
    }
    pub fn setOpaque(self: *AnySprite, enabled: bool) void {
        spr.setOpaque(self, @intFromBool(enabled));
    }
    pub fn markDirty(self: *AnySprite) void {
        spr.markDirty(self);
    }

    pub fn setTag(self: *AnySprite, tag: u8) void {
        spr.setTag(self, tag);
    }
    pub fn getTag(self: *AnySprite) u8 {
        return spr.getTag(self);
    }

    pub fn setIgnoresDrawOffset(self: *AnySprite, enabled: bool) void {
        spr.setIgnoresDrawOffset(self, @intFromBool(enabled));
    }

    pub fn setUpdateFunction(self: *AnySprite, comptime update: fn (self: *AnySprite) void) void {
        spr.setUpdateFunction(self, struct {
            pub fn f(s: *AnySprite) callconv(.C) void {
                update(s);
            }
        }.f);
    }

    pub fn setDrawFunction(
        self: *AnySprite,
        comptime draw: fn (self: *AnySprite, bounds: Rect, drawrect: Rect) void,
    ) void {
        spr.setDrawFunction(self, struct {
            pub fn f(s: *AnySprite, bounds: Rect, drawrect: Rect) callconv(.C) void {
                draw(s, bounds, drawrect);
            }
        }.f);
    }

    pub fn getPosition(self: *AnySprite) struct { x: f32, y: f32 } {
        var x, var y = [_]f32{undefined} ** 2;
        spr.getPosition(self, &x, &y);
        return .{ .x = x, .y = y };
    }

    pub fn setCollideRect(self: *AnySprite, collide_rect: Rect) void {
        spr.setCollideRect(self, collide_rect);
    }
    pub fn getCollideRect(self: *AnySprite) Rect {
        return spr.getCollideRect(self);
    }
    pub fn clearCollideRect(self: *AnySprite) void {
        spr.clearCollideRect(self);
    }

    pub fn setCollisionResponseFunction(
        self: *AnySprite,
        comptime func: fn (self: *AnySprite, other: *AnySprite) CollisionResponse,
    ) void {
        spr.setCollisionResponseFunction(self, struct {
            pub fn f(s: *AnySprite, o: *AnySprite) callconv(.C) CollisionResponse {
                return func(s, o);
            }
        }.f);
    }

    /// caller owns memory
    pub fn checkCollisions(
        self: *AnySprite,
        /// the x position to move to
        x: f32,
        /// the y position to move to
        y: f32,
    ) CollisionResolution {
        var actualX, var actualY = [_]f32{undefined} ** 2;
        var len: c_int = undefined;
        const ptr = spr.checkCollisions(self, x, y, &actualX, &actualY, &len);
        std.debug.assert((ptr == null and len == 0) or (ptr != null and len != 0));
        return .{
            .x = actualX,
            .y = actualY,
            .collisions = if (ptr) |p| p[0..@intCast(len)] else &.{},
        };
    }

    /// caller owns memory
    pub fn moveWithCollisions(
        self: *AnySprite,
        /// the x position to move to
        x: f32,
        /// the y position to move to
        y: f32,
    ) CollisionResolution {
        var actualX, var actualY = [_]f32{undefined} ** 2;
        var len: c_int = undefined;
        const ptr = spr.moveWithCollisions(self, x, y, &actualX, &actualY, &len);
        std.debug.assert((ptr == null and len == 0) or (ptr != null and len != 0));
        return .{
            .x = actualX,
            .y = actualY,
            .collisions = if (ptr) |p| p[0..@intCast(len)] else &.{},
        };
    }

    /// caller owns memory
    pub fn overlappingSprites(self: *AnySprite) []*AnySprite {
        var len: c_int = undefined;
        const ptr = spr.overlappingSprites(self, &len);
        return ptr[0..@intCast(len)];
    }

    pub fn setStencilPattern(self: *AnySprite, pattern: [8]u8) void {
        spr.setStencilPattern(self, &pattern);
    }
    pub fn clearStencil(self: *AnySprite) void {
        spr.clearStencil(self);
    }

    pub fn setStencilImage(self: *AnySprite, stencil: *graphics.Bitmap, tile: bool) void {
        spr.setStencilImage(self, stencil, @intFromBool(tile));
    }
};

pub const query = struct {
    pub const Info = extern struct {
        /// The sprite being intersected by the segment
        sprite: *AnySprite,
        /// ti1 and ti2 are numbers between 0 and 1 which indicate how far from the starting point of the line segment the collision happened
        ti1: f32, // entry point
        ti2: f32, // exit point
        /// The coordinates of the first intersection between sprite and the line segment
        entryPoint: CollisionPoint,
        /// The coordinates of the second intersection between sprite and the line segment
        exitPoint: CollisionPoint,
    };

    /// caller owns memory
    pub fn spritesAtPoint(x: f32, y: f32) []*AnySprite {
        var len: c_int = undefined;
        const ptr = spr.querySpritesAtPoint(x, y, &len);
        return ptr[0..@intCast(len)];
    }
    /// caller owns memory
    pub fn spritesInRect(rect: Rect) []*AnySprite {
        var len: c_int = undefined;
        const ptr = spr.querySpritesInRect(rect.x, rect.y, rect.width, rect.height, &len);
        return ptr[0..@intCast(len)];
    }
    /// caller owns memory
    pub fn spritesAlongLine(x1: f32, y1: f32, x2: f32, y2: f32) []*AnySprite {
        var len: c_int = undefined;
        const ptr = spr.querySpritesAlongLine(x1, y1, x2, y2, &len);
        return ptr[0..@intCast(len)];
    }
    /// caller owns memory
    pub fn spriteInfoAlongLine(x1: f32, y1: f32, x2: f32, y2: f32) []Info {
        var len: c_int = undefined;
        const ptr = spr.querySpriteInfoAlongLine(x1, y1, x2, y2, &len);
        return ptr[0..@intCast(len)];
    }
    /// caller owns memory
    pub fn allOverlappingSprites() []*AnySprite {
        var len: c_int = undefined;
        const ptr = spr.allOverlappingSprites(&len);
        return ptr[0..@intCast(len)];
    }
};

pub const CollisionResponse = enum(c_int) {
    Slide,
    Freeze,
    Overlap,
    Bounce,
};

pub const Rect = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const CollisionPoint = extern struct {
    x: f32,
    y: f32,
};
pub const CollisionVector = extern struct {
    x: c_int,
    y: c_int,
};

pub const CollisionInfo = extern struct {
    /// The sprite being moved
    sprite: *AnySprite,
    /// The sprite being moved
    other: *AnySprite,
    /// The result of collisionResponse
    responseType: CollisionResponse,
    /// True if the sprite was overlapping other when the collision started. False if it didn’t overlap but tunneled through other.
    overlaps: u8,
    /// A number between 0 and 1 indicating how far along the movement to the goal the collision occurred
    ti: f32,
    /// The difference between the original coordinates and the actual ones when the collision happened
    move: CollisionPoint,
    /// The collision normal; usually -1, 0, or 1 in x and y. Use this value to determine things like if your character is touching the ground.
    normal: CollisionVector,
    /// The coordinates where the sprite started touching other
    touch: CollisionPoint,
    /// The rectangle the sprite occupied when the touch happened
    spriteRect: Rect,
    /// The rectangle the sprite being collided with occupied when the touch happened
    otherRect: Rect,
};

pub const CollisionResolution = struct {
    /// the x position after collision
    x: f32,
    /// the y position after collision
    y: f32,
    /// info about any collisions that would occur
    collisions: []CollisionInfo,

    pub fn free(self: *CollisionResolution) void {
        pdapi.system.allocator().free(self.collisions);
        self.* = undefined;
    }
};

///// RAW BINDINGS /////
var spr: *const PlaydateSprite = undefined;
pub fn init(pdspr: *const PlaydateSprite) void {
    spr = pdspr;
}

pub const PlaydateSprite = extern struct {
    const UpdateFunction = fn (sprite: *AnySprite) callconv(.C) void;
    const DrawFunction = fn (sprite: *AnySprite, bounds: Rect, drawrect: Rect) callconv(.C) void;
    const CollisionFilterProc = fn (sprite: *AnySprite, other: *AnySprite) callconv(.C) CollisionResponse;

    setAlwaysRedraw: *const fn (flag: c_int) callconv(.C) void,
    addDirtyRect: *const fn (dirtyRect: graphics.LCDRect) callconv(.C) void,
    drawSprites: *const fn () callconv(.C) void,
    updateAndDrawSprites: *const fn () callconv(.C) void,

    newSprite: *const fn () callconv(.C) ?*AnySprite,
    freeSprite: *const fn (sprite: *AnySprite) callconv(.C) void,
    copy: *const fn (sprite: *AnySprite) callconv(.C) ?*AnySprite,

    addSprite: *const fn (sprite: *AnySprite) callconv(.C) void,
    removeSprite: *const fn (sprite: *AnySprite) callconv(.C) void,
    removeSprites: *const fn (sprites: [*]*AnySprite, count: c_int) callconv(.C) void,
    removeAllSprites: *const fn () callconv(.C) void,
    getSpriteCount: *const fn () callconv(.C) c_int,

    setBounds: *const fn (sprite: *AnySprite, bounds: Rect) callconv(.C) void,
    getBounds: *const fn (sprite: *AnySprite) callconv(.C) Rect,
    moveTo: *const fn (sprite: *AnySprite, x: f32, y: f32) callconv(.C) void,
    moveBy: *const fn (sprite: *AnySprite, dx: f32, dy: f32) callconv(.C) void,

    setImage: *const fn (sprite: *AnySprite, image: *graphics.Bitmap, flip: graphics.BitmapFlip) callconv(.C) void,
    getImage: *const fn (sprite: *AnySprite) callconv(.C) ?*graphics.Bitmap,
    setSize: *const fn (s: *AnySprite, width: f32, height: f32) callconv(.C) void,
    setZIndex: *const fn (s: *AnySprite, z_index: i16) callconv(.C) void,
    getZIndex: *const fn (sprite: *AnySprite) callconv(.C) i16,

    setDrawMode: *const fn (sprite: *AnySprite, mode: graphics.BitmapDrawMode) callconv(.C) void,
    setImageFlip: *const fn (sprite: *AnySprite, flip: graphics.BitmapFlip) callconv(.C) void,
    getImageFlip: *const fn (sprite: *AnySprite) callconv(.C) graphics.BitmapFlip,
    setStencil: *const fn (sprite: *AnySprite, mode: *graphics.Bitmap) callconv(.C) void, // deprecated in favor of setStencilImage()

    setClipRect: *const fn (sprite: *AnySprite, clipRect: graphics.LCDRect) callconv(.C) void,
    clearClipRect: *const fn (sprite: *AnySprite) callconv(.C) void,
    setClipRectsInRange: *const fn (clipRect: graphics.LCDRect, startZ: c_int, endZ: c_int) callconv(.C) void,
    clearClipRectsInRange: *const fn (startZ: c_int, endZ: c_int) callconv(.C) void,

    setUpdatesEnabled: *const fn (sprite: *AnySprite, flag: c_int) callconv(.C) void,
    updatesEnabled: *const fn (sprite: *AnySprite) callconv(.C) c_int,
    setCollisionsEnabled: *const fn (sprite: *AnySprite, flag: c_int) callconv(.C) void,
    collisionsEnabled: *const fn (sprite: *AnySprite) callconv(.C) c_int,
    setVisible: *const fn (sprite: *AnySprite, flag: c_int) callconv(.C) void,
    isVisible: *const fn (sprite: *AnySprite) callconv(.C) c_int,
    setOpaque: *const fn (sprite: *AnySprite, flag: c_int) callconv(.C) void,
    markDirty: *const fn (sprite: *AnySprite) callconv(.C) void,

    setTag: *const fn (sprite: *AnySprite, tag: u8) callconv(.C) void,
    getTag: *const fn (sprite: *AnySprite) callconv(.C) u8,

    setIgnoresDrawOffset: *const fn (sprite: *AnySprite, flag: c_int) callconv(.C) void,

    setUpdateFunction: *const fn (sprite: *AnySprite, func: *const UpdateFunction) callconv(.C) void,
    setDrawFunction: *const fn (sprite: *AnySprite, func: *const DrawFunction) callconv(.C) void,

    getPosition: *const fn (s: *AnySprite, x: *f32, y: *f32) callconv(.C) void,

    // Collisions
    resetCollisionWorld: *const fn () callconv(.C) void,

    setCollideRect: *const fn (sprite: *AnySprite, collideRect: Rect) callconv(.C) void,
    getCollideRect: *const fn (sprite: *AnySprite) callconv(.C) Rect,
    clearCollideRect: *const fn (sprite: *AnySprite) callconv(.C) void,

    // caller is responsible for freeing the returned array for all collision methods
    setCollisionResponseFunction: *const fn (sprite: *AnySprite, func: *const CollisionFilterProc) callconv(.C) void,
    checkCollisions: *const fn (sprite: *AnySprite, goalX: f32, goalY: f32, actualX: *f32, actualY: *f32, len: *c_int) callconv(.C) [*]CollisionInfo, // access results using const info = &results[i];
    moveWithCollisions: *const fn (sprite: *AnySprite, goalX: f32, goalY: f32, actualX: *f32, actualY: *f32, len: *c_int) callconv(.C) [*]CollisionInfo,
    querySpritesAtPoint: *const fn (x: f32, y: f32, len: *c_int) callconv(.C) [*]*AnySprite,
    querySpritesInRect: *const fn (x: f32, y: f32, width: f32, height: f32, len: *c_int) callconv(.C) [*]*AnySprite,
    querySpritesAlongLine: *const fn (x1: f32, y1: f32, x2: f32, y2: f32, len: *c_int) callconv(.C) [*]*AnySprite,
    querySpriteInfoAlongLine: *const fn (x1: f32, y1: f32, x2: f32, y2: f32, len: *c_int) callconv(.C) [*]query.Info, // access results using const info = &results[i];
    overlappingSprites: *const fn (sprite: *AnySprite, len: *c_int) callconv(.C) [*]*AnySprite,
    allOverlappingSprites: *const fn (len: *c_int) callconv(.C) [*]*AnySprite,

    // added in 1.7
    setStencilPattern: *const fn (sprite: *AnySprite, pattern: [*]u8) callconv(.C) void, //pattern is 8 bytes
    clearStencil: *const fn (sprite: *AnySprite) callconv(.C) void,

    setUserdata: *const fn (sprite: *AnySprite, userdata: *anyopaque) callconv(.C) void,
    getUserdata: *const fn (sprite: *AnySprite) callconv(.C) ?*anyopaque,

    // added in 1.10
    setStencilImage: *const fn (sprite: *AnySprite, stencil: *graphics.Bitmap, tile: c_int) callconv(.C) void,
};
