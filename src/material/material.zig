const HitRecord = @import("../hittable/hit_record.zig");
const Lambertian = @import("lambertian.zig");
const Dielectric = @import("dielectric.zig");
const Metal = @import("metal.zig");
const v = @import("../vector.zig");
const Ray = @import("../ray.zig");

pub const Material = union(enum) {
    metal: Metal,
    lambertian: Lambertian,
    dielectric: Dielectric,

    pub fn scatter(
        self: *const Material,
        ray: *const Ray,
        hit_record: *const HitRecord,
        attenuation: *v.Color,
        scattered: *Ray,
    ) bool {
        return switch (self.*) {
            inline else => |*material| material.scatter(
                ray,
                hit_record,
                attenuation,
                scattered,
            ),
        };
    }
};
