const std = @import("std");
const ray = @import("ray");

const Buffer = ray.Buffer;

const Renderer = @This();

buffer: Buffer,
fill: ray.Rgba,
clear_color: ray.Rgba = .{ .r = 18, .g = 20, .b = 26, .a = 255 },

pub fn init(
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    fill: ray.Rgba,
) !Renderer {
    var buffer = try Buffer.init(allocator, width, height);
    errdefer buffer.deinit();

    var self: Renderer = .{ .buffer = buffer, .fill = fill };
    self.buffer.clear(self.clear_color);
    return self;
}

pub fn deinit(self: *Renderer) void {
    self.buffer.deinit();
    self.* = undefined;
}

pub fn render(self: *Renderer) void {
    ray.render(&self.buffer, .{ .fill = self.fill });
}
