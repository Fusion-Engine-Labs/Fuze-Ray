pub const Rgba = @import("utils.zig").Rgba;
pub const Buffer = @import("buffer.zig");
const v = @import("vector.zig");
const Ray = @import("ray.zig");

pub const Params = struct {
    fill: Rgba,
};

fn hit_sphere(center: v.Vec3, radius: f64, ray: *const Ray) f64 {
    const oc = center - ray.origin;
    const a = v.magnitude_squared(ray.direction);
    const h = v.dot(ray.direction, oc);
    const c = v.dot(oc, oc) - (radius * radius);

    const discriminant = h * h - a * c;
    if (discriminant < 0) {
        return -1;
    }
    return (h - @sqrt(discriminant)) / a;
}

pub fn render(buf: *Buffer, params: Params) void {
    const width: f64 = @floatFromInt(buf.width);
    const height: f64 = @floatFromInt(buf.height);

    const focal_length: f64 = 1.0;
    const viewport_height: f64 = 2.0;
    const viewport_width = viewport_height * width / height;
    const camera_center = v.zero;

    const viewport_u: v.Vec3 = .{ viewport_width, 0, 0 };
    const viewport_v: v.Vec3 = .{ 0, -viewport_height, 0 };

    const pixel_delta_u = viewport_u / v.splat(width);
    const pixel_delta_v = viewport_v / v.splat(height);

    const viewport_upper_left = camera_center - v.init(0, 0, focal_length) - viewport_u / v.splat(2) - viewport_v / v.splat(2);
    const pixel00_loc = viewport_upper_left + v.splat(0.5) * (pixel_delta_u + pixel_delta_v);

    const fill = params.fill.toColor();

    for (0..buf.height) |yi| {
        const y: u32 = @intCast(yi);
        for (buf.row(y), 0..) |*pixel, xi| {
            const pixel_center = pixel00_loc + (v.splat(xi) * pixel_delta_u) + (v.splat(yi) * pixel_delta_v);
            const ray_direction = pixel_center - camera_center;

            const ray = Ray.init(camera_center, ray_direction);
            const t = hit_sphere(v.init(0, 0, -1), 0.5, &ray);
            if (t > 0.0) {
                const N = v.unit(ray.at(t) - v.init(0, 0, -1));
                pixel.* = .fromColor(v.splat(0.5) * v.init(v.x(N) + 1, v.y(N) + 1, v.z(N) + 1));
                continue;
            }

            const unit_direction = v.unit(ray.direction);
            const a: f64 = 0.5 * (v.y(unit_direction) + 1.0);
            const color = v.splat(1.0 - a) * v.one + v.splat(a) * fill;
            pixel.* = .fromColor(color);
        }
    }
}
