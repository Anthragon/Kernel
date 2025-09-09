const std = @import("std");
const root = @import("root");

const err = @import("errors.zig");
pub const KernelErrorEnum = err.KernelErrorEnum;
pub const KernelError = err.KernelError;
pub const errorFromEnum = err.errorFromEnum;
pub const enumFromError = err.enumFromError;

pub fn Result(T: type) type {
    return extern struct {
        @"error": KernelErrorEnum,
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
        pub fn err(e: KernelErrorEnum) Result(T) {
            return .{
                .@"error" = e,
                .value = undefined,
            };
        }

        pub fn unwrap(s: @This()) ?T {
            return if (s.@"error" == .noerror) s.value else null;
        }
        pub fn isok(s: @This()) bool {
            return s.@"error" == .noerror;
        }
        pub fn asbuiltin(s: @This()) KernelError!T {
            return if (s.isok()) s.value else errorFromEnum(s.@"error");
        }
        pub fn frombuiltin(s: KernelError!T) Result(T) {
            return .val(s catch |e| return .err(enumFromError(e)));
        }
    };
}
