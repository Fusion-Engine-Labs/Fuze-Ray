const std = @import("std");

const Hittable = @import("hittable.zig").Hittable;
const Interval = @import("../interval.zig");
const HitRecord = @import("hit_record.zig");
const Ray = @import("../ray.zig");

const HittableList = @This();

hittables: std.ArrayList(Hittable),

pub fn init() HittableList {
    return .{ .hittables = .empty };
}

pub fn deinit(self: *HittableList, allocator: std.mem.Allocator) void {
    self.hittables.deinit(allocator);
}

pub fn clear(self: *HittableList) void {
    self.hittables.clearRetainingCapacity();
}

pub fn add(self: *HittableList, allocator: std.mem.Allocator, obj: Hittable) !void {
    try self.hittables.append(allocator, obj);
}

pub fn hit(
    self: *const HittableList,
    ray: *const Ray,
    ray_t: Interval,
    hit_record: *HitRecord,
) bool {
    var temp_rec: HitRecord = undefined;
    var hit_anything = false;
    var closest_so_far = ray_t.max;

    for (self.hittables.items) |obj| {
        if (obj.hit(ray, ray_t, hit_record)) {
            hit_anything = true;
            closest_so_far = hit_record.t;
            temp_rec = hit_record.*;
        }
    }

    return hit_anything;
}
