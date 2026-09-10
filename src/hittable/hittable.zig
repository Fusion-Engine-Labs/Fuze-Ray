const Interval = @import("../interval.zig");
const HitRecord = @import("hit_record.zig");
const Sphere = @import("sphere.zig");
const Ray = @import("../ray.zig");

pub const Hittable = union(enum) {
    sphere: Sphere,

    pub fn hit(
        self: Hittable,
        ray: *const Ray,
        ray_t: Interval,
        hit_record: *HitRecord,
    ) bool {
        switch (self) {
            .sphere => |s| return s.hit(
                ray,
                ray_t,
                hit_record,
            ),
        }
    }
};
