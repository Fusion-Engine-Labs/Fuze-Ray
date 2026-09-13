const Material = @import("../material/material.zig").Material;
const Interval = @import("../interval.zig");
const HitRecord = @import("hit_record.zig");
const v = @import("../vector.zig");
const Ray = @import("../ray.zig");

const Sphere = @This();

material: *const Material,
center: v.Vec3,
radius: f64,

pub fn init(center: v.Point, radius: f64, material: *const Material) Sphere {
    return .{
        .center = center,
        .radius = @max(0, radius),
        .material = material,
    };
}

pub fn hit(
    self: Sphere,
    ray: *const Ray,
    ray_t: Interval,
    hit_record: *HitRecord,
) bool {
    const oc = self.center - ray.origin;
    const a = v.magnitude_squared(ray.direction);
    const h = v.dot(ray.direction, oc);
    const c = v.dot(oc, oc) - (self.radius * self.radius);

    const discriminant = h * h - a * c;
    if (discriminant < 0) {
        return false;
    }
    const sqrtd = @sqrt(discriminant);

    var root = (h - sqrtd) / a;
    if (!ray_t.surrounds(root)) {
        root = (h + sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            return false;
        }
    }

    hit_record.t = root;
    hit_record.p = ray.at(root);
    hit_record.material = self.material;

    const outward_normal = (hit_record.p - self.center) / v.splat(self.radius);
    hit_record.set_face_normal(ray, outward_normal);

    return true;
}
