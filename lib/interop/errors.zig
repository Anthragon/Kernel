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
    invalidName

};
