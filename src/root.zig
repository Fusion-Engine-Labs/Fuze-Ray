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

const Scene = struct {
    list: HittableList,
    materials: std.ArrayList(*Material),

    fn deinit(self: *Scene, allocator: std.mem.Allocator) void {
        for (self.materials.items) |m| allocator.destroy(m);
        self.materials.deinit(allocator);
        self.list.deinit(allocator);
    }
};

/// Allocates `material` on the heap so its address stays valid for the
/// lifetime of the returned Scene, rather than pointing into this
/// function's stack frame.
fn addMaterial(scene: *Scene, allocator: std.mem.Allocator, material: Material) !*Material {
    const m = try allocator.create(Material);
    m.* = material;
    try scene.materials.append(allocator, m);
    return m;
}

fn scene1(allocator: std.mem.Allocator) !Scene {
    var scene: Scene = .{ .list = HittableList.init(), .materials = .empty };
    errdefer scene.deinit(allocator);

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
        try addMaterial(&scene, allocator, .{ .lambertion = material_ground }),
    );

    const sphere_two = Sphere.init(
        v.init(0, 0, -1.2),
        0.5,
        try addMaterial(&scene, allocator, .{ .lambertion = material_center }),
    );

    const sphere_three = Sphere.init(
        v.init(-1, 0, -1),
        0.5,
        try addMaterial(&scene, allocator, .{ .dialetric = material_left }),
    );

    const sphere_four = Sphere.init(
        v.init(1, 0, -1),
        0.5,
        try addMaterial(&scene, allocator, .{ .metal = material_right }),
    );

    const sphere_five = Sphere.init(
        v.init(-1, 0, -1),
        0.4,
        try addMaterial(&scene, allocator, .{ .dialetric = material_bubble }),
    );

    try scene.list.add(
        allocator,
        .{ .sphere = sphere_one },
    );
    try scene.list.add(
        allocator,
        .{ .sphere = sphere_two },
    );
    try scene.list.add(
        allocator,
        .{ .sphere = sphere_three },
    );
    try scene.list.add(
        allocator,
        .{ .sphere = sphere_four },
    );
    try scene.list.add(
        allocator,
        .{ .sphere = sphere_five },
    );

    return scene;
}

pub fn render(io: std.Io, buf: *Buffer, params: Params) !void {
    var scene = try scene1(buf.allocator);
    defer scene.deinit(buf.allocator);

    const camera = Camera.init(buf, io);
    try camera.render(params, &scene.list);
}
