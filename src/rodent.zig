const std = @import("std");
const rl = @import("raylib");
const game = @import("game.zig");
const config = @import("config.zig");

const Object = game.Object;
const Position = game.Position;
const Move = game.Move;
const Game = game.Game;
const Board = game.Board;

const KeyMove = struct { key: rl.KeyboardKey, move: Move };

const rodent_keys = [_]KeyMove{
    .{ .key = .up, .move = .{ .row = -1, .column = 0 } },
    .{ .key = .kp_8, .move = .{ .row = -1, .column = 0 } },
    .{ .key = .down, .move = .{ .row = 1, .column = 0 } },
    .{ .key = .kp_2, .move = .{ .row = 1, .column = 0 } },
    .{ .key = .left, .move = .{ .row = 0, .column = -1 } },
    .{ .key = .kp_4, .move = .{ .row = 0, .column = -1 } },
    .{ .key = .right, .move = .{ .row = 0, .column = 1 } },
    .{ .key = .kp_6, .move = .{ .row = 0, .column = 1 } },
    .{ .key = .kp_7, .move = .{ .row = -1, .column = -1 } },
    .{ .key = .kp_9, .move = .{ .row = -1, .column = 1 } },
    .{ .key = .kp_1, .move = .{ .row = 1, .column = -1 } },
    .{ .key = .kp_3, .move = .{ .row = 1, .column = 1 } },
};

const another_rodent_keys = [_]KeyMove{
    .{ .key = .w, .move = .{ .row = -1, .column = 0 } },
    .{ .key = .s, .move = .{ .row = 1, .column = 0 } },
    .{ .key = .a, .move = .{ .row = 0, .column = -1 } },
    .{ .key = .d, .move = .{ .row = 0, .column = 1 } },
    .{ .key = .q, .move = .{ .row = -1, .column = -1 } },
    .{ .key = .e, .move = .{ .row = -1, .column = 1 } },
    .{ .key = .z, .move = .{ .row = 1, .column = -1 } },
    .{ .key = .c, .move = .{ .row = 1, .column = 1 } },
};

pub fn moveRodent(g: *Game) void {
    var m: Move = .{ .row = 0, .column = 0 };
    for (rodent_keys) |km| {
        if (rl.isKeyPressed(km.key)) m = m.compose(km.move);
    }
    if (!m.isZero()) {
        if (findRodent(&g.board)) |p| _ = move(g, p, m);
    }

    m = .{ .row = 0, .column = 0 };
    for (another_rodent_keys) |km| {
        if (rl.isKeyPressed(km.key)) m = m.compose(km.move);
    }
    if (!m.isZero()) {
        if (findAnotherRodent(&g.board)) |p| _ = move(g, p, m);
    }
}

pub fn findRodent(b: *const Board) ?Position {
    var i: i32 = 0;
    while (i < config.board_size) : (i += 1) {
        var j: i32 = 0;
        while (j < config.board_size) : (j += 1) {
            const p: Position = .{ .row = i, .column = j };
            const o = b.at(p);
            if (o == .rodent or o == .rodent_sinkhole) return p;
        }
    }
    return null;
}

pub fn findAnotherRodent(b: *const Board) ?Position {
    var i: i32 = 0;
    while (i < config.board_size) : (i += 1) {
        var j: i32 = 0;
        while (j < config.board_size) : (j += 1) {
            const p: Position = .{ .row = i, .column = j };
            const o = b.at(p);
            if (o == .another_rodent or o == .another_rodent_sinkhole) return p;
        }
    }
    return null;
}

pub fn respawnRodent(g: *Game) void {
    while (true) {
        const r = rl.getRandomValue(1, config.board_size - 2);
        const c = rl.getRandomValue(1, config.board_size - 2);
        const p: Position = .{ .row = r, .column = c };
        if (g.board.at(p) == .empty) {
            g.board.set(p, .rodent);
            return;
        }
    }
}

pub fn respawnAnotherRodent(g: *Game) void {
    while (true) {
        const r = rl.getRandomValue(1, config.board_size - 2);
        const c = rl.getRandomValue(1, config.board_size - 2);
        const p: Position = .{ .row = r, .column = c };
        if (g.board.at(p) == .empty) {
            g.board.set(p, .another_rodent);
            return;
        }
    }
}

pub fn move(g: *Game, position: Position, m: Move) bool {
    const next = position.after(m);
    if (!Board.inBounds(next)) return false;

    const b = &g.board;
    const here = b.at(position);
    const there = b.at(next);

    if ((here == .rodent or here == .another_rodent) and there == .cat) {
        b.set(position, .empty);
        return true;
    }

    if (here == .rodent and there == .cheese) {
        b.set(position, .empty);
        b.set(next, .rodent);
        g.points += config.cheese_points;
        return true;
    }

    if (here == .another_rodent and there == .cheese) {
        b.set(position, .empty);
        b.set(next, .another_rodent);
        g.points += config.cheese_points;
        return true;
    }

    if ((here == .rodent or here == .another_rodent) and there == .trap) {
        b.set(position, .empty);
        b.set(next, .empty);
        b.rodent_death.append(b.allocator, next) catch {};
        return false;
    }

    if (here == .rodent and there == .sinkhole) {
        b.set(position, .empty);
        b.set(next, .rodent_sinkhole);
        b.rodent_sinkhole_since_s = rl.getTime();
        return false;
    }

    if (here == .another_rodent and there == .sinkhole) {
        b.set(position, .empty);
        b.set(next, .another_rodent_sinkhole);
        b.another_rodent_sinkhole_since_s = rl.getTime();
        return false;
    }

    if (here == .rodent_sinkhole) {
        if (rl.getTime() - b.rodent_sinkhole_since_s >= config.sinkhole_duration_s) {
            b.set(position, .rodent);
        }
        return false;
    }

    if (here == .another_rodent_sinkhole) {
        if (rl.getTime() - b.another_rodent_sinkhole_since_s >= config.sinkhole_duration_s) {
            b.set(position, .another_rodent);
        }
        return false;
    }

    if (here == .obstacle and there == .sinkhole) return true;
    if (here == .obstacle and there == .trap) return false;
    if (here == .cat and there == .sinkhole) return false;
    if (there == .wall) return false;

    if (there == .empty or there == .cheese) {
        b.set(next, here);
        b.set(position, .empty);
        return true;
    }

    if (move(g, next, m)) {
        b.set(next, here);
        b.set(position, .empty);
        return true;
    }

    return false;
}
