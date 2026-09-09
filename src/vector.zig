const std = @import("std");

pub const Vec3 = @Vector(3, f64);

pub const Fmt = std.fmt.Alt(Vec3, format);
fn format(v: Vec3, w: *std.Io.Writer) !void {
    try w.print("{d} {d} {d}", .{ v[0], v[1], v[2] });
}

pub const Point = Vec3;
pub const Color = Vec3;

pub const zero: Vec3 = .{ 0, 0, 0 };
pub const one: Vec3 = .{ 1, 1, 1 };

pub fn x(v: Vec3) f64 {
    return v[0];
}
pub fn y(v: Vec3) f64 {
    return v[1];
}
pub fn z(v: Vec3) f64 {
    return v[2];
}

pub fn magnitude(v: Vec3) f64 {
    return @sqrt(full_magnitude(v));
}

pub fn full_magnitude(v: Vec3) f64 {
    return @reduce(.Add, v * v);
}

pub fn splat(n: anytype) Vec3 {
    switch (@TypeOf(n)) {
        usize, comptime_int => return @splat(@floatFromInt(n)),
        f64, comptime_float => return @splat(n),
        else => unreachable,
    }
}

pub fn reflect(v: Vec3, normal: Vec3) Vec3 {
    return v - splat(2 * dot(v, normal)) * normal;
}

pub fn refract(v: Vec3, normal: Vec3, refraction_ratio: f64) Vec3 {
    const cos_theta = @min(dot(-v, normal), 1.0);
    const r_out_perp = splat(refraction_ratio) * (v + splat(cos_theta) * normal);
    const r_out_parallel = splat(-@sqrt(@abs(1 - full_magnitude(r_out_perp)))) *
        normal;

    return r_out_perp + r_out_parallel;
}

pub fn toGamma(color: f64) f64 {
    return if (color > 0) @sqrt(color) else 0;
}

pub fn dot(lhs: Vec3, rhs: Vec3) f64 {
    return @reduce(.Add, lhs * rhs);
}

pub fn cross(lhs: Vec3, rhs: Vec3) Vec3 {
    return .{
        lhs[1] * rhs[2] - lhs[2] * rhs[1],
        lhs[2] * rhs[0] - lhs[0] * rhs[2],
        lhs[0] * rhs[1] - lhs[1] * rhs[0],
    };
}

pub fn unit(v: Vec3) Vec3 {
    const mag = magnitude(v);
    if (mag == 0) {
        return zero;
    }

    const mag3: Vec3 = @splat(mag);
    return v / mag3;
}

pub fn nearZero(v: Vec3) bool {
    const s = 1e-8;
    return @reduce(.And, @abs(v) < splat(s));
}

pub fn random(r: std.Random) Vec3 {
    return .{ r.float(f64), r.float(f64), r.float(f64) };
}

pub fn randomRange(r: std.Random, min: f64, max: f64) Vec3 {
    return .{
        r.float(f64) * (max - min) + min,
        r.float(f64) * (max - min) + min,
        r.float(f64) * (max - min) + min,
    };
}

pub fn randomUnit(r: std.Random) Vec3 {
    while (true) {
        const v = randomRange(r, -1, 1);
        const m2 = full_magnitude(v);
        if (std.math.floatEpsAt(f64, 0) < m2 and m2 <= 1) {
            return v / @sqrt(splat(m2));
        }
    }
}

pub fn randomHemisphere(r: std.Random, normal: Vec3) Vec3 {
    const v = randomUnit(r);
    if (dot(v, normal) > 0) {
        return v;
    } else {
        return -v;
    }
}

pub fn randomUnitDisk(r: std.Random) Vec3 {
    while (true) {
        const p: Vec3 = .{ r.float(f64) * 2 - 1, r.float(f64) * 2 - 1, 0 };
        if (full_magnitude(p) < 1) {
            return p;
        }
    }
}
