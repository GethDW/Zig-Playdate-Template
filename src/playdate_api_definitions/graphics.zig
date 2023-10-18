const pdapi = @import("../playdate_api_definitions.zig");

pub const video = @import("video.zig");

pub const LCD_COLUMNS = 400;
pub const LCD_ROWS = 240;
pub const LCD_ROWSIZE = 52;

pub const Color = union(enum(c_int)) {
    Black,
    White,
    Clear,
    XOR,
    Pattern: *const LCDPattern,
};

pub fn clear(color: Color) void {
    gfx.clear(switch (color) {
        .Pattern => |pattern| @intFromPtr(pattern),
        else => |c| @intCast(@intFromEnum(c)),
    });
}

pub const Bitmap = opaque {
    // newBitmap: *const fn (width: c_int, height: c_int, color: graphics.LCDColor) callconv(.C) ?*graphics.Bitmap,
    pub fn new(width: u16, height: u16, color: Color) error{OutOfMemory}!*Bitmap {
        return gfx.newBitmap(width, height, switch (color) {
            .Pattern => |pattern| @intFromPtr(pattern),
            else => |c| @intCast(@intFromEnum(c)),
        }) orelse error.OutOfMemory;
    }
    // freeBitmap: *const fn (bitmap: ?*graphics.Bitmap) callconv(.C) void,
    pub fn free(self: *Bitmap) void {
        gfx.freeBitmap(self);
    }
    // loadBitmap: *const fn (path: [*:0]const u8, outerr: ?*[*:0]const u8) callconv(.C) ?*graphics.Bitmap,
    pub fn loadBitmap(path: [*:0]const u8) error{FileNotFound}!*Bitmap {
        var out_err: [*:0]const u8 = undefined;
        if (gfx.loadBitmap(path, &out_err)) |ptr| {
            return ptr;
        } else {
            pdapi.system.log("error: failed to load bitmap, %s", out_err);
            return error.FileNotFound;
        }
    }
    // copyBitmap: *const fn (bitmap: ?*graphics.Bitmap) callconv(.C) ?*graphics.Bitmap,
    pub fn copy(self: *Bitmap) error{OutOfMemory}!*Bitmap {
        return gfx.copyBitmap(self) orelse error.OutOfMemory;
    }
    // loadIntoBitmap: *const fn (path: [*:0]const u8, bitmap: ?*graphics.Bitmap, outerr: ?*[*:0]const u8) callconv(.C) void,
    pub fn loadInto(self: *Bitmap, path: [*:0]const u8) error{LoadFail}!void {
        var out_err: [*:0]const u8 = undefined;
        if (gfx.loadIntoBitmap(path, self, &out_err)) |ptr| {
            return ptr;
        } else {
            pdapi.system.log("error: failed to load bitmap, %s", out_err);
            return error.FileNotFound;
        }
    }
    // getBitmapData: *const fn (bitmap: ?*graphics.Bitmap, width: ?*c_int, height: ?*c_int, rowbytes: ?*c_int, mask: ?*[*c]u8, data: ?*[*c]u8) callconv(.C) void,
    pub fn getData(self: *Bitmap) struct {
        width: u16,
        height: u16,
        row_bytes: u16,
        data: [*]u8,
        mask: ?[*]u8,
    } {
        var width: u16 = undefined;
        var height: u16 = undefined;
        var row_bytes: u16 = undefined;
        var mask: ?[*]u8 = undefined;
        var data: [*]u8 = undefined;
        gfx.getBitmapData(self, &width, &height, &row_bytes, &mask, &data);
        return .{
            .width = width,
            .height = height,
            .row_bytes = row_bytes,
            .data = data,
            .mask = mask,
        };
    }
    // clearBitmap: *const fn (bitmap: ?*graphics.Bitmap, bgcolor: graphics.LCDColor) callconv(.C) void,
    // rotatedBitmap: *const fn (bitmap: ?*graphics.Bitmap, rotation: f32, xscale: f32, yscale: f32, allocedSize: ?*c_int) callconv(.C) ?*graphics.Bitmap,
};

///// RAW BINDINGS /////
var gfx: *const Playdategraphics = undefined;
pub fn init(pdgfx: *const Playdategraphics) void {
    gfx = pdgfx;
    video.init(gfx.video);
}

