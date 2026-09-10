const std = @import("std");

const HittableList = @import("hittable/hittable_list.zig");
const Sphere = @import("hittable/sphere.zig");
pub const Rgba = @import("utils.zig").Rgba;
pub const Buffer = @import("buffer.zig");
const Camera = @import("camera.zig");
const v = @import("vector.zig");

pub const Params = struct {
    fill: Rgba,
};

pub fn render(buf: *Buffer, params: Params) !void {
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

    const camera = Camera.init(buf);
    try camera.render(params, &hittable_list);
}
