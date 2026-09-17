const std = @import("std");

threadlocal var state: ?std.Random.DefaultPrng = null;
var next_seed = std.atomic.Value(u64).init(70);

pub fn ensureInit() void {
    if (state == null) {
        state = std.Random.DefaultPrng.init(next_seed.fetchAdd(1, .monotonic));
    }
}

pub fn random() std.Random {
    return state.?.random();
}
