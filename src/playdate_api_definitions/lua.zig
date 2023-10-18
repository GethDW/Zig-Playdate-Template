const pdapi = @import("../playdate_api_definitions.zig");
const graphics = pdapi.graphics;
const sprite = pdapi.sprite;

pub var lua: *const PlaydateLua = undefined;
pub fn init(pdlua: *const PlaydateLua) void {
    lua = pdlua;
}

pub fn get(comptime T: type, pos: i32) T {
    return switch (@typeInfo(T)) {
        .Optional => |info| if (lua.argIsNil(pos) == 1) null else getNative(info.child, pos),
        else => get(T, pos),
    };
}

fn getNative(comptime T: type, pos: i32) T {
    switch (@typeInfo(T)) {
        .Bool => |_| return lua.getArgBool(pos) == 1,
        .Float => |_| return lua.getArgFloat(pos),
        .Int => |_| return @intCast(lua.getArgInt(pos)),
        else => switch (T) {
            sprite.Sprite => return lua.getSprite(pos).?,
            graphics.Bitmap => return lua.getBitmap(pos).?,
            [*:0]const u8 => return lua.getArgString(pos),
            else => @compileError("unsupported type in lua " ++ @typeName(T)),
        },
    }
}

pub const ClassMethod = struct {
    []const u8,
    (fn () c_int),
};
pub fn registerClass(
    comptime name: []const u8,
    comptime methods: []const ClassMethod,
    comptime is_static: bool,
) error{RegisterClassFail}!void {
    comptime var regs: [methods.len:LuaReg.End]LuaReg = undefined;
    inline for (&regs, methods) |*reg, meth| {
        const method_name, const method = meth;
        reg.* = .{
            .name = @ptrCast(method_name ++ &[_]u8{0}),
            .func = struct {
                pub fn f(_: *LuaState) callconv(.C) c_int {
                    return method();
                }
            }.f,
        };
    }

    var err: [*:0]const u8 = undefined;
    if (lua.registerClass(
        @ptrCast(name ++ &[_]u8{0}),
        &regs,
        null,
        @intFromBool(is_static),
        &err,
    ) == 0) {
        pdapi.system.log("error: %s", err);
        return error.RegisterClassFail;
    }
}

pub const LuaState = opaque {};
pub const LuaCFunction = fn (*LuaState) callconv(.C) c_int;
pub const LuaUDObject = opaque {};

//literal value
pub const LValType = enum(c_int) {
    Int = 0,
    Float = 1,
    Str = 2,
};
const LuaReg = extern struct {
    name: ?[*:0]const u8,
    func: ?*const LuaCFunction,

    pub const End = LuaReg{
        .name = null,
        .func = null,
    };
};
pub const LuaType = enum(c_int) {
    TypeNil = 0,
    TypeBool = 1,
    TypeInt = 2,
    TypeFloat = 3,
    TypeString = 4,
    TypeTable = 5,
    TypeFunction = 6,
    TypeThread = 7,
    TypeObject = 8,
};
pub const LuaVal = extern struct {
    name: [*:0]const u8,
    type: LValType,
    v: extern union {
        intval: c_uint,
        floatval: f32,
        strval: [*:0]const u8,
    },
};
pub const PlaydateLua = extern struct {
    // these two return 1 on success, else 0 with an error message in outErr
    addFunction: *const fn (f: *const LuaCFunction, name: [*:0]const u8, outErr: ?*[*:0]const u8) callconv(.C) c_int,
    registerClass: *const fn (name: [*:0]const u8, reg: [*:LuaReg.End]const LuaReg, vals: ?*const LuaVal, isstatic: c_int, outErr: ?*[*:0]const u8) callconv(.C) c_int,

    pushFunction: *const fn (f: *const LuaCFunction) callconv(.C) void,
    indexMetatable: *const fn () callconv(.C) c_int,

    stop: *const fn () callconv(.C) void,
    start: *const fn () callconv(.C) void,

    // stack operations
    getArgCount: *const fn () callconv(.C) c_int,
    getArgType: *const fn (pos: c_int, outClass: ?*[*:0]const u8) callconv(.C) LuaType,

    argIsNil: *const fn (pos: c_int) callconv(.C) c_int,
    getArgBool: *const fn (pos: c_int) callconv(.C) c_int,
    getArgInt: *const fn (pos: c_int) callconv(.C) c_int,
    getArgFloat: *const fn (pos: c_int) callconv(.C) f32,
    getArgString: *const fn (pos: c_int) callconv(.C) [*c]const u8,
    getArgBytes: *const fn (pos: c_int, outlen: ?*usize) callconv(.C) [*c]const u8,
    getArgObject: *const fn (pos: c_int, type: [*:0]const u8, ?**LuaUDObject) callconv(.C) ?*anyopaque,

    getBitmap: *const fn (c_int) callconv(.C) ?*graphics.Bitmap,
    getSprite: *const fn (c_int) callconv(.C) ?*sprite.AnySprite,

    // for returning values back to Lua
    pushNil: *const fn () callconv(.C) void,
    pushBool: *const fn (val: c_int) callconv(.C) void,
    pushInt: *const fn (val: c_int) callconv(.C) void,
    pushFloat: *const fn (val: f32) callconv(.C) void,
    pushString: *const fn (str: [*c]const u8) callconv(.C) void,
    pushBytes: *const fn (str: [*c]const u8, len: usize) callconv(.C) void,
    pushBitmap: *const fn (bitmap: ?*graphics.Bitmap) callconv(.C) void,
    pushSprite: *const fn (sprite: ?*sprite.AnySprite) callconv(.C) void,

    pushObject: *const fn (obj: *anyopaque, type: [*:0]const u8, nValues: c_int) callconv(.C) ?*LuaUDObject,
    retainObject: *const fn (obj: *LuaUDObject) callconv(.C) ?*LuaUDObject,
    releaseObject: *const fn (obj: *LuaUDObject) callconv(.C) void,

    setObjectValue: *const fn (obj: *LuaUDObject, slot: c_int) callconv(.C) void,
    getObjectValue: *const fn (obj: *LuaUDObject, slot: c_int) callconv(.C) c_int,

    // calling lua from C has some overhead. use sparingly!
    callFunction_deprecated: *const fn (name: [*:0]const u8, nargs: c_int) callconv(.C) void,
    callFunction: *const fn (name: [*:0]const u8, nargs: c_int, outerr: ?*[*:0]const u8) callconv(.C) c_int,
};
