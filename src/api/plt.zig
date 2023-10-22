// WELCOME TO THE METAPROGRAMMING HELL HOLE!!!

const std = @import("std");
const api = @import("../api.zig");
const PlaydateAPI = @import("playdate_raw").PlaydateAPI;

fn iterateFnPtrs(
    comptime S: type,
    comptime names: []const []const u8,
    ctx: anytype,
    comptime callback: fn (comptime names: []const []const u8, comptime F: type, ctx: @TypeOf(ctx)) void,
) void {
    @setEvalBranchQuota(3000);
    loop: inline for (@typeInfo(S).Struct.fields) |field| {
        if (field.type == void) {
            const version = comptime std.SemanticVersion.parse(field.name) catch unreachable;
            if (comptime api.sdkIsAtLeast(version.major, version.minor, version.patch)) {
                continue :loop;
            } else break :loop;
        }
        switch (@typeInfo(@typeInfo(field.type).Pointer.child)) {
            .Fn => |fn_info| callback(
                names ++ &[1][]const u8{field.name},
                @Type(.{ .Fn = fn_info }),
                ctx,
            ),
            .Struct => |struct_info| iterateFnPtrs(
                @Type(.{ .Struct = struct_info }),
                names ++ &[1][]const u8{field.name},
                ctx,
                callback,
            ),
            else => {},
        }
    }
}
fn concatNames(comptime names: []const []const u8, comptime sep: []const u8) []const u8 {
    @setEvalBranchQuota(4000);
    return comptime if (names.len == 1) names[0] else name: {
        comptime var name: []const u8 = names[0];
        inline for (names[1..]) |n| name = name ++ sep ++ n;
        break :name name;
    };
}

const fn_ptr_count = blk: {
    var acc: usize = 0;
    iterateFnPtrs(PlaydateAPI, &.{}, &acc, struct {
        pub fn f(comptime _: []const []const u8, comptime _: type, ctx: *usize) void {
            ctx.* += 1;
        }
    }.f);
    break :blk acc;
};
const PlaydatePLT = blk: {
    const Fields = [fn_ptr_count]@import("std").builtin.Type.StructField;
    const State = struct { fields: *Fields, i: usize = 0 };
    var fields: Fields = undefined;
    var state = State{ .fields = &fields };
    iterateFnPtrs(PlaydateAPI, &.{}, &state, struct {
        pub fn f(comptime names: []const []const u8, comptime F: type, comptime s: *State) void {
            const name = concatNames(names, "_");
            s.fields[s.i] = .{
                .name = name,
                .type = *const F,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(*const F),
            };
            s.i += 1;
        }
    }.f);

    break :blk @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
};

pub var pd: PlaydatePLT = undefined;
pub fn init(pd_raw: *const PlaydateAPI) void {
    const Context = struct {
        pd_raw: *const PlaydateAPI,
        should_load: bool,
    };
    var context = Context{ .pd_raw = pd_raw, .should_load = true };
    iterateFnPtrs(PlaydateAPI, &.{}, &context, struct {
        pub fn f(comptime names: []const []const u8, comptime _: type, ctx: *Context) void {
            const name = comptime concatNames(names, "_");
            var ptr: *const anyopaque = @ptrCast(ctx.pd_raw);
            comptime var FT: type = *const PlaydateAPI;
            inline for (names) |n| {
                const field = @field(@as(FT, @ptrCast(@alignCast(ptr))), n);
                FT = @TypeOf(field);
                ptr = @ptrCast(field);
            }
            @field(pd, name) = @as(FT, @ptrCast(@alignCast(ptr)));
        }
    }.f);
}
