//! Events are a specific capability entry that allows
//! modules to bind to callbacks. Also it allows multiple
//! modules to bind to a single callback and allows them
//! to also bind a context that can be used to share arguments
//! or values.

const std = @import("std");
const root = @import("root");

pub const Event = extern struct {
    pub const EventOnBindCallback = *const fn (*const anyopaque, ?*anyopaque) callconv(.c) bool;
    pub const EventOnUnbindCallback = *const fn (*const anyopaque) callconv(.c) void;

    bind_callback: EventOnBindCallback,
    unbind_callback: EventOnUnbindCallback,

    pub fn bind(s: @This(), func: *const anyopaque, ctx: ?*anyopaque) callconv(.c) bool {
        return s.bind_callback(func, ctx);
    }
    pub fn unbind(s: @This(), func: *const anyopaque) callconv(.c) void {
        s.unbind_callback(func);
    }
};
