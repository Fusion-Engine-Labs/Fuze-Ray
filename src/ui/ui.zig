const Inspector = @import("inspector.zig").Inspector;
const controls = @import("controls.zig");
const gui = @import("zGUI");
const std = @import("std");
const ray = @import("ray");

const toolbar_height: f32 = 44;
const side_panel_width: f32 = 312;
const body_padding: f32 = 8;
const body_gap: f32 = 8;

/// Space the window needs on top of the viewport it is asked to show.
pub const chrome_width: u32 = @intFromFloat(side_panel_width + body_gap + body_padding * 2);
pub const chrome_height: u32 = @intFromFloat(toolbar_height + body_padding * 2);

/// What a frame of panel input asked for.
pub const Frame = struct {
    /// The user pressed the render action, which starts a render when none is
    /// running and stops the one in flight when there is.
    render_toggled: bool = false,
    /// A control changed something the tracer reads.
    scene_edited: bool = false,
};

/// Everything the app shows outside the traced image itself.
pub const Stats = struct {
    fps: ?f32,
    /// Duration of the last completed render, or null before the first one.
    last_render_ns: ?i96,
    /// Size of the pixel buffer currently on screen.
    width: u32,
    height: u32,
    rendering: bool,
    /// The last render was stopped before it finished.
    canceled: bool,
    /// The scene has been edited since the image on screen was traced.
    edited: bool,
};

const Fit = struct {
    width: f32 = 0,
    height: f32 = 0,
    left: f32 = 0,
    top: f32 = 0,
};

pub const Panel = struct {
    viewport: gui.NodeId,
    image: gui.NodeId,
    render_button: gui.NodeId,
    status_label: gui.NodeId,
    state_label: gui.NodeId,
    fps_label: gui.NodeId,
    inspector: Inspector,
    fit: Fit = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        texture: gui.TextureHandle,
        scene: *const ray.Scene,
    ) !Panel {
        const root = ui.rootNode();
        try ui.setStyle(root, ui.theme.style(.{
            .width = .fill,
            .height = .fill,
            .direction = .column,
            .background = .app,
        }));

        const toolbar = try gui.widgets.toolbar(ui, root, ui.theme.style(.{
            .width = .fill,
            .height = .{ .px = toolbar_height },
            .gap = ui.theme.space.xl,
            .padding = .{ .left = 14, .right = 14 },
            .background = .shell,
            .border = .stroke_soft,
            .border_width = 1,
        }));

        _ = try gui.widgets.text(ui, toolbar, "Fusion Raytracer", .{
            .width = .hug,
            .height = .fill,
            .padding = .{ .top = ui.centeredTextTop(toolbar_height, ui.theme.font.title) },
            .color = .text,
            .size = ui.theme.font.title,
        });
        const fps_label = try toolbarStat(ui, toolbar, .fill);

        const body = try gui.widgets.row(ui, root, .{
            .width = .fill,
            .height = .fill,
            .gap = body_gap,
            .padding = gui.Edges.all(body_padding),
        });

        const viewport = try gui.widgets.column(ui, body, .{
            .width = .fill,
            .height = .fill,
            .background = .viewport,
            .border = .stroke_soft,
            .border_width = 1,
        });
        const image = try gui.widgets.image(ui, viewport, .{
            .texture = texture,
            .style = ui.theme.style(.{ .width = .fill, .height = .fill }),
        });

        const side_panel = try gui.widgets.column(ui, body, .{
            .width = .{ .px = side_panel_width },
            .height = .fill,
            .gap = ui.theme.space.md,
            .padding = gui.Edges.all(ui.theme.space.lg),
            .background = .panel,
            .border = .stroke_soft,
            .border_width = 1,
        });

        // The action and its status stay pinned above the scroll area: they are
        // the one part of the panel that must never be scrolled out of reach.
        const render_button = try controls.button(ui, side_panel, "Render", .{
            .height = ui.theme.metrics.control_height + 4,
            .font_size = ui.theme.font.body,
            .background = .accent,
            .foreground = .text,
            .border = .accent,
        });
        const status_label = try statusLine(ui, side_panel, .text_muted);
        const state_label = try statusLine(ui, side_panel, .warning);
        _ = try gui.widgets.divider(ui, side_panel);

        const inspector = try Inspector.init(allocator, ui, side_panel, scene);

        return .{
            .viewport = viewport,
            .image = image,
            .render_button = render_button,
            .status_label = status_label,
            .state_label = state_label,
            .fps_label = fps_label,
            .inspector = inspector,
        };
    }

    pub fn deinit(self: *Panel, ui: *gui.Ui) void {
        self.inspector.deinit(ui);
        self.* = undefined;
    }

    /// Runs a frame of input against `scene`.
    pub fn update(self: *Panel, ui: *gui.Ui, scene: *ray.Scene) !Frame {
        if (ui.input.hovered == self.render_button) {
            ui.requestCursor(.hand);
        }
        return .{
            .render_toggled = ui.clicked(self.render_button),
            .scene_edited = try self.inspector.update(ui, scene),
        };
    }

    /// Centres the traced image in the viewport at the largest whole scale that
    /// fits, leaving the aspect ratio alone.
    pub fn fitViewport(self: *Panel, ui: *gui.Ui, width: u32, height: u32) !void {
        const area = ui.bounds(self.viewport) orelse return;
        const buffer_width: f32 = @floatFromInt(width);
        const buffer_height: f32 = @floatFromInt(height);
        if (buffer_width <= 0 or buffer_height <= 0 or area.w <= 0 or area.h <= 0) {
            return;
        }

        const scale = @min(area.w / buffer_width, area.h / buffer_height);
        const drawn_width = @floor(buffer_width * scale);
        const drawn_height = @floor(buffer_height * scale);
        const fit: Fit = .{
            .width = drawn_width,
            .height = drawn_height,
            .left = @floor((area.w - drawn_width) / 2),
            .top = @floor((area.h - drawn_height) / 2),
        };
        if (std.meta.eql(fit, self.fit)) {
            return;
        }
        self.fit = fit;

        var style = ui.nodeStyle(self.image) orelse return;
        style.width = .{ .px = fit.width };
        style.height = .{ .px = fit.height };
        style.margin = .{ .left = fit.left, .top = fit.top };
        try ui.setStyle(self.image, style);
    }

    pub fn sync(self: *const Panel, ui: *gui.Ui, stats: Stats) !void {
        try ui.setText(self.render_button, if (stats.rendering)
            "Stop"
        else if (stats.last_render_ns == null)
            "Render"
        else
            "Re-render");

        var status_buf: [64]u8 = undefined;
        try ui.setText(self.status_label, if (stats.rendering)
            try std.fmt.bufPrint(&status_buf, "{d}\u{00d7}{d} \u{00b7} rendering\u{2026}", .{
                stats.width,
                stats.height,
            })
        else if (stats.last_render_ns) |ns|
            try std.fmt.bufPrint(&status_buf, "{d}\u{00d7}{d} \u{00b7} {d:.2} s{s}", .{
                stats.width,
                stats.height,
                seconds(ns),
                if (stats.canceled) " \u{00b7} stopped" else "",
            })
        else
            try std.fmt.bufPrint(&status_buf, "{d}\u{00d7}{d} \u{00b7} not rendered", .{
                stats.width,
                stats.height,
            }));

        try ui.setText(self.state_label, if (stats.edited and !stats.rendering)
            "Scene edited since last render"
        else
            "");

        var fps_buf: [32]u8 = undefined;
        try ui.setText(self.fps_label, if (stats.fps) |value|
            try std.fmt.bufPrint(&fps_buf, "{d:.0} FPS", .{value})
        else
            "");
    }
};

