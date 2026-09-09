pub const Rgba = @import("utils.zig").Rgba;
pub const Buffer = @import("buffer.zig");

pub const Params = struct {
    fill: Rgba,
};

pub fn render(buf: *Buffer, params: Params) void {
    for (0..buf.height) |y| {
        for (buf.row(@intCast(y)), 0..) |*pixel, x| {
            pixel.* = tracePixel(@intCast(x), @intCast(y), params);
        }
    }
}

pub fn tracePixel(x: u32, y: u32, params: Params) Rgba {
    _ = x;
    _ = y;
    return params.fill;
}
