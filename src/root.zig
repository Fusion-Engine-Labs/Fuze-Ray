const std = @import("std");

const HittableList = @import("hittable/hittable_list.zig");
const Material = @import("material/material.zig").Material;
const Dialectric = @import("material/dialectric.zig");
const Lambertion = @import("material/lambertion.zig");
const Sphere = @import("hittable/sphere.zig");
const Metal = @import("material/metal.zig");
const Rng = @import("rng.zig");
pub const Rgba = @import("utils.zig").Rgba;
pub const Buffer = @import("buffer.zig");
const Camera = @import("camera.zig");
const v = @import("vector.zig");

pub const SceneChoice = enum { one, two };

pub const Params = struct {
    fill: Rgba,
    scene: SceneChoice = .one,
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

fn scene2(allocator: std.mem.Allocator) !Scene {
    var scene: Scene = .{ .list = HittableList.init(), .materials = .empty };
    errdefer scene.deinit(allocator);

    const r = Rng.random();

    const ground_material = Lambertion{ .albedo = v.init(0.5, 0.5, 0.5) };
    try scene.list.add(allocator, .{ .sphere = Sphere.init(
        v.init(0, -1000, 0),
        1000,
        try addMaterial(&scene, allocator, .{ .lambertion = ground_material }),
    ) });

    var a: i32 = -11;
    while (a < 11) : (a += 1) {
        var b: i32 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = r.float(f64);
            const center = v.init(
                @as(f64, @floatFromInt(a)) + 0.9 * r.float(f64),
                0.2,
                @as(f64, @floatFromInt(b)) + 0.9 * r.float(f64),
            );

            if (v.magnitude(center - v.init(4, 0.2, 0)) > 0.9) {
                const material: *const Material = blk: {
                    if (choose_mat < 0.8) {
                        const albedo = v.random(r) * v.random(r);
                        break :blk try addMaterial(&scene, allocator, .{ .lambertion = .{ .albedo = albedo } });
                    } else if (choose_mat < 0.95) {
                        const albedo = v.randomRange(r, 0.5, 1);
                        const fuzz = 0.5 * r.float(f64);
                        break :blk try addMaterial(&scene, allocator, .{ .metal = .{ .albedo = albedo, .fuzz = fuzz } });
                    } else {
                        break :blk try addMaterial(&scene, allocator, .{ .dialetric = .{ .refraction_index = 1.5 } });
                    }
                };

                try scene.list.add(allocator, .{ .sphere = Sphere.init(center, 0.2, material) });
            }
        }
    }

    try scene.list.add(allocator, .{ .sphere = Sphere.init(
        v.init(0, 1, 0),
        1.0,
        try addMaterial(&scene, allocator, .{ .dialetric = .{ .refraction_index = 1.5 } }),
    ) });

    try scene.list.add(allocator, .{ .sphere = Sphere.init(
        v.init(-4, 1, 0),
        1.0,
        try addMaterial(&scene, allocator, .{ .lambertion = .{ .albedo = v.init(0.4, 0.2, 0.1) } }),
    ) });

    try scene.list.add(allocator, .{ .sphere = Sphere.init(
        v.init(4, 1, 0),
        1.0,
        try addMaterial(&scene, allocator, .{ .metal = .{ .albedo = v.init(0.7, 0.6, 0.5), .fuzz = 0.0 } }),
    ) });

    return scene;
}

const scene2_camera_settings: Camera.Settings = .{
    .vfov = 20,
    .lookfrom = v.init(13, 2, 3),
    .lookat = v.init(0, 0, 0),
    .vup = v.init(0, 1, 0),
    .defocus_angle = 0.6,
    .focus_dist = 10.0,
    .samples_per_pixel = 500,
    .max_depth = 50,
};

pub fn render(io: std.Io, buf: *Buffer, params: Params) !void {
    var scene = switch (params.scene) {
        .one => try scene1(buf.allocator),
        .two => try scene2(buf.allocator),
    };
    defer scene.deinit(buf.allocator);

    const camera_settings: Camera.Settings = switch (params.scene) {
        .one => .{},
        .two => scene2_camera_settings,
    };

    const camera = Camera.init(buf, io, camera_settings);
    try camera.render(params, &scene.list);
}
