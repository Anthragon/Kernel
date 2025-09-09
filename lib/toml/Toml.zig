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
    const alloc = arena.allocator();
    errdefer arena.deinit();

    var root = std.StringHashMapUnmanaged(Value).empty;
    var current_table: *std.StringHashMapUnmanaged(Value) = &root;
    var lines = std.mem.tokenizeAny(u8, toml, "\r\n");

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Table array: [[table]]
        if (trimmed.len > 4 and trimmed[0] == '[' and trimmed[1] == '[' and trimmed[trimmed.len - 2] == ']' and trimmed[trimmed.len - 1] == ']') {
            const tablename = std.mem.trim(u8, trimmed[2 .. trimmed.len - 2], " \t");

            const entry = root.getOrPut(allocator, tablename) catch return error.OutOfMemory;
            if (!entry.found_existing) {
                var arr = std.ArrayList(Value).empty;
                entry.value_ptr.* = Value{ .Array = try arr.toOwnedSlice(allocator) };
            }

            var arr_val = entry.value_ptr.*;
            if (arr_val != .Array) return error.InvalidToml;

            var arr = std.ArrayList(Value).fromOwnedSlice(arr_val.Array);

            const new_table = std.StringHashMapUnmanaged(Value).empty;
            try arr.append(allocator, Value{ .Table = new_table });

            arr_val = Value{ .Array = try arr.toOwnedSlice(allocator) };

            const last_idx = arr_val.Array.len - 1;
            current_table = &arr_val.Array[last_idx].Table;

            continue;
        }

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
            var value_str = std.mem.trimLeft(u8, trimmed[eq_pos + 1 ..], " \t");

            if (value_str.len > 0 and value_str[0] == '[' and value_str[value_str.len - 1] != ']') {
                var end_line: []const u8 = value_str;

                while (lines.next()) |next_line| {
                    if (std.mem.indexOfScalar(u8, next_line, ']') != null) {
                        end_line = next_line;
                        break;
                    }
                }

                value_str = toml[value_str.ptr - toml.ptr .. end_line.ptr - toml.ptr + end_line.len];
            }

            const parsed = try parseTomlValue(alloc, value_str);
            _ = try current_table.put(allocator, key, parsed);
        }
    }

    return .{
        .arena = arena,
        .content = root,
    };
}
fn parseTomlValue(allocator: std.mem.Allocator, value: []const u8) !Value {
    const trimmed = std.mem.trim(u8, value, " \t");

    // Parse String
    if (trimmed.len >= 2 and ((trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') or (trimmed[0] == '\'' and trimmed[trimmed.len - 1] == '\''))) {
        return Value{ .String = try allocator.dupeZ(u8, trimmed[1 .. trimmed.len - 1]) };
    }

    // Parse Array
    if (trimmed.len >= 2 and trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
        var items = std.ArrayList(Value).empty;
        const inner = std.mem.trim(u8, value[1 .. value.len - 1], " \t\n\r");

        const parts = try splitTopLevelComma(allocator, inner);
        defer allocator.free(parts);

        for (parts) |item| {
            if (item.len == 0) continue;
            const val = try parseTomlValue(allocator, item);
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

fn splitTopLevelComma(gpa: std.mem.Allocator, s: []const u8) ![][]const u8 {
    var result = std.ArrayList([]const u8).empty;
    var start: usize = 0;
    var depth: usize = 0;
    var i: usize = 0;

    while (i < s.len) : (i += 1) {
        const c = s[i];
        switch (c) {
            '{', '[' => depth += 1,
            '}', ']' => {
                if (depth > 0) depth -= 1;
            },
            ',' => if (depth == 0) {
                const part = std.mem.trim(u8, s[start..i], " \t\n\r");
                if (part.len > 0)
                    try result.append(gpa, part);
                start = i + 1;
            },
            else => {},
        }
    }

    if (start < s.len) {
        const part = std.mem.trim(u8, s[start..], " \t\n\r");
        if (part.len > 0)
            try result.append(gpa, part);
    }

    return try result.toOwnedSlice(gpa);
}
