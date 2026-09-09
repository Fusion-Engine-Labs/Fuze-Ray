const v = @import("vector.zig");

const Ray = @This();

origin: v.Point,
direction: v.Vec3,

pub fn init(origin: v.Point, direction: v.Vec3) Ray {
    return .{ .origin = origin, .direction = direction };
}

pub fn at(self: *const Ray, t: f64) v.Point {
    return @mulAdd(v.Vec3, @splat(t), self.direction, self.origin);
}
