pub const Error = enum(usize) {

    noerror = 0,

    // Misc
    unexpected,
    notImplemented,
    nullContext,
    nullArgument,

    // Query
    notFound,

    // Indexing
    notIterable,
    outOfBounds,

    // Naming
    nameAlreadyUsed,
    nameNotFound,
    invalidName,

    // FS error
    cannotRead,
    invalidPath,
    nodeIsFile,
    nodeIsDirectory,

};

pub fn errorToZigError(err: Error) anyerror {
    return switch (err) {
        .unexpected => error.unexpected,
        .notImplemented => error.notImplemented,
        .nullContext => error.nullContext,
        .nullArgument => error.nullArgument,

        .notFound => error.notFound,

        .notIterable => error.notIterable,
        .outOfBounds => error.outOfBounds,

        .nameAlreadyUsed => error.nameAlreadyUsed,
        .nameNotFound => error.nameNotFound,
        .invalidName => error.invalidName,

        .cannotRead => error.cannotRead,
        .invalidPath => error.invalidPath,
        .nodeIsFile => error.nodeIsFile,
        .nodeIsDirectory => error.nodeIsDirectory,

        else => error.unregistredError
    };
}
