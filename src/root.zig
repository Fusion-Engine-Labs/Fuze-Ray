const std = @import("std");

const HittableList = @import("hittable/hittable_list.zig");
const Material = @import("material/material.zig").Material;
const Dialectric = @import("material/dialectric.zig");
const Lambertion = @import("material/lambertion.zig");
const Sphere = @import("hittable/sphere.zig");
const Metal = @import("material/metal.zig");
pub const Rgba = @import("utils.zig").Rgba;
pub const Buffer = @import("buffer.zig");
const Camera = @import("camera.zig");
const v = @import("vector.zig");

pub const Params = struct {
    fill: Rgba,
};

pub fn render(io: std.Io, buf: *Buffer, params: Params) !void {
    var hittable_list = HittableList.init();
    defer hittable_list.deinit(buf.allocator);

    const material_ground = Lambertion{
        .albedo = v.init(0.8, 0.8, 0.0),
    };
    const material_center = Lambertion{
        .albedo = v.init(0.1, 0.2, 0.5),
    };
    const material_left = Dialectric{
        .refraction_index = 1.5,
    };
    const material_bubble = Dialectric{
        .refraction_index = 1.0 / 1.5,
    };
    const material_right = Metal{
        .albedo = v.init(0.8, 0.6, 0.2),
        .fuzz = 1.0,
    };

    const sphere_one = Sphere.init(
        v.init(0, -100.5, -1),
        100,
        &.{ .lambertion = material_ground },
    );

    const sphere_two = Sphere.init(
        v.init(0, 0, -1.2),
        0.5,
        &.{ .lambertion = material_center },
    );

    const sphere_three = Sphere.init(
        v.init(-1, 0, -1),
        0.5,
        &.{ .dialetric = material_left },
    );

    const sphere_four = Sphere.init(
        v.init(1, 0, -1),
        0.5,
        &.{ .metal = material_right },
    );

    const sphere_five = Sphere.init(
        v.init(-1, 0, -1),
        0.4,
        &.{ .dialetric = material_bubble },
    );

    try hittable_list.add(
        buf.allocator,
        .{ .sphere = sphere_one },
    );
    try hittable_list.add(
        buf.allocator,
        .{ .sphere = sphere_two },
    );
    try hittable_list.add(
        buf.allocator,
        .{ .sphere = sphere_three },
    );
    try hittable_list.add(
        buf.allocator,
        .{ .sphere = sphere_four },
    );
    try hittable_list.add(
        buf.allocator,
        .{ .sphere = sphere_five },
    );

    const camera = Camera.init(buf, io);
    try camera.render(params, &hittable_list);
}
