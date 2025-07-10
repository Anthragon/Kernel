pub const Error = enum(usize) {

    noerror = 0,

    // Misc
    nullContext = 1,

    // Indexing
    notIterable = 2,
    outOfBounds = 3,

    // Naming
    nameAlreadyUsed = 4,
    nameNotFound = 5,
    invalidName = 6

};
