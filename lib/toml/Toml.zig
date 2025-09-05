const std = @import("std");

arena: std.heap.ArenaAllocator,
content: std.StringHashMapUnmanaged(Value),

const Value = union(enum) {
    String: [*:0]const u8,
    Integer: i64,
    Boolean: bool,
    Array: []Value,
    Table: std.StringHashMapUnmanaged(Value),
};

pub fn deinit(s: *@This()) void {
    s.arena.deinit();
}

pub fn parseToml(allocator: std.mem.Allocator, toml: []const u8) !@This() {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    const aloc = arena.allocator();
    errdefer arena.deinit();

    var root = std.StringHashMapUnmanaged(Value).empty;
    var current_table: *std.StringHashMapUnmanaged(Value) = &root;
    var lines = std.mem.tokenizeAny(u8, toml, "\r\n");

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");

        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Table header: [table]
        if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
            const tablename = trimmed[1 .. trimmed.len - 1];
            const new_table = std.StringHashMapUnmanaged(Value).empty;
            _ = try root.put(allocator, tablename, Value{ .Table = new_table });
            current_table = &root.getPtr(tablename).?.Table;
            continue;
        }

        // Key = value
        if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
            const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
            const value_str = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

            const parsed = try parseTomlValue(aloc, value_str);
            _ = try current_table.put(allocator, key, parsed);
        }
    }

    return .{
        .arena = arena,
        .content = root,
    };
}
fn parseTomlValue(allocator: std.mem.Allocator, value: []const u8) !Value {

    // Parse String
    if (value.len >= 2 and ((value[0] == '"' and value[value.len - 1] == '"') or (value[0] == '\'' and value[value.len - 1] == '\''))) {
        return Value{ .String = try allocator.dupeZ(u8, value[1 .. value.len - 1]) };
    }

    // Parse Array
    if (value.len >= 2 and value[0] == '[' and value[value.len - 1] == ']') {
        var items = std.ArrayList(Value).empty;
        const inner = std.mem.trim(u8, value[1 .. value.len - 1], " \t");
        var it = std.mem.tokenizeScalar(u8, inner, ',');

        while (it.next()) |item| {
            const val = try parseTomlValue(allocator, std.mem.trim(u8, item, " \t"));
            try items.append(allocator, val);
        }
        return Value{ .Array = try items.toOwnedSlice(allocator) };
    }

    // Parse Inline Table
    if (value.len >= 2 and value[0] == '{' and value[value.len - 1] == '}') {
        var table = std.StringHashMapUnmanaged(Value).empty;
        const inner = std.mem.trim(u8, value[1 .. value.len - 1], " \t");

        var it = std.mem.tokenizeScalar(u8, inner, ',');
        while (it.next()) |pair| {
            if (std.mem.indexOf(u8, pair, "=")) |eq_pos| {
                const k = std.mem.trim(u8, pair[0..eq_pos], " \t");
                const v = std.mem.trim(u8, pair[eq_pos + 1 ..], " \t");
                const parsed = try parseTomlValue(allocator, v);
                try table.put(allocator, k, parsed);
            }
        }

        return Value{ .Table = table };
    }

    // Parse Boolean
    if (std.mem.eql(u8, value, "true")) return Value{ .Boolean = true };
    if (std.mem.eql(u8, value, "false")) return Value{ .Boolean = false };

    // Parse Integer
    return Value{ .Integer = (std.fmt.parseInt(i64, value, 10) catch return error.ParseIntError) };

    //return error.UnsupportedTomlValue;
}
