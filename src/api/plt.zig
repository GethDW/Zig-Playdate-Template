const PlaydateAPI = @import("playdate_raw").PlaydateAPI;
const PlaydatePLT = blk: {
    const total = tot: {
        var acc: usize = 0;
        inline for (@typeInfo(PlaydateAPI).Struct.fields) |field1| {
            inline for (@typeInfo(@typeInfo(field1.type).Pointer.child).Struct.fields) |field2| {
                switch (@typeInfo(@typeInfo(field2.type).Pointer.child)) {
                    .Struct => |info| inline for (info.fields) |field3| {
                        _ = field3;
                        acc += 1;
                    },
                    .Fn => {
                        acc += 1;
                    },
                    else => unreachable,
                }
            }
        }
        break :tot acc;
    };
    var i: usize = 0;
    var fields: [total]@import("std").builtin.Type.StructField = undefined;
    inline for (@typeInfo(PlaydateAPI).Struct.fields) |field1| {
        inline for (@typeInfo(@typeInfo(field1.type).Pointer.child).Struct.fields) |field2| {
            switch (@typeInfo(@typeInfo(field2.type).Pointer.child)) {
                .Struct => |info| inline for (info.fields) |field3| {
                    fields[i] = .{
                        .name = field1.name ++ "_" ++ field2.name ++ "_" ++ field3.name,
                        .type = field3.type,
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = field3.alignment,
                    };
                    i += 1;
                },
                .Fn => {
                    fields[i] = .{
                        .name = field1.name ++ "_" ++ field2.name,
                        .type = field2.type,
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = field2.alignment,
                    };
                    i += 1;
                },
                else => unreachable,
            }
        }
    }
    break :blk @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
};
pub var pd: PlaydatePLT = undefined;
pub fn init(pd_raw: *const PlaydateAPI) void {
    inline for (@typeInfo(PlaydateAPI).Struct.fields) |field1| {
        inline for (@typeInfo(@typeInfo(field1.type).Pointer.child).Struct.fields) |field2| {
            switch (@typeInfo(@typeInfo(field2.type).Pointer.child)) {
                .Struct => |info| inline for (info.fields) |field3| {
                    // @compileLog(field1.name ++ "_" ++ field2.name ++ "_" ++ field3.name ++ " <- " ++ field1.name ++ "." ++ field2.name ++ "." ++ field3.name);
                    @field(pd, field1.name ++ "_" ++ field2.name ++ "_" ++ field3.name) = @field(@field(@field(pd_raw, field1.name), field2.name), field3.name);
                },
                .Fn => {
                    // @compileLog(field1.name ++ "_" ++ field2.name ++ " <- " ++ field1.name ++ "." ++ field2.name);
                    @field(pd, field1.name ++ "_" ++ field2.name) = @field(@field(pd_raw, field1.name), field2.name);
                },
                else => unreachable,
            }
        }
    }
}