pub const LCDPattern = [16]u8;
pub const LCDColor = usize; //Pointer to LCDPattern or a LCDSolidColor value
pub const LCDSolidColor = enum(c_int) {
    ColorBlack,
    ColorWhite,
    ColorClear,
    ColorXOR,
};
pub const BitmapDrawMode = enum(c_int) {
    DrawModeCopy,
    DrawModeWhiteTransparent,
    DrawModeBlackTransparent,
    DrawModeFillWhite,
    DrawModeFillBlack,
    DrawModeXOR,
    DrawModeNXOR,
    DrawModeInverted,
};
pub const LCDLineCapStyle = enum(c_int) {
    LineCapStyleButt,
    LineCapStyleSquare,
    LineCapStyleRound,
};

pub const LCDFontLanguage = enum(c_int) {
    LCDFontLanguageEnglish,
    LCDFontLanguageJapanese,
    LCDFontLanguageUnknown,
};

pub const BitmapFlip = enum(c_int) {
    BitmapUnflipped,
    BitmapFlippedX,
    BitmapFlippedY,
    BitmapFlippedXY,
};
pub const LCDPolygonFillRule = enum(c_int) {
    PolygonFillNonZero,
    PolygonFillEvenOdd,
};

pub const BitmapTable = opaque {};
pub const LCDFont = opaque {};
pub const LCDFontPage = opaque {};
pub const LCDFontGlyph = opaque {};
pub const LCDFontData = opaque {};
pub const LCDRect = extern struct {
    left: c_int,
    right: c_int,
    top: c_int,
    bottom: c_int,
};
pub const Playdategraphics = extern struct {
    video: *const video.PlaydateVideo,
    // Drawing Functions
    clear: *const fn (color: LCDColor) callconv(.C) void,
    setBackgroundColor: *const fn (color: LCDSolidColor) callconv(.C) void,
    setStencil: *const fn (stencil: *Bitmap) callconv(.C) void, // deprecated in favor of setStencilImage, which adds a "tile" flag
    setDrawMode: *const fn (mode: BitmapDrawMode) callconv(.C) void,
    setDrawOffset: *const fn (dx: c_int, dy: c_int) callconv(.C) void,
    setClipRect: *const fn (x: c_int, y: c_int, width: c_int, height: c_int) callconv(.C) void,
    clearClipRect: *const fn () callconv(.C) void,
    setLineCapStyle: *const fn (endCapStyle: LCDLineCapStyle) callconv(.C) void,
    setFont: *const fn (font: ?*LCDFont) callconv(.C) void,
    setTextTracking: *const fn (tracking: c_int) callconv(.C) void,
    pushContext: *const fn (target: ?*Bitmap) callconv(.C) void,
    popContext: *const fn () callconv(.C) void,

    drawBitmap: *const fn (bitmap: ?*Bitmap, x: c_int, y: c_int, flip: BitmapFlip) callconv(.C) void,
    tileBitmap: *const fn (bitmap: ?*Bitmap, x: c_int, y: c_int, width: c_int, height: c_int, flip: BitmapFlip) callconv(.C) void,
    drawLine: *const fn (x1: c_int, y1: c_int, x2: c_int, y2: c_int, width: c_int, color: LCDColor) callconv(.C) void,
    fillTriangle: *const fn (x1: c_int, y1: c_int, x2: c_int, y2: c_int, x3: c_int, y3: c_int, color: LCDColor) callconv(.C) void,
    drawRect: *const fn (x: c_int, y: c_int, width: c_int, height: c_int, color: LCDColor) callconv(.C) void,
    fillRect: *const fn (x: c_int, y: c_int, width: c_int, height: c_int, color: LCDColor) callconv(.C) void,
    drawEllipse: *const fn (x: c_int, y: c_int, width: c_int, height: c_int, lineWidth: c_int, startAngle: f32, endAngle: f32, color: LCDColor) callconv(.C) void,
    fillEllipse: *const fn (x: c_int, y: c_int, width: c_int, height: c_int, startAngle: f32, endAngle: f32, color: LCDColor) callconv(.C) void,
    drawScaledBitmap: *const fn (bitmap: ?*Bitmap, x: c_int, y: c_int, xscale: f32, yscale: f32) callconv(.C) void,
    drawText: *const fn (text: ?*const anyopaque, len: usize, encoding: pdapi.system.StringEncoding, x: c_int, y: c_int) callconv(.C) c_int,

    // Bitmap
    newBitmap: *const fn (width: c_int, height: c_int, color: LCDColor) callconv(.C) ?*Bitmap,
    freeBitmap: *const fn (bitmap: ?*Bitmap) callconv(.C) void,
    loadBitmap: *const fn (path: [*:0]const u8, outerr: ?*[*:0]const u8) callconv(.C) ?*Bitmap,
    copyBitmap: *const fn (bitmap: ?*Bitmap) callconv(.C) ?*Bitmap,
    loadIntoBitmap: *const fn (path: [*:0]const u8, bitmap: *Bitmap, outerr: ?*[*:0]const u8) callconv(.C) void,
    getBitmapData: *const fn (bitmap: *Bitmap, width: *c_int, height: *c_int, rowbytes: *c_int, mask: *?[*]u8, data: *[*]u8) callconv(.C) void,
    clearBitmap: *const fn (bitmap: ?*Bitmap, bgcolor: LCDColor) callconv(.C) void,
    rotatedBitmap: *const fn (bitmap: ?*Bitmap, rotation: f32, xscale: f32, yscale: f32, allocedSize: ?*c_int) callconv(.C) ?*Bitmap,

    // BitmapTable
    newBitmapTable: *const fn (count: c_int, width: c_int, height: c_int) callconv(.C) ?*BitmapTable,
    freeBitmapTable: *const fn (table: ?*BitmapTable) callconv(.C) void,
    loadBitmapTable: *const fn (path: [*:0]const u8, outerr: ?*[*:0]const u8) callconv(.C) ?*BitmapTable,
    loadIntoBitmapTable: *const fn (path: [*:0]const u8, table: ?*BitmapTable, outerr: ?*[*:0]const u8) callconv(.C) void,
    getTableBitmap: *const fn (table: ?*BitmapTable, idx: c_int) callconv(.C) ?*Bitmap,

    // LCDFont
    loadFont: *const fn (path: [*:0]const u8, outErr: ?*[*:0]const u8) callconv(.C) ?*LCDFont,
    getFontPage: *const fn (font: ?*LCDFont, c: u32) callconv(.C) ?*LCDFontPage,
    getPageGlyph: *const fn (page: ?*LCDFontPage, c: u32, bitmap: ?**Bitmap, advance: ?*c_int) callconv(.C) ?*LCDFontGlyph,
    getGlyphKerning: *const fn (glyph: ?*LCDFontGlyph, glyphcode: u32, nextcode: u32) callconv(.C) c_int,
    getTextWidth: *const fn (font: ?*LCDFont, text: ?*const anyopaque, len: usize, encoding: pdapi.system.StringEncoding, tracking: c_int) callconv(.C) c_int,

    // raw framebuffer access
    getFrame: *const fn () callconv(.C) [*]u8, // row stride = LCD_ROWSIZE
    getDisplayFrame: *const fn () callconv(.C) [*]u8, // row stride = LCD_ROWSIZE
    getDebugBitmap: *const fn () callconv(.C) ?*Bitmap, // valid in simulator only, function is null on device
    copyFrameBufferBitmap: *const fn () callconv(.C) ?*Bitmap,
    markUpdatedRows: *const fn (start: c_int, end: c_int) callconv(.C) void,
    display: *const fn () callconv(.C) void,

    // misc util.
    setColorToPattern: *const fn (color: ?*LCDColor, bitmap: ?*Bitmap, x: c_int, y: c_int) callconv(.C) void,
    checkMaskCollision: *const fn (bitmap1: ?*Bitmap, x1: c_int, y1: c_int, flip1: BitmapFlip, bitmap2: ?*Bitmap, x2: c_int, y2: c_int, flip2: BitmapFlip, rect: LCDRect) callconv(.C) c_int,

    // 1.1
    setScreenClipRect: *const fn (x: c_int, y: c_int, width: c_int, height: c_int) callconv(.C) void,

    // 1.1.1
    fillPolygon: *const fn (nPoints: c_int, coords: [*]c_int, color: LCDColor, fillRule: LCDPolygonFillRule) callconv(.C) void,
    getFontHeight: *const fn (font: *LCDFont) callconv(.C) u8,

    // 1.7
    getDisplayBufferBitmap: *const fn () callconv(.C) ?*Bitmap,
    drawRotatedBitmap: *const fn (bitmap: *Bitmap, x: c_int, y: c_int, rotation: f32, centerx: f32, centery: f32, xscale: f32, yscale: f32) callconv(.C) void,
    setTextLeading: *const fn (lineHeightAdustment: c_int) callconv(.C) void,

    // 1.8
    setBitmapMask: *const fn (bitmap: *Bitmap, mask: *Bitmap) callconv(.C) c_int,
    getBitmapMask: *const fn (bitmap: *Bitmap) callconv(.C) ?*Bitmap,

    // 1.10
    setStencilImage: *const fn (stencil: *Bitmap, tile: c_int) callconv(.C) void,

    // 1.12
    makeFontFromData: *const fn (data: *LCDFontData, wide: c_int) callconv(.C) *LCDFont,
};
