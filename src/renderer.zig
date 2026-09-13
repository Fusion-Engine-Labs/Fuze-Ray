const std = @import("std");
const ray = @import("ray");

const Buffer = ray.Buffer;

const Renderer = @This();

io: std.Io,
buffer: Buffer,
fill: ray.Rgba,
clear_color: ray.Rgba = .{ .r = 18, .g = 20, .b = 26, .a = 255 },
thread: ?std.Thread = null,
running: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
elapsed_ns: i96 = 0,

pub fn init(
    allocator: std.mem.Allocator,
    io: std.Io,
    width: u32,
    height: u32,
    fill: ray.Rgba,
) !Renderer {
    var buffer = try Buffer.init(allocator, width, height);
    errdefer buffer.deinit();

    var self: Renderer = .{ .io = io, .buffer = buffer, .fill = fill };
    self.buffer.clear(self.clear_color);
    return self;
}

pub fn deinit(self: *Renderer) void {
    self.wait();
    self.buffer.deinit();
    self.* = undefined;
}

pub fn start(self: *Renderer) !void {
    if (self.isRendering()) {
        return;
    }
    self.wait();
    self.buffer.clear(self.clear_color);
    self.running.store(true, .release);
    self.thread = std.Thread.spawn(.{}, work, .{self}) catch |err| {
        self.running.store(false, .release);
        return err;
    };
}

pub fn isRendering(self: *const Renderer) bool {
    return self.running.load(.acquire);
}

pub fn wait(self: *Renderer) void {
    if (self.thread) |thread| {
        thread.join();
        self.thread = null;
    }
}

fn work(self: *Renderer) void {
    const start_ns = nowNs(self.io);
    ray.render(self.io, &self.buffer, .{ .fill = self.fill }) catch |err| {
        std.debug.print("ray: render error: {}\n", .{err});
    };
    self.elapsed_ns = nowNs(self.io) - start_ns;
    self.running.store(false, .release);
}

fn nowNs(io: std.Io) i96 {
    return std.Io.Clock.awake.now(io).toNanoseconds();
}
