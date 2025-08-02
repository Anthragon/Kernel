//! Events are a specific capability entry that allows
//! modules to bind to callbacks. Also it allows multiple
//! modules to bind to a single callback and allows them
//! to also bind a context that can be used to share arguments
//! or values.

const std = @import("std");
const root = @import("root");

pub const Event = struct {

};
