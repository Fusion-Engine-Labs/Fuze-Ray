const HitRecord = @import("../hittable/hit_record.zig");
const v = @import("../vector.zig");
const Ray = @import("../ray.zig");
const std = @import("std");

const Lambertion = @This();

albedo: v.Color,

pub var rand_state = std.Random.DefaultPrng.init(70);

pub fn scatter(
    self: *const Lambertion,
    _: *const Ray,
    hit_record: *const HitRecord,
    attenuation: *v.Color,
    scattered: *Ray,
) bool {
    var scatter_direction = hit_record.normal + v.randomUnit(rand_state.random());
    if (v.nearZero(scatter_direction)) {
        scatter_direction = hit_record.normal;
    }

    scattered.* = .init(hit_record.p, scatter_direction);
    attenuation.* = self.albedo;
    return true;
}
