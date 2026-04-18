const std = @import("std");
const rl = @import("raylib");
const game = @import("game.zig");
const config = @import("config.zig");
const rodent = @import("rodent.zig");

const Object = game.Object;
const Position = game.Position;
const Move = game.Move;
const Board = game.Board;

const BS: i32 = config.board_size;

const cats_possible_moves = [_]Move{
    .{ .row = 0, .column = -1 },
    .{ .row = 0, .column = 1 },
    .{ .row = -1, .column = -1 },
    .{ .row = -1, .column = 0 },
    .{ .row = -1, .column = 1 },
    .{ .row = 1, .column = -1 },
    .{ .row = 1, .column = 0 },
    .{ .row = 1, .column = 1 },
};

pub fn updateCats(b: *Board) void {
    const max_cats = @as(usize, @intCast(BS)) * @as(usize, @intCast(BS));
    var cats_buf: [max_cats]Position = undefined;

    var count = findAllCats(b, &cats_buf);
    if (count == 0 and b.remaining_waves > 0) {
        b.remaining_waves -= 1;
        respawnCats(b);
        count = findAllCats(b, &cats_buf);
    }

    transformTrappedCatsToCheese(b, cats_buf[0..count]);
    moveCats(b);
}

fn moveCats(b: *Board) void {
    const max_cats = @as(usize, @intCast(BS)) * @as(usize, @intCast(BS));
    var cats_buf: [max_cats]Position = undefined;
    const count = findAllCats(b, &cats_buf);
    for (cats_buf[0..count]) |c| {
        moveCat(b, c);
    }
}

fn transformTrappedCatsToCheese(b: *Board, cats: []const Position) void {
    if (cats.len == 0) return;
    for (cats) |c| {
        if (b.at(c) != .cat_resting) return;
    }
    for (cats) |c| b.set(c, .cheese);
}

fn moveCat(b: *Board, cat: Position) void {
    const rod = rodent.findRodent(b);
    const another = rodent.findAnotherRodent(b);

    const best_to_rod: ?Position = if (rod) |r| aStar(b, cat, r) else null;
    const best_to_another: ?Position = if (another) |r| aStar(b, cat, r) else null;

    if (best_to_rod != null and best_to_another == null) {
        const dest = best_to_rod.?;
        const here_obj = b.at(dest);
        if (here_obj == .rodent or here_obj == .rodent_sinkhole) {
            b.rodent_death.append(b.allocator, dest) catch {};
        }
        b.set(dest, .cat);
        b.set(cat, .empty);
        return;
    }

    if (best_to_rod == null and best_to_another != null) {
        const dest = best_to_another.?;
        const here_obj = b.at(dest);
        if (here_obj == .another_rodent or here_obj == .another_rodent_sinkhole) {
            b.rodent_death.append(b.allocator, dest) catch {};
        }
        b.set(dest, .cat);
        b.set(cat, .empty);
        return;
    }

    if (best_to_rod != null and best_to_another != null) {
        const d_rod = Board.distance(best_to_rod.?, rod.?);
        const d_another = Board.distance(best_to_another.?, another.?);
        const dest = if (d_rod <= d_another) best_to_rod.? else best_to_another.?;
        b.set(dest, .cat);
        b.set(cat, .empty);
        return;
    }

    var moves_buf: [8]Move = undefined;
    const moves = getPossibleMoves(b, cat, &moves_buf);

    var best: ?Position = null;
    if (rod != null and another != null) {
        if (Board.distance(cat, rod.?) <= Board.distance(cat, another.?)) {
            best = minimizeDistance(b, cat, rod.?, moves);
        } else {
            best = minimizeDistance(b, cat, another.?, moves);
        }
    } else if (rod) |r| {
        best = minimizeDistance(b, cat, r, moves);
    } else if (another) |r| {
        best = minimizeDistance(b, cat, r, moves);
    }

    if (best) |dest| {
        b.set(dest, .cat);
        b.set(cat, .empty);
        return;
    }

    if (moves.len > 0) {
        const dest = cat.after(moves[0]);
        b.set(dest, .cat);
        b.set(cat, .empty);
        return;
    }

    b.set(cat, .cat_resting);
}

fn getPossibleMoves(b: *const Board, cat: Position, out: *[8]Move) []Move {
    var n: usize = 0;
    for (cats_possible_moves) |d| {
        const next = cat.after(d);
        if (isWalkable(b, next)) {
            out[n] = d;
            n += 1;
        }
    }
    return out[0..n];
}

