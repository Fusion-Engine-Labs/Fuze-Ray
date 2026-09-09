pub const Rgba = @import("utils.zig").Rgba;
pub const Buffer = @import("buffer.zig");

pub const Params = struct {
    fill: Rgba,
};

pub fn render(buf: *Buffer, params: Params) void {
    for (0..buf.height) |yi| {
        const y: u32 = @intCast(yi);
        for (buf.row(y), 0..) |*pixel, xi| {
            const x: u32 = @intCast(xi);
            _ = x;
            pixel.* = params.fill;
        }
    }
}
