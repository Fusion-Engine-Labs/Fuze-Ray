const HitRecord = @import("../hittable/hit_record.zig");
const Lambertion = @import("lambertion.zig");
const Dialectric = @import("dialectric.zig");
const Metal = @import("metal.zig");
const v = @import("../vector.zig");
const Ray = @import("../ray.zig");

pub const Material = union(enum) {
    metal: Metal,
    lambertion: Lambertion,
    dialetric: Dialectric,

    pub fn scatter(
        self: *const Material,
        ray: *const Ray,
        hit_record: *const HitRecord,
        attenuation: *v.Color,
        scattered: *Ray,
    ) bool {
        return switch (self.*) {
            .metal => |m| m.scatter(
                ray,
                hit_record,
                attenuation,
                scattered,
            ),
            .lambertion => |l| l.scatter(
                ray,
                hit_record,
                attenuation,
                scattered,
            ),
            .dialetric => |d| d.scatter(
                ray,
                hit_record,
                attenuation,
                scattered,
            ),
        };
    }
};