fn minimizeDistance(b: *const Board, cat: Position, rod: Position, moves: []const Move) ?Position {
    var best: ?Position = null;
    var min_dist: f64 = std.math.floatMax(f64);
    for (moves) |m| {
        const cand = cat.after(m);
        const d = Board.distance(cand, rod);
        if (d < min_dist and isWalkable(b, cand)) {
            min_dist = d;
            best = cand;
        }
    }
    return best;
}

pub fn isWalkable(b: *const Board, p: Position) bool {
    if (!Board.inBounds(p)) return false;
    const o = b.at(p);
    return o == .empty or o == .rodent or o == .another_rodent or o == .rodent_sinkhole or o == .another_rodent_sinkhole;
}

fn aStar(b: *const Board, cat: Position, target: Position) ?Position {
    const N: usize = @intCast(BS);
    var g_score: [23][23]i32 = undefined;
    var in_open: [23][23]bool = undefined;
    var closed: [23][23]bool = undefined;
    var parent: [23][23]Position = undefined;

    for (0..N) |i| {
        for (0..N) |j| {
            g_score[i][j] = 0;
            in_open[i][j] = false;
            closed[i][j] = false;
            parent[i][j] = .{ .row = -1, .column = -1 };
        }
    }

    in_open[@intCast(cat.row)][@intCast(cat.column)] = true;
    g_score[@intCast(cat.row)][@intCast(cat.column)] = 0;

    while (true) {
        var current: ?Position = null;
        var best_f: i32 = std.math.maxInt(i32);
        var ri: i32 = 0;
        while (ri < BS) : (ri += 1) {
            var ci: i32 = 0;
            while (ci < BS) : (ci += 1) {
                if (!in_open[@intCast(ri)][@intCast(ci)]) continue;
                const pos: Position = .{ .row = ri, .column = ci };
                const f = g_score[@intCast(ri)][@intCast(ci)] + heuristic(pos, target);
                if (f < best_f) {
                    best_f = f;
                    current = pos;
                }
            }
        }

        const cur = current orelse return null;
        in_open[@intCast(cur.row)][@intCast(cur.column)] = false;
        closed[@intCast(cur.row)][@intCast(cur.column)] = true;

        if (cur.eql(target)) {
            var step = cur;
            while (!parent[@intCast(step.row)][@intCast(step.column)].eql(cat)) {
                step = parent[@intCast(step.row)][@intCast(step.column)];
                if (step.row == -1) return null;
            }
            return step;
        }

        for (cats_possible_moves) |d| {
            const nb = cur.after(d);
            if (!Board.inBounds(nb)) continue;
            if (closed[@intCast(nb.row)][@intCast(nb.column)]) continue;
            if (!nb.eql(target) and !isWalkable(b, nb)) continue;

            const tentative = g_score[@intCast(cur.row)][@intCast(cur.column)] + 1;
            const open_here = in_open[@intCast(nb.row)][@intCast(nb.column)];
            if (!open_here or tentative < g_score[@intCast(nb.row)][@intCast(nb.column)]) {
                g_score[@intCast(nb.row)][@intCast(nb.column)] = tentative;
                parent[@intCast(nb.row)][@intCast(nb.column)] = cur;
                in_open[@intCast(nb.row)][@intCast(nb.column)] = true;
            }
        }
    }
}

fn heuristic(a: Position, b: Position) i32 {
    const dr = @abs(a.row - b.row);
    const dc = @abs(a.column - b.column);
    return @intCast(@max(dr, dc));
}

pub fn findAllCats(b: *const Board, out: []Position) usize {
    var n: usize = 0;
    var i: i32 = 0;
    while (i < BS) : (i += 1) {
        var j: i32 = 0;
        while (j < BS) : (j += 1) {
            const p: Position = .{ .row = i, .column = j };
            const o = b.at(p);
            if (o == .cat or o == .cat_resting) {
                out[n] = p;
                n += 1;
            }
        }
    }
    return n;
}

fn respawnCats(b: *Board) void {
    while (true) {
        const r = rl.getRandomValue(1, BS - 2);
        const c = rl.getRandomValue(1, BS - 2);
        const p: Position = .{ .row = r, .column = c };

        const rod = rodent.findRodent(b);
        const another = rodent.findAnotherRodent(b);

        const far_from_rod = rod == null or Board.distance(p, rod.?) > 5;
        const far_from_another = another == null or Board.distance(p, another.?) > 5;

        if (b.at(p) == .empty and far_from_rod and far_from_another) {
            b.set(p, .cat);
            return;
        }
    }
}
