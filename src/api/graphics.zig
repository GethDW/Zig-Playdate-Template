const pdapi = @import("../api.zig");
const plt = @import("plt.zig");

const raw = @import("playdate_raw");

pub const video = @import("video.zig");

pub const lcd_columns = raw.LCD_COLUMNS;
pub const lcd_rows = raw.LCD_ROWS;
pub const lcd_rowsize = raw.LCD_ROWSIZE;

pub const Color = union(enum(c_int)) {
    Black,
    White,
    Clear,
    XOR,
    Pattern: *const raw.LCDPattern,
};

pub fn clear(color: Color) void {
    plt.pd.graphics_clear(switch (color) {
        .Pattern => |pattern| @intFromPtr(pattern),
        else => |c| @intCast(@intFromEnum(c)),
    });
}

pub const Bitmap = opaque {
    // newBitmap: *const fn (width: c_int, height: c_int, color: graphics.LCDColor) callconv(.C) ?*graphics.Bitmap,
    pub fn new(width: u16, height: u16, color: Color) error{OutOfMemory}!*Bitmap {
        return plt.pd.graphics_newBitmap(width, height, switch (color) {
            .Pattern => |pattern| @intFromPtr(pattern),
            else => |c| @intCast(@intFromEnum(c)),
        }) orelse error.OutOfMemory;
    }
    // freeBitmap: *const fn (bitmap: ?*graphics.Bitmap) callconv(.C) void,
    pub fn free(self: *Bitmap) void {
        plt.pd.graphics_freeBitmap(self);
    }
    // loadBitmap: *const fn (path: [*:0]const u8, outerr: ?*[*:0]const u8) callconv(.C) ?*graphics.Bitmap,
    pub fn loadBitmap(path: [*:0]const u8) error{FileNotFound}!*Bitmap {
        var out_err: [*:0]const u8 = undefined;
        if (plt.pd.graphics_loadBitmap(path, &out_err)) |ptr| {
            return ptr;
        } else {
            pdapi.system.log("error: failed to load bitmap, %s", out_err);
            return error.FileNotFound;
        }
    }
    // copyBitmap: *const fn (bitmap: ?*graphics.Bitmap) callconv(.C) ?*graphics.Bitmap,
    pub fn copy(self: *Bitmap) error{OutOfMemory}!*Bitmap {
        return plt.pd.graphics_copyBitmap(self) orelse error.OutOfMemory;
    }
    // loadIntoBitmap: *const fn (path: [*:0]const u8, bitmap: ?*graphics.Bitmap, outerr: ?*[*:0]const u8) callconv(.C) void,
    pub fn loadInto(self: *Bitmap, path: [*:0]const u8) error{LoadFail}!void {
        var out_err: [*:0]const u8 = undefined;
        if (plt.pd.graphics_loadIntoBitmap(path, self, &out_err)) |ptr| {
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
        plt.pd.graphics_getBitmapData(self, &width, &height, &row_bytes, &mask, &data);
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