fn seconds(ns: i96) f64 {
    return @as(f64, @floatFromInt(ns)) / @as(f64, std.time.ns_per_s);
}

fn toolbarStat(ui: *gui.Ui, parent: gui.NodeId, width: gui.Size) !gui.NodeId {
    return gui.widgets.text(ui, parent, "", .{
        .width = width,
        .height = .fill,
        .padding = .{ .top = ui.centeredTextTop(toolbar_height, ui.theme.font.small) },
        .color = .text_muted,
        .size = ui.theme.font.small,
        .text_align = .end,
    });
}

fn statusLine(ui: *gui.Ui, parent: gui.NodeId, color: gui.ColorRole) !gui.NodeId {
    return gui.widgets.text(ui, parent, "", .{
        .width = .fill,
        .height = .{ .px = 16 },
        .color = color,
        .size = ui.theme.font.tiny,
    });
}

// Tall enough that the whole inspector fits without scrolling, so a test can
// click any control by its laid-out bounds.
const headless_window: gui.Vec2 = .{ .x = 1024, .y = 1200 };

/// Runs the panel headlessly for one frame against `scene`.
fn stepHeadless(state: *gui.Ui, panel: *Panel, scene: *ray.Scene) !Frame {
    return stepHeadlessWith(state, panel, scene, &.{});
}

fn stepHeadlessWith(
    state: *gui.Ui,
    panel: *Panel,
    scene: *ray.Scene,
    events: []const gui.PlatformEvent,
) !Frame {
    try state.beginFrame(.{
        .events = events,
        .window_size = headless_window,
        .dt = 1.0 / 60.0,
    });
    const frame = try panel.update(state, scene);
    try panel.fitViewport(state, scene.width, scene.height);
    try panel.sync(state, .{
        .fps = 60,
        .last_render_ns = null,
        .width = scene.width,
        .height = scene.height,
        .rendering = false,
        .canceled = false,
        .edited = frame.scene_edited,
    });
    try state.endFrame();
    return frame;
}

