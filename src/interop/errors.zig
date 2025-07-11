pub const Error = enum(usize) {

    noerror = 0,

    // Misc
    unexpected = 1,
    nullContext = 2,

    // Indexing
    notIterable = 3,
    outOfBounds = 4,

    // Naming
    nameAlreadyUsed = 5,
    nameNotFound = 6,
    invalidName = 7

};
