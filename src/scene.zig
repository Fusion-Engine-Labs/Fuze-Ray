const std = @import("std");

const HittableList = @import("hittable/hittable_list.zig");
const Material = @import("material/material.zig").Material;
const Sphere = @import("hittable/sphere.zig");
const Camera = @import("camera.zig");
const v = @import("vector.zig");

pub const Scene = struct {
    width: u32 = 1920,
    height: u32 = 1080,
    camera: Camera.Settings = .{},
    spheres: std.ArrayList(SphereDesc) = .empty,

    pub fn initDefault(allocator: std.mem.Allocator) !Scene {
        var scene: Scene = .{};
        errdefer scene.deinit(allocator);
        try scene.spheres.appendSlice(allocator, &default_spheres);
        return scene;
    }

    pub fn deinit(self: *Scene, allocator: std.mem.Allocator) void {
        self.spheres.deinit(allocator);
        self.* = undefined;
    }

    pub fn clone(self: *const Scene, allocator: std.mem.Allocator) !Scene {
        var copy = self.*;
        copy.spheres = try self.spheres.clone(allocator);
        return copy;
    }

    pub fn add(self: *Scene, allocator: std.mem.Allocator, sphere: SphereDesc) !void {
        try self.spheres.append(allocator, sphere);
    }

    pub fn remove(self: *Scene, index: usize) void {
        _ = self.spheres.orderedRemove(index);
    }

    pub fn build(self: *const Scene, allocator: std.mem.Allocator) !World {
        const materials = try allocator.alloc(Material, self.spheres.items.len);
        errdefer allocator.free(materials);

        var list = HittableList.init();
        errdefer list.deinit(allocator);
        try list.hittables.ensureTotalCapacityPrecise(allocator, self.spheres.items.len);

        for (self.spheres.items, materials) |sphere, *material| {
            material.* = sphere.material.resolve();
            list.hittables.appendAssumeCapacity(.{
                .sphere = Sphere.init(sphere.center, sphere.radius, material),
            });
        }

        return .{ .list = list, .materials = materials };
    }
};

pub const World = struct {
    list: HittableList,
    materials: []Material,

    pub fn deinit(self: *World, allocator: std.mem.Allocator) void {
        self.list.deinit(allocator);
        allocator.free(self.materials);
        self.* = undefined;
    }
};

pub const SphereDesc = struct {
    center: v.Point = v.init(0, 0, -1),
    radius: f64 = 0.5,
    material: MaterialDesc = .{},
};

pub const MaterialDesc = struct {
    kind: MaterialKind = .lambertian,
    albedo: v.Color = v.init(0.7, 0.7, 0.7),
    fuzz: f64 = 0.0,
    refraction_index: f64 = 1.5,

    fn resolve(self: MaterialDesc) Material {
        return switch (self.kind) {
            .lambertian => .{ .lambertian = .{ .albedo = self.albedo } },
            .metal => .{ .metal = .{ .albedo = self.albedo, .fuzz = self.fuzz } },
            .dielectric => .{ .dielectric = .{ .refraction_index = self.refraction_index } },
        };
    }
};

pub const MaterialKind = enum {
    lambertian,
    metal,
    dielectric,

    pub fn name(self: MaterialKind) []const u8 {
        return switch (self) {
            .lambertian => "Diffuse",
            .metal => "Metal",
            .dielectric => "Glass",
        };
    }

    pub fn tintsLight(self: MaterialKind) bool {
        return switch (self) {
            .lambertian, .metal => true,
            .dielectric => false,
        };
    }
};

pub const material_kind_names = names: {
    const fields = @typeInfo(MaterialKind).@"enum".fields;
    var out: [fields.len][]const u8 = undefined;
    for (fields, &out) |field, *slot| {
        slot.* = MaterialKind.name(@enumFromInt(field.value));
    }
    break :names out;
};

const default_spheres = [_]SphereDesc{
    .{
        .center = v.init(0, -100.5, -1),
        .radius = 100,
        .material = .{ .kind = .lambertian, .albedo = v.init(0.8, 0.8, 0.0) },
    },
    .{
        .center = v.init(0, 0, -1.2),
        .radius = 0.5,
        .material = .{ .kind = .lambertian, .albedo = v.init(0.1, 0.2, 0.5) },
    },
    .{
        .center = v.init(-1, 0, -1),
        .radius = 0.5,
        .material = .{ .kind = .dielectric, .refraction_index = 1.5 },
    },
    .{
        .center = v.init(-1, 0, -1),
        .radius = 0.4,
        .material = .{ .kind = .dielectric, .refraction_index = 1.0 / 1.5 },
    },
    .{
        .center = v.init(1, 0, -1),
        .radius = 0.5,
        .material = .{ .kind = .metal, .albedo = v.init(0.8, 0.6, 0.2), .fuzz = 1.0 },
    },
};
