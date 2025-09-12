//! Implementation of the users and permition system

const std = @import("std");
const root = @import("root");
const Toml = root.lib.Toml;
const debug = root.debug;
const Guid = root.utils.Guid;
const allocator = root.mem.heap.kernel_buddy_allocator;

const log = std.log.scoped(.auth);

const UserList = std.ArrayList(*User);

var user_list: UserList = undefined;

/// Represents virtual or real users
pub const User = struct {
    /// The index inside the users list
    index: usize,
    /// The unique identifier of this user
    uuid: Guid,
    /// The user name
    name: []const u8,
    /// The user password
    passwd: []const u8,

    /// Indicates if the user is visible by default
    is_hidden: bool,
    /// Indicates if the user is a system user
    is_system: bool,
    // Indicates if the user has administration permission
    is_admin: bool,
    /// Indicates if the user can execute while other main
    /// user is active
    is_global: bool,

    /// the UNIX timestamp of the creation of this user
    creation_timestamp: usize,
};

pub fn init() void {
    log.debug(" ## Setting up auth service...", .{});

    user_list = UserList.empty;

    // Appending the virtual system users
    append_user(.{
        // > Adam is a better term for the first father of all tasks
        // > than root was! - Terry A. Davis
        .user_name = "Adam",
        .user_passwd = "0000",

        .is_hidden = false,
        .is_system = true,
        .is_admin = true,
        .is_global = true,
    });
}

pub fn append_user(options: struct {
    user_name: []const u8,
    user_passwd: []const u8,
    user_uuid: Guid = Guid.zero(),
    is_hidden: bool = false,
    is_system: bool = false,
    is_admin: bool = false,
    is_global: bool = false,
    creation_timestamp: ?u64 = null,
}) void {
    var nuser = allocator.create(User) catch root.oom_panic();
    const index = user_list.items.len;

    nuser.* = .{
        .index = index,
        .uuid = options.user_uuid,
        .name = options.user_name,
        .passwd = options.user_passwd,
        .is_hidden = options.is_hidden,
        .is_system = options.is_system,
        .is_admin = options.is_admin,
        .is_global = options.is_global,
        .creation_timestamp = undefined,
    };

    nuser.creation_timestamp = if (options.creation_timestamp == null)
        root.system.time.timestamp()
    else
        options.creation_timestamp.?;

    user_list.append(allocator, nuser) catch root.oom_panic();
}

pub fn load_users_config(file_name: []const u8, config: Toml) void {
    log.debug("parsing users from {s}:\n{f}", .{ file_name, config });

    const table = config.content.get("user") orelse return;
    if (table != .Array) std.debug.panic("{s}: Expected ´user´ to be Array, found {s}", .{ file_name, @tagName(table) });

    log.debug("User list has {} itens", .{table.Array.len});
    for (table.Array) |user| {
        if (user != .Table) std.debug.panic("{s}: Expected ´user´ table item to be Table, found {s}", .{ file_name, @tagName(user) });

        if (!(user.Table.contains("name") and user.Table.get("name").? == .String) or
            !(user.Table.contains("uuid") and user.Table.get("uuid").? == .String) or
            !(user.Table.contains("perm") and user.Table.get("perm").? == .String) or
            !(!user.Table.contains("pass") or user.Table.get("pass").? == .String))
            std.debug.panic("{s}: Expected 'user' table item to be '{{ name: String, uuid: String, perm: String, pass: String? }}', found invalid Table", .{file_name});

        const user_name = std.mem.sliceTo(user.Table.get("name").?.String, 0);
        const user_uuid = Guid.fromString(std.mem.sliceTo(user.Table.get("uuid").?.String, 0)) catch std.debug.panic("{s}: Invalig GUID format", .{file_name});
        const user_perm = std.mem.sliceTo(user.Table.get("perm").?.String, 0);
        const user_pass = if (user.Table.contains("pass")) std.mem.sliceTo(user.Table.get("pass").?.String, 0) else "";

        const user_is_adm = std.mem.containsAtLeastScalar(u8, user_perm, 1, 'A');
        const user_is_global = std.mem.containsAtLeastScalar(u8, user_perm, 1, 'G');
        const user_is_hidden = std.mem.containsAtLeastScalar(u8, user_perm, 1, 'H');
        const user_is_system = std.mem.containsAtLeastScalar(u8, user_perm, 1, 'S');

        append_user(.{
            .user_name = user_name,
            .user_uuid = user_uuid,
            .user_passwd = user_pass,
            .creation_timestamp = null,
            .is_admin = user_is_adm,
            .is_global = user_is_global,
            .is_hidden = user_is_hidden,
            .is_system = user_is_system,
        });
    }
}

pub fn get_user_by_index(index: usize) ?*User {
    if (index >= user_list.items.len) return null;
    return user_list.items[index];
}

pub fn lsusers() void {
    log.warn("lsusers", .{});
    log.info("Listing users:", .{});

    for (user_list.items) |i| {
        log.info("{: <2} - {s} {f} {c}{c}{c}", .{
            i.index,
            i.name,
            i.uuid,

            @as(u8, if (i.is_admin) 'A' else '-'),
            @as(u8, if (i.is_system) 'S' else '-'),
            @as(u8, if (i.is_global) 'G' else '-'),
        });
    }
}
