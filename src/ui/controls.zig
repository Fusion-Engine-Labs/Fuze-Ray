const gui = @import("zGUI");
const std = @import("std");
const ray = @import("ray");

const v = ray.vector;

pub const label_width: f32 = 68;

const axis_names = [_][]const u8{ "X", "Y", "Z" };

pub fn row(ui: *gui.Ui, parent: gui.NodeId, name: []const u8) !gui.NodeId {
    const container = try gui.widgets.row(ui, parent, .{
        .width = .fill,
        .height = .hug,
        .gap = ui.theme.space.sm,
    });
    errdefer ui.destroySubtree(container);

    _ = try gui.widgets.text(ui, container, name, .{
        .width = .{ .px = label_width },
        .height = .{ .px = ui.theme.metrics.control_height },
        .padding = .{ .top = ui.centeredTextTop(ui.theme.metrics.control_height, ui.theme.font.small) },
        .color = .text_muted,
        .size = ui.theme.font.small,
    });
    return container;
}

pub const Scalar = struct {
    field: gui.NumericField,
    options: gui.NumericOptions,

    pub fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        value: f64,
        options: gui.NumericOptions,
    ) !Scalar {
        return .{
            .field = try gui.NumericField.initF32(allocator, ui, parent, @floatCast(value), options),
            .options = options,
        };
    }

    pub fn deinit(self: *Scalar, ui: *gui.Ui) void {
        self.field.deinit(ui);
        self.* = undefined;
    }

    pub fn update(self: *Scalar, ui: *gui.Ui, value: *f64) !bool {
        const before: f32 = @floatCast(value.*);
        var edited = before;
        const result = try self.field.updateF32(ui, &edited, self.options);
        if (!result.committed or edited == before) {
            return false;
        }
        value.* = edited;
        return true;
    }
};

/// One `u32` of the scene bound to a numeric field, for counts and sizes that
/// have no meaningful fractional part.
pub const Count = struct {
    field: gui.NumericField,
    options: gui.NumericOptions,

    pub fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        value: u32,
        options: gui.NumericOptions,
    ) !Count {
        return .{
            .field = try gui.NumericField.initU32(allocator, ui, parent, value, options),
            .options = options,
        };
    }

    pub fn deinit(self: *Count, ui: *gui.Ui) void {
        self.field.deinit(ui);
        self.* = undefined;
    }

    pub fn update(self: *Count, ui: *gui.Ui, value: *u32) !bool {
        const before = value.*;
        var edited = before;
        const result = try self.field.updateU32(ui, &edited, self.options);
        if (!result.committed or edited == before) {
            return false;
        }
        value.* = edited;
        return true;
    }
};

/// Three numeric fields sharing a row, each labelled with its axis.
pub const Vector = struct {
    axes: [axis_names.len]gui.NumericField,
    options: gui.NumericOptions,

    pub fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        value: v.Vec3,
        options: gui.NumericOptions,
    ) !Vector {
        const components: [axis_names.len]f64 = value;
        var axes: [axis_names.len]gui.NumericField = undefined;
        var built: usize = 0;
        errdefer for (axes[0..built]) |*axis| axis.deinit(ui);

        while (built < axes.len) : (built += 1) {
            axes[built] = try gui.NumericField.initF32(
                allocator,
                ui,
                parent,
                @floatCast(components[built]),
                axisOptions(options, built),
            );
        }
        return .{ .axes = axes, .options = options };
    }

    pub fn deinit(self: *Vector, ui: *gui.Ui) void {
        for (&self.axes) |*axis| axis.deinit(ui);
        self.* = undefined;
    }

    pub fn update(self: *Vector, ui: *gui.Ui, value: *v.Vec3) !bool {
        // A `@Vector` cannot be indexed at runtime, so the axes are driven
        // through the array it coerces to and written back only once.
        var components: [axis_names.len]f64 = value.*;
        var changed = false;
        for (&self.axes, &components, 0..) |*axis, *component, index| {
            const before: f32 = @floatCast(component.*);
            var edited = before;
            const result = try axis.updateF32(ui, &edited, axisOptions(self.options, index));
            if (!result.committed or edited == before) {
                continue;
            }
            component.* = edited;
            changed = true;
        }
        if (changed) {
            value.* = components;
        }
        return changed;
    }

    fn axisOptions(options: gui.NumericOptions, index: usize) gui.NumericOptions {
        var next = options;
        next.trailing_label = axis_names[index];
        return next;
    }
};

