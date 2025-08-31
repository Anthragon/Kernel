const std = @import("std");
const root = @import("root");

pub const Error = @import("errors.zig").Error;

pub fn Result(T: type) type {
    return extern struct {
        @"error": Error,
        value: T,

        pub fn val(v: T) Result(T) {
            return .{
                .@"error" = .noerror,
                .value = v,
            };
        }
        pub fn retvoid() Result(void) {
            return .{
                .@"error" = .noerror,
                .value = undefined,
            };
        }
        pub fn err(e: Error) Result(T) {
            return .{
                .@"error" = e,
                .value = undefined,
            };
        }

        pub fn unwrap(s: *const @This()) ?T {
            return if (s.@"error" == .noerror) s.value else null;
        }
        pub fn isok(s: *const @This()) bool {
            return s.@"error" == .noerror;
        }
    };
}
