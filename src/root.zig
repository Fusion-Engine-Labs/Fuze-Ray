const std = @import("std");

const HittableList = @import("hittable/hittable_list.zig");
const HitRecord = @import("hittable/hit_record.zig");
const Sphere = @import("hittable/sphere.zig");
pub const Rgba = @import("utils.zig").Rgba;
pub const Buffer = @import("buffer.zig");
const v = @import("vector.zig");
const Ray = @import("ray.zig");

pub const Params = struct {
    fill: Rgba,
};

pub fn render(buf: *Buffer, params: Params) !void {
    const width: f64 = @floatFromInt(buf.width);
    const height: f64 = @floatFromInt(buf.height);

    var hittable_list = HittableList.init();
    defer hittable_list.deinit(buf.allocator);

    try hittable_list.add(
        buf.allocator,
        .{ .sphere = Sphere.init(v.init(0, -100.5, -1), 100) },
    );
    try hittable_list.add(
        buf.allocator,
        .{ .sphere = Sphere.init(v.init(0, 0, -1), 0.5) },
    );

    const focal_length: f64 = 1.0;
    const viewport_height: f64 = 2.0;
    const viewport_width = viewport_height * width / height;
    const camera_center = v.zero;

    const viewport_u: v.Vec3 = .{ viewport_width, 0, 0 };
    const viewport_v: v.Vec3 = .{ 0, -viewport_height, 0 };

    const pixel_delta_u = viewport_u / v.splat(width);
    const pixel_delta_v = viewport_v / v.splat(height);

    const viewport_upper_left =
        camera_center - v.init(0, 0, focal_length) - viewport_u / v.splat(2) - viewport_v / v.splat(2);
    const pixel00_loc = viewport_upper_left + v.splat(0.5) * (pixel_delta_u + pixel_delta_v);

    const fill = params.fill.toColor();

    for (0..buf.height) |yi| {
        const y: u32 = @intCast(yi);
        for (buf.row(y), 0..) |*pixel, xi| {
            const pixel_center = pixel00_loc + (v.splat(xi) * pixel_delta_u) + (v.splat(yi) * pixel_delta_v);
            const ray_direction = pixel_center - camera_center;

            const ray = Ray.init(camera_center, ray_direction);

            var hit_record: HitRecord = undefined;
            if (hittable_list.hit(
                &ray,
                0,
                std.math.floatMax(f64),
                &hit_record,
            )) {
                pixel.* = .fromColor(v.splat(0.5) * (hit_record.normal + v.init(1, 1, 1)));
                continue;
            }

            const unit_direction = v.unit(ray.direction);
            const a: f64 = 0.5 * (v.y(unit_direction) + 1.0);
            const color = v.splat(1.0 - a) * v.one + v.splat(a) * fill;
            pixel.* = .fromColor(color);
        }
    }
}