/// A linear scene colour bound to a swatch picker. The picker speaks 8-bit
/// sRGB, so the gamma encoding the image pipeline already defines is reused
/// here instead of being restated; the round trip is exact, which is what lets
/// the swatch be derived from the scene every frame rather than mirrored.
pub const Color = struct {
    picker: gui.ColorPicker,

    pub fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        value: v.Color,
    ) !Color {
        return .{
            .picker = try gui.ColorPicker.init(allocator, ui, parent, toGui(value), .{
                .width = 56,
                .height = ui.theme.metrics.control_height,
            }),
        };
    }

    pub fn deinit(self: *Color, ui: *gui.Ui) void {
        self.picker.deinit(ui);
        self.* = undefined;
    }

    pub fn update(self: *Color, ui: *gui.Ui, value: *v.Color) !bool {
        var picked = toGui(value.*);
        if (!try self.picker.update(ui, &picked)) {
            return false;
        }
        value.* = fromGui(picked);
        return true;
    }

    fn toGui(color: v.Color) gui.Color {
        const encoded = ray.Rgba.fromColor(color);
        return .rgba(encoded.r, encoded.g, encoded.b, 255);
    }

    fn fromGui(color: gui.Color) v.Color {
        const encoded: ray.Rgba = .{ .r = color.r, .g = color.g, .b = color.b };
        return encoded.toColor();
    }
};

/// A one-of-N picker drawn as a row of joined buttons.
pub const Segmented = struct {
    allocator: std.mem.Allocator,
    root: gui.NodeId,
    buttons: []gui.NodeId,

    pub fn init(
        allocator: std.mem.Allocator,
        ui: *gui.Ui,
        parent: gui.NodeId,
        labels: []const []const u8,
    ) !Segmented {
        const root = try gui.widgets.row(ui, parent, .{
            .width = .fill,
            .height = .{ .px = ui.theme.metrics.control_height },
            .gap = ui.theme.space.xxs,
        });
        errdefer ui.destroySubtree(root);

        const buttons = try allocator.alloc(gui.NodeId, labels.len);
        errdefer allocator.free(buttons);

        for (labels, buttons) |label, *segment| {
            segment.* = try gui.widgets.button(ui, root, label, segmentStyle(ui, false));
        }
        return .{ .allocator = allocator, .root = root, .buttons = buttons };
    }

    pub fn deinit(self: *Segmented, ui: *gui.Ui) void {
        ui.destroySubtree(self.root);
        self.allocator.free(self.buttons);
        self.* = undefined;
    }

    /// Returns the index the user picked this frame, or null when the
    /// selection is unchanged.
    pub fn update(self: *Segmented, ui: *gui.Ui, selected: usize) !?usize {
        var picked: ?usize = null;
        for (self.buttons, 0..) |segment, index| {
            if (ui.input.hovered == segment) {
                ui.requestCursor(.hand);
            }
            if (ui.clicked(segment) and index != selected) {
                picked = index;
            }
        }

        // Paint the choice the caller will see next frame, so the press reads
        // as immediate even though the scene has not been rewritten yet.
        const shown = picked orelse selected;
        for (self.buttons, 0..) |segment, index| {
            const next = segmentStyle(ui, index == shown);
            const current = ui.nodeStyle(segment) orelse continue;
            if (!std.meta.eql(current, next)) {
                try ui.setStyle(segment, next);
            }
        }
        return picked;
    }

    fn segmentStyle(ui: *const gui.Ui, selected: bool) gui.Style {
        const height = ui.theme.metrics.control_height;
        return ui.theme.style(.{
            .width = .fill,
            .height = .fill,
            .padding = .{ .top = ui.centeredTextTop(height, ui.theme.font.small) },
            .background = if (selected) .accent_soft else .control,
            .foreground = if (selected) .text else .text_muted,
            .hover_background = .interaction_hover,
            .pressed_background = .accent_pressed,
            .border = if (selected) .accent_border else .stroke,
            .border_width = 1,
            .radius = .control,
            .font_size = ui.theme.font.small,
            .text_align = .center,
        });
    }
};

/// A full-width button with a centred label. `themedButton` leaves its text
/// left-aligned, which only reads well when the button hugs its content.
pub fn button(
    ui: *gui.Ui,
    parent: gui.NodeId,
    text: []const u8,
    options: ButtonOptions,
) !gui.NodeId {
    const height = options.height;
    return gui.widgets.button(ui, parent, text, ui.theme.style(.{
        .width = .fill,
        .height = .{ .px = height },
        .padding = .{ .top = ui.centeredTextTop(height, options.font_size) },
        .background = options.background,
        .foreground = options.foreground,
        .hover_background = .interaction_hover,
        .pressed_background = .accent_pressed,
        .border = options.border,
        .border_width = 1,
        .radius = .control,
        .font_size = options.font_size,
        .text_align = .center,
    }));
}

pub const ButtonOptions = struct {
    height: f32,
    font_size: f32,
    background: gui.ColorRole = .control,
    foreground: gui.ColorRole = .text_dim,
    border: gui.ColorRole = .stroke,
};
