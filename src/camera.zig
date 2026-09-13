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

io: std.Io,
vfov: f64,
width: f64,
height: f64,
center: v.Point,
max_depth: u32,
pixel00_loc: v.Point,
pixel_delta_u: v.Vec3,
pixel_delta_v: v.Vec3,
samples_per_pixel: u32,
lookfrom: v.Point,
lookat: v.Point,
vup: v.Vec3,
pixel_samples_scale: f64,
buffer: *Buffer,
vv: v.Vec3,
u: v.Vec3,
w: v.Vec3,
defocus_angle: f64,
focus_dist: f64,
defocus_disk_u: v.Vec3,
defocus_disk_v: v.Vec3,

pub fn init(buffer: *Buffer, io: std.Io) Camera {
    const width: f64 = @floatFromInt(buffer.width);
    const height: f64 = @floatFromInt(buffer.height);

    const defocus_angle: f64 = 10.0;
    const focus_dist: f64 = 3.4;

    const lookfrom = v.init(-2, 2, 1);
    const lookat = v.init(0, 0, -1);
    const vup = v.init(0, 1, 0);

    const vfov: f64 = 90.0;
    const theta = std.math.degreesToRadians(vfov);
    const h = std.math.tan(theta / 2);
    const viewport_height: f64 = 2 * h * focus_dist;
    const viewport_width = viewport_height * width / height;
    const center = lookfrom;

    const w = v.unit(lookfrom - lookat);
    const u = v.unit(v.cross(vup, w));
    const vv = v.cross(w, u);

    const viewport_u: v.Vec3 = v.splat(viewport_width) * u;
    const viewport_v: v.Vec3 = v.splat(viewport_height) * -vv;

    const pixel_delta_u = viewport_u / v.splat(width);
    const pixel_delta_v = viewport_v / v.splat(height);

    const viewport_upper_left =
        center - (v.splat(focus_dist) * w) - viewport_u / v.splat(2) - viewport_v / v.splat(2);
    const pixel00_loc = viewport_upper_left + v.splat(0.5) * (pixel_delta_u + pixel_delta_v);

    const defocus_radius = focus_dist * std.math.tan(std.math.degreesToRadians(defocus_angle / 2));
    const defocus_disk_u = v.splat(defocus_radius) * u;
    const defocus_disk_v = v.splat(defocus_radius) * vv;

    const samples_per_pixel: u32 = 10;

    return .{
        .io = io,
        .vfov = vfov,
        .width = width,
        .defocus_angle = defocus_angle,
        .focus_dist = focus_dist,
        .u = u,
        .vv = vv,
        .w = w,
        .height = height,
        .lookat = lookat,
        .lookfrom = lookfrom,
        .vup = vup,
        .buffer = buffer,
        .center = center,
        .max_depth = 50,
        .pixel00_loc = pixel00_loc,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(samples_per_pixel)),
        .samples_per_pixel = samples_per_pixel,
        .defocus_disk_u = defocus_disk_u,
        .defocus_disk_v = defocus_disk_v,
    };
}

pub fn render(self: *const Camera, params: Params, world: *const HittableList) !void {
    @setFloatMode(.optimized);
    const fill = params.fill.toColor();

    var group: std.Io.Group = .init;
    defer group.cancel(self.io);

    for (0..self.buffer.height) |y| {
        try group.concurrent(
            self.io,
            renderRow,
            .{ self, fill, world, y },
        );
    }
    try group.await(self.io);
}

fn renderRow(self: *const Camera, fill: v.Vec3, world: *const HittableList, y: usize) !void {
    for (self.buffer.row(@intCast(y)), 0..) |*pixel, x| {
        var pixel_color: v.Vec3 = v.zero;
        for (0..self.samples_per_pixel) |_| {
            const ray = self.get_ray(x, y);
            pixel_color += ray_color(&ray, world, fill, self.max_depth);
        }

        pixel_color *= v.splat(self.pixel_samples_scale);
        pixel.* = .fromColor(pixel_color);
    }
}

fn get_ray(self: *const Camera, x: usize, y: usize) Ray {
    const offset = sample_square();
    const xi: f64 = @floatFromInt(x);
    const yi: f64 = @floatFromInt(y);

    const uvec = v.splat(xi + v.x(offset));
    const vvec = v.splat(yi + v.y(offset));

    const pixel_sample = self.pixel00_loc + (uvec * self.pixel_delta_u) + (vvec * self.pixel_delta_v);
    const ray_origin = if (self.defocus_angle <= 0)
        self.center
    else
        defocus_disk_sample(self);

    const ray_direction = pixel_sample - self.center;

    return .init(ray_origin, ray_direction);
}

fn sample_square() v.Vec3 {
    const r = rand_state.random();
    return v.init(r.float(f64) - 0.5, r.float(f64) - 0.5, 0);
}

fn defocus_disk_sample(camera: *const Camera) v.Point {
    const p = v.randomUnitDisk(rand_state.random());
    return camera.center + (v.splat(v.x(p)) * camera.defocus_disk_u) + (v.splat(v.y(p)) * camera.defocus_disk_v);
}

fn ray_color(ray: *const Ray, world: *const HittableList, fill: v.Vec3, depth: u32) v.Vec3 {
    if (depth <= 0) {
        return v.init(0, 0, 0);
    }

    var hit_record: HitRecord = undefined;
    if (world.hit(ray, .init(0, std.math.inf(f64)), &hit_record)) {
        var scattered: Ray = undefined;
        var attenuation: v.Color = undefined;

        if (hit_record.material.scatter(ray, &hit_record, &attenuation, &scattered)) {
            return attenuation * ray_color(
                &scattered,
                world,
                fill,
                depth - 1,
            );
        }
        return v.zero;
    }

    const unit_direction = v.unit(ray.direction);
    const a: f64 = 0.5 * (v.y(unit_direction) + 1.0);
    return v.splat(1.0 - a) * v.one + v.splat(a) * fill;
}