test "the panel tracks spheres appearing and disappearing under it" {
    const allocator = std.testing.allocator;

    var scene = try ray.Scene.initDefault(allocator);
    defer scene.deinit(allocator);

    var state = try gui.Ui.init(allocator);
    defer state.deinit();

    var panel = try Panel.init(allocator, &state, .none, &scene);
    defer panel.deinit(&state);

    _ = try stepHeadless(&state, &panel, &scene);
    try std.testing.expectEqual(scene.spheres.items.len, panel.inspector.entities.entities.items.len);

    try scene.add(allocator, .{ .center = .{ 2, 3, 4 }, .radius = 1.5 });
    _ = try stepHeadless(&state, &panel, &scene);
    try std.testing.expectEqual(scene.spheres.items.len, panel.inspector.entities.entities.items.len);

    scene.remove(0);
    scene.remove(0);
    _ = try stepHeadless(&state, &panel, &scene);
    try std.testing.expectEqual(scene.spheres.items.len, panel.inspector.entities.entities.items.len);

    // An empty scene still has to lay out, and the render action stays live.
    while (scene.spheres.items.len != 0) scene.remove(0);
    const frame = try stepHeadless(&state, &panel, &scene);
    try std.testing.expect(!frame.render_toggled);
    try std.testing.expectEqual(@as(usize, 0), panel.inspector.entities.entities.items.len);
}

/// The events that press whatever sits at the centre of `bounds`.
fn clickAt(bounds: gui.Rect) [3]gui.PlatformEvent {
    const point: gui.Vec2 = .{ .x = bounds.x + bounds.w / 2, .y = bounds.y + bounds.h / 2 };
    return .{ .{ .mouse_move = point }, .{ .mouse_down = .left }, .{ .mouse_up = .left } };
}

test "a sphere section opens and edits the sphere it is bound to" {
    const allocator = std.testing.allocator;

    // One sphere, so its section is certain to sit above the fold of the
    // inspector's scroll area and can be clicked.
    var scene: ray.Scene = .{};
    defer scene.deinit(allocator);
    try scene.add(allocator, .{ .material = .{ .kind = .lambertian } });

    var state = try gui.Ui.init(allocator);
    defer state.deinit();

    var panel = try Panel.init(allocator, &state, .none, &scene);
    defer panel.deinit(&state);

    for (0..2) |_| _ = try stepHeadless(&state, &panel, &scene);

    const entity = &panel.inspector.entities.entities.items[0];
    try std.testing.expect(!entity.section.isExpanded());

    const header = clickAt(state.bounds(entity.section.header_node).?);
    _ = try stepHeadlessWith(&state, &panel, &scene, &header);
    try std.testing.expect(entity.section.isExpanded());

    // Settle the disclosure animation so the body has its real geometry.
    for (0..20) |_| _ = try stepHeadless(&state, &panel, &scene);

    const body = state.bounds(entity.section.body()).?;
    const panel_bounds = state.bounds(panel.inspector.root).?;
    try std.testing.expect(body.h > 0);
    try std.testing.expect(body.w <= panel_bounds.w);

    const glass = @intFromEnum(ray.MaterialKind.dielectric);
    const segment = clickAt(state.bounds(entity.kind.buttons[glass]).?);
    const frame = try stepHeadlessWith(&state, &panel, &scene, &segment);
    try std.testing.expect(frame.scene_edited);
    try std.testing.expectEqual(ray.MaterialKind.dielectric, scene.spheres.items[0].material.kind);
}

test "the viewport letterboxes the image without distorting it" {
    const allocator = std.testing.allocator;

    var scene = try ray.Scene.initDefault(allocator);
    defer scene.deinit(allocator);

    var state = try gui.Ui.init(allocator);
    defer state.deinit();

    var panel = try Panel.init(allocator, &state, .none, &scene);
    defer panel.deinit(&state);

    // The first frame establishes the viewport's bounds; the second is the one
    // that can fit an image to them.
    _ = try stepHeadless(&state, &panel, &scene);
    _ = try stepHeadless(&state, &panel, &scene);

    const area = state.bounds(panel.viewport).?;
    try std.testing.expect(panel.fit.width > 0 and panel.fit.height > 0);
    try std.testing.expect(panel.fit.width <= area.w and panel.fit.height <= area.h);

    const scene_aspect = @as(f32, @floatFromInt(scene.width)) / @as(f32, @floatFromInt(scene.height));
    const fit_aspect = panel.fit.width / panel.fit.height;
    try std.testing.expectApproxEqAbs(scene_aspect, fit_aspect, 0.01);
}
