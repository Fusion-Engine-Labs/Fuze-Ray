const HitRecord = @import("hit_record.zig");
const Sphere = @import("sphere.zig");
const Ray = @import("../ray.zig");

pub const Hittable = union(enum) {
    sphere: Sphere,

    pub fn hit(
        self: Hittable,
        ray: *const Ray,
        ray_tmin: f64,
        ray_tmax: f64,
        hit_record: *HitRecord,
    ) bool {
        switch (self) {
            .sphere => |s| return s.hit(
                ray,
                ray_tmin,
                ray_tmax,
                hit_record,
            ),
        }
    }
};
