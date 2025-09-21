const std = @import("std");
const builtin = @import("builtin");

locked: bool = false,

pub fn lock(self: *@This()) void {
    while (self.locked) {}
    self.locked = true;
    return;
}

pub fn unlock(self: *@This()) void {
    self.locked = false;
    return;
}
