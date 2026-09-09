const Renderer = @import("renderer.zig");
const gui_glfw = @import("zGUI_glfw");
const ui = @import("ui.zig");
const gui = @import("zGUI");
const std = @import("std");

const render_width = 1920;
const render_height = 1080;

const viewport_width = render_width * 2 / 3;
const viewport_height = render_height * 2 / 3;

const window_width = viewport_width + ui.chrome_width;
const window_height = viewport_height + ui.chrome_height;

const fps_window_ns: i96 = std.time.ns_per_s / 4;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var platform = try gui_glfw.GlfwPlatform.init(gpa, window_width, window_height, "ray");
    defer platform.deinit();
    platform.makeContextCurrent();

    var gl = try gui.OpenGlRenderer.init(gpa, gui_glfw.GlfwPlatform.getProcAddress);
    defer gl.deinit();

    const font_bytes = @embedFile("app_font");
    var font_atlas = try gui.FontAtlas.init(gpa, font_bytes, 1024, 1024);
    defer font_atlas.deinit();

    var state = try gui.Ui.init(gpa);
    defer state.deinit();

    const raster_scale = framebufferScale(platform.getWindowSize(), platform.getFramebufferSize());
    const theme_font_sizes = state.theme.font.sizes();
    try font_atlas.prewarmAscii(&theme_font_sizes, raster_scale);
    try gl.syncFontAtlas(&font_atlas);
    state.setFontAtlas(&font_atlas);

    var renderer = try Renderer.init(gpa, render_width, render_height, ui.initialFill());
    defer renderer.deinit();

    var texture = try gl.createTextureRgba(
        renderer.buffer.width,
        renderer.buffer.height,
        renderer.buffer.bytes(),
    );
    defer gl.destroyTexture(&texture);

    var panel = try ui.Panel.init(gpa, &state, texture);
    defer panel.deinit(&state);

    var last_cursor: ?gui.CursorKind = null;
    var last_frame_ns = nowNs(io);
    var last_render_ns: ?i96 = null;
    var fps: ?f32 = null;
    var fps_window_start_ns = last_frame_ns;
    var fps_window_frames: u32 = 0;

    while (!platform.shouldClose()) {
        const frame_start_ns = nowNs(io);
        const dt = std.math.clamp(
            nanosToSeconds(frame_start_ns - last_frame_ns),
            1.0 / 10_000.0,
            0.25,
        );
        last_frame_ns = frame_start_ns;

        fps_window_frames += 1;
        const fps_elapsed_ns = frame_start_ns - fps_window_start_ns;
        if (fps_elapsed_ns >= fps_window_ns) {
            const frames: f32 = @floatFromInt(fps_window_frames);
            fps = frames / nanosToSeconds(fps_elapsed_ns);
            fps_window_start_ns = frame_start_ns;
            fps_window_frames = 0;
        }

        const platform_events = platform.pollEvents();
        const size = platform.getWindowSize();
        const framebuffer_size = platform.getFramebufferSize();

        try state.beginFrame(.{
            .events = platform_events,
            .window_size = size,
            .dt = dt,
            .clipboard = platform.clipboard(),
        });

        try panel.update(&state);
        renderer.fill = panel.fill();

        const needs_render = panel.startClicked(&state);

        try panel.fitViewport(&state, renderer.buffer.width, renderer.buffer.height);

        if (needs_render) {
            const render_start_ns = nowNs(io);
            renderer.render();
            last_render_ns = nowNs(io) - render_start_ns;
            try gl.uploadTextureRgba(
                texture,
                renderer.buffer.width,
                renderer.buffer.height,
                renderer.buffer.bytes(),
            );
        }

        try panel.sync(&state, .{
            .fps = fps,
            .last_render_ns = last_render_ns,
            .width = renderer.buffer.width,
            .height = renderer.buffer.height,
        });

        const cursor = state.requestedCursor();
        if (last_cursor == null or last_cursor.? != cursor) {
            platform.setCursor(cursor);
            last_cursor = cursor;
        }

        state.setTextRasterScale(framebufferScale(size, framebuffer_size));
        try state.endFrame();
        try gl.syncFontAtlas(&font_atlas);

        const framebuffer_width: u32 = @intFromFloat(@max(1, framebuffer_size.x));
        const framebuffer_height: u32 = @intFromFloat(@max(1, framebuffer_size.y));
        try gl.beginFrameLogical(framebuffer_width, framebuffer_height, size.x, size.y);
        try gl.render(state.drawData());
        try gl.endFrame();
        platform.swapBuffers();
    }
}

fn nowNs(io: std.Io) i96 {
    return std.Io.Clock.awake.now(io).toNanoseconds();
}

fn nanosToSeconds(ns: i96) f32 {
    return @as(f32, @floatFromInt(ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));
}

fn framebufferScale(window_size: gui.Vec2, framebuffer_size: gui.Vec2) f32 {
    const x = framebuffer_size.x / @max(1, window_size.x);
    const y = framebuffer_size.y / @max(1, window_size.y);
    return @max(0.25, @max(x, y));
}
