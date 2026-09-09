const Rgba = @import("utils.zig").Rgba;
const std = @import("std");

const Buffer = @This();

allocator: std.mem.Allocator,
width: u32 = 0,
height: u32 = 0,
pixels: []Rgba = &.{},

pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Buffer {
    var self: Buffer = .{ .allocator = allocator };
    try self.resize(width, height);
    return self;
}

pub fn deinit(self: *Buffer) void {
    self.allocator.free(self.pixels);
    self.* = undefined;
}

pub fn resize(self: *Buffer, width: u32, height: u32) !void {
    const w = @max(1, width);
    const h = @max(1, height);
    if (w == self.width and h == self.height) {
        return;
    }

    const pixels = try self.allocator.alloc(Rgba, @as(usize, w) * @as(usize, h));
    self.allocator.free(self.pixels);
    self.pixels = pixels;
    self.width = w;
    self.height = h;
}

pub fn clear(self: *Buffer, color: Rgba) void {
    @memset(self.pixels, color);
}

pub fn set(self: *Buffer, x: u32, y: u32, color: Rgba) void {
    if (x >= self.width or y >= self.height) {
        return;
    }
    self.pixels[@as(usize, y) * @as(usize, self.width) + @as(usize, x)] = color;
}

pub fn get(self: Buffer, x: u32, y: u32) Rgba {
    if (x >= self.width or y >= self.height) {
        return .{};
    }
    return self.pixels[@as(usize, y) * @as(usize, self.width) + @as(usize, x)];
}

pub fn row(self: Buffer, y: u32) []Rgba {
    std.debug.assert(y < self.height);
    const start = @as(usize, y) * @as(usize, self.width);
    return self.pixels[start..][0..self.width];
}

pub fn bytes(self: Buffer) []const u8 {
    return std.mem.sliceAsBytes(self.pixels);
}
