pub const KernelErrorEnum = enum(usize) {
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
    cannotWrite,
    invalidPath,
    nodeIsFile,
    nodeIsDirectory,
};

pub const KernelError = error{
    Unexpected,
    NotImplemented,
    NullContext,
    NullArgument,

    NotFound,

    NotIterable,
    OutOfBounds,

    NameAlreadyUsed,
    NameNotFound,
    InvalidName,

    CannotRead,
    CannotWrite,
    InvalidPath,
    NodeIsFile,
    NodeIsDirectory,
};

pub fn errorFromEnum(err: KernelErrorEnum) KernelError {
    return switch (err) {
        .noerror => unreachable,
        .unexpected => KernelError.Unexpected,
        .notImplemented => KernelError.NotImplemented,
        .nullContext => KernelError.NullContext,
        .nullArgument => KernelError.NullArgument,

        .notFound => KernelError.NotFound,

        .notIterable => KernelError.NotIterable,
        .outOfBounds => KernelError.OutOfBounds,

        .nameAlreadyUsed => KernelError.NameAlreadyUsed,
        .nameNotFound => KernelError.NameNotFound,
        .invalidName => KernelError.InvalidName,

        .cannotRead => KernelError.CannotRead,
        .cannotWrite => KernelError.CannotWrite,
        .invalidPath => KernelError.InvalidPath,
        .nodeIsFile => KernelError.NodeIsFile,
        .nodeIsDirectory => KernelError.NodeIsDirectory,
    };
}
pub fn enumFromError(err: KernelError) KernelErrorEnum {
    return switch (err) {
        KernelError.Unexpected => .unexpected,
        KernelError.NotImplemented => .notImplemented,
        KernelError.NullContext => .nullContext,
        KernelError.NullArgument => .nullArgument,

        KernelError.NotFound => .notFound,

        KernelError.NotIterable => .notIterable,
        KernelError.OutOfBounds => .outOfBounds,

        KernelError.NameAlreadyUsed => .nameAlreadyUsed,
        KernelError.NameNotFound => .nameNotFound,
        KernelError.InvalidName => .invalidName,

        KernelError.CannotRead => .cannotRead,
        KernelError.CannotWrite => .cannotWrite,
        KernelError.InvalidPath => .invalidPath,
        KernelError.NodeIsFile => .nodeIsFile,
        KernelError.NodeIsDirectory => .nodeIsDirectory,
    };
}
