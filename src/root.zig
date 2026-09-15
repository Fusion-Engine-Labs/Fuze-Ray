pub const Rgba = @import("utils.zig").Rgba;
pub const Buffer = @import("buffer.zig");

pub const Entity = struct {
    fill: Rgba,
    position: [3]f64,
    radius: f64,
};

pub fn render(buf: *Buffer, entity: Entity) void {
    for (0..buf.height) |yi| {
        const y: u32 = @intCast(yi);
        for (buf.row(y), 0..) |*pixel, xi| {
            const x: u32 = @intCast(xi);
            _ = x;
            pixel.* = entity.fill;
        }
    }
}
