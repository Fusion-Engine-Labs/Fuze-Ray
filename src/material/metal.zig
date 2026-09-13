const HitRecord = @import("../hittable/hit_record.zig");
const v = @import("../vector.zig");
const Ray = @import("../ray.zig");
const std = @import("std");

const Metal = @This();

albedo: v.Color,
fuzz: f64,

pub var rand_state = std.Random.DefaultPrng.init(70);

pub fn scatter(
    self: *const Metal,
    ray: *const Ray,
    hit_record: *const HitRecord,
    attenuation: *v.Color,
    scattered: *Ray,
) bool {
    var reflected = v.reflect(ray.direction, hit_record.normal);
    reflected = v.unit(reflected) + (v.splat(self.fuzz) * v.randomUnit(rand_state.random()));
    scattered.* = .init(hit_record.p, reflected);
    attenuation.* = self.albedo;
    return v.dot(scattered.direction, hit_record.normal) > 0;
}
