const std = @import("std");
const v = @import("vector.zig");

pub const Rgba = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn fromColor(color: v.Color) Rgba {
        return .{
            .r = encode(color[0]),
            .g = encode(color[1]),
            .b = encode(color[2]),
        };
    }

    pub fn toColor(self: Rgba) v.Color {
        return .{ decode(self.r), decode(self.g), decode(self.b) };
    }
};

fn encode(value: f64) u8 {
    return @intFromFloat(@round(std.math.clamp(v.toGamma(value), 0, 1) * 255));
}

fn decode(value: u8) f64 {
    const scaled = @as(f64, @floatFromInt(value)) / 255;
    return scaled * scaled;
}
