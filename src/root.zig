const std = @import("std");

const scene_mod = @import("scene.zig");

pub const Buffer = @import("buffer.zig");
pub const Camera = @import("camera.zig");
pub const Rgba = @import("utils.zig").Rgba;
pub const vector = @import("vector.zig");

pub const Scene = scene_mod.Scene;
pub const SphereDesc = scene_mod.SphereDesc;
pub const MaterialDesc = scene_mod.MaterialDesc;
pub const MaterialKind = scene_mod.MaterialKind;
pub const material_kind_names = scene_mod.material_kind_names;

/// Traces `scene` into `buffer`, which must already be sized to the scene's
/// resolution. The caller owns `scene` for the duration of the call. Setting
/// `cancel` while the trace runs stops it early.
pub fn render(
    io: std.Io,
    buffer: *Buffer,
    scene: *const Scene,
    cancel: ?*const std.atomic.Value(bool),
) !void {
    var world = try scene.build(buffer.allocator);
    defer world.deinit(buffer.allocator);

    const camera = Camera.init(buffer, io, scene.camera);
    try camera.render(&world.list, cancel);
}

test {
    std.testing.refAllDecls(@This());
    _ = scene_mod;
}

test "rendering the default scene fills the buffer" {
    const allocator = std.testing.allocator;

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();

    var scene = try Scene.initDefault(allocator);
    defer scene.deinit(allocator);

    // Small and cheap: this is checking that the pipeline runs end to end, not
    // that it converges.
    scene.width = 24;
    scene.height = 16;
    scene.camera.samples_per_pixel = 2;
    scene.camera.max_depth = 4;

    var buffer = try Buffer.init(allocator, scene.width, scene.height);
    defer buffer.deinit();
    buffer.clear(.{ .r = 0, .g = 0, .b = 0, .a = 0 });

    try render(threaded.io(), &buffer, &scene, null);

    // The sky gradient alone guarantees a lit top row, and every pixel the
    // tracer touches is written opaque.
    var lit: usize = 0;
    for (buffer.pixels) |pixel| {
        try std.testing.expectEqual(@as(u8, 255), pixel.a);
        if (pixel.r != 0 or pixel.g != 0 or pixel.b != 0) lit += 1;
    }
    try std.testing.expect(lit > buffer.pixels.len / 2);
}
