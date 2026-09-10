const std = @import("std");

const Interval = @This();

min: f64,
max: f64,

pub fn init(min: f64, max: f64) Interval {
    return .{ .min = min, .max = max };
}

pub fn size(self: Interval) f64 {
    return self.max - self.min;
}

pub fn contains(self: Interval, x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Interval, x: f64) bool {
    return self.min < x and x < self.max;
}

pub const empty = Interval.init(std.math.floatMax(f64, std.math.floatMin(f64)));
pub const universe = Interval.init(std.math.floatMin(f64, std.math.floatMax(f64)));
