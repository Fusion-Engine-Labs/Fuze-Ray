const std = @import("std");

const HittableList = @import("hittable/hittable_list.zig");
const HitRecord = @import("hittable/hit_record.zig");
const Params = @import("root.zig").Params;
const Rgba = @import("utils.zig").Rgba;
const Buffer = @import("buffer.zig");
const v = @import("vector.zig");
const Ray = @import("ray.zig");

pub threadlocal var rand_state = std.Random.DefaultPrng.init(70);

const Camera = @This();

width: f64,
height: f64,
center: v.Point,
pixel00_loc: v.Point,
pixel_delta_u: v.Vec3,
pixel_delta_v: v.Vec3,
samples_per_pixel: u32,
pixel_samples_scale: f64,
buffer: *Buffer,

pub fn init(buffer: *Buffer) Camera {
    const width: f64 = @floatFromInt(buffer.width);
    const height: f64 = @floatFromInt(buffer.height);

    const focal_length: f64 = 1.0;
    const viewport_height: f64 = 2.0;
    const viewport_width = viewport_height * width / height;
    const center = v.zero;

    const viewport_u: v.Vec3 = .{ viewport_width, 0, 0 };
    const viewport_v: v.Vec3 = .{ 0, -viewport_height, 0 };

    const pixel_delta_u = viewport_u / v.splat(width);
    const pixel_delta_v = viewport_v / v.splat(height);

    const viewport_upper_left =
        center - v.init(0, 0, focal_length) - viewport_u / v.splat(2) - viewport_v / v.splat(2);
    const pixel00_loc = viewport_upper_left + v.splat(0.5) * (pixel_delta_u + pixel_delta_v);

    const samples_per_pixel: u32 = 10;

    return .{
        .width = width,
        .height = height,
        .buffer = buffer,
        .center = center,
        .pixel00_loc = pixel00_loc,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(samples_per_pixel)),
        .samples_per_pixel = samples_per_pixel,
    };
}

pub fn render(self: *const Camera, params: Params, world: *const HittableList) !void {
    @setFloatMode(.optimized);
    const fill = params.fill.toColor();

    for (0..self.buffer.height) |y| {
        for (self.buffer.row(@intCast(y)), 0..) |*pixel, x| {
            var pixel_color: v.Vec3 = v.zero;
            for (0..self.samples_per_pixel) |_| {
                const ray = self.get_ray(x, y);
                pixel_color += ray_color(&ray, world, fill);
            }

            pixel_color *= v.splat(self.pixel_samples_scale);
            pixel.* = .fromColor(pixel_color);
        }
    }
}

fn get_ray(self: *const Camera, x: usize, y: usize) Ray {
    const offset = sample_square();
    const xi: f64 = @floatFromInt(x);
    const yi: f64 = @floatFromInt(y);

    const uvec = v.splat(xi + v.x(offset));
    const vvec = v.splat(yi + v.y(offset));

    const pixel_sample = self.pixel00_loc + (uvec * self.pixel_delta_u) + (vvec * self.pixel_delta_v);
    const ray_direction = pixel_sample - self.center;

    return .init(self.center, ray_direction);
}

fn sample_square() v.Vec3 {
    const r = rand_state.random();
    return v.init(r.float(f64) - 0.5, r.float(f64) - 0.5, 0);
}

fn ray_color(ray: *const Ray, world: *const HittableList, fill: v.Vec3) v.Vec3 {
    var hit_record: HitRecord = undefined;
    if (world.hit(ray, .init(0, std.math.floatMax(f64)), &hit_record)) {
        return v.splat(0.5) * (hit_record.normal + v.init(1, 1, 1));
    }

    const unit_direction = v.unit(ray.direction);
    const a: f64 = 0.5 * (v.y(unit_direction) + 1.0);
    return v.splat(1.0 - a) * v.one + v.splat(a) * fill;
}
