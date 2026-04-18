const std = @import("std");
const rl = @import("raylib");
const config = @import("config.zig");

pub const Object = enum(u8) {
    empty,
    rodent,
    another_rodent,
    rodent_sinkhole,
    another_rodent_sinkhole,
    obstacle,
    wall,
    cat,
    cat_resting,
    cheese,
    sinkhole,
    trap,
};

pub const Position = struct {
    row: i32,
    column: i32,

    pub fn eql(self: Position, other: Position) bool {
        return self.row == other.row and self.column == other.column;
    }

    pub fn after(self: Position, m: Move) Position {
        return .{ .row = self.row + m.row, .column = self.column + m.column };
    }
};

pub const Move = struct {
    row: i32,
    column: i32,

    pub fn compose(self: Move, other: Move) Move {
        return .{ .row = self.row + other.row, .column = self.column + other.column };
    }

    pub fn isZero(self: Move) bool {
        return self.row == 0 and self.column == 0;
    }
};

pub const GameSpeed = enum(u8) {
    snail,
    slow,
    medium,
    fast,
    blazing,

    pub fn name(self: GameSpeed) [:0]const u8 {
        return switch (self) {
            .snail => "Snail",
            .slow => "Slow",
            .medium => "Medium",
            .fast => "Fast",
            .blazing => "Blazing",
        };
    }

    pub fn updateIntervalS(self: GameSpeed) f64 {
        return switch (self) {
            .snail => 2.0,
            .slow => 1.0,
            .medium => 0.75,
            .fast => 0.5,
            .blazing => 0.25,
        };
    }

    pub fn faster(self: GameSpeed) GameSpeed {
        const v = @intFromEnum(self);
        const max = @intFromEnum(GameSpeed.blazing);
        return if (v < max) @enumFromInt(v + 1) else self;
    }

    pub fn slower(self: GameSpeed) GameSpeed {
        const v = @intFromEnum(self);
        return if (v > 0) @enumFromInt(v - 1) else self;
    }
};

pub const GameState = enum { playing, pause, game_over, win };

pub const GameType = enum { single_player, cooperative };

pub const Board = struct {
    objects: [config.board_size][config.board_size]Object,
    last_cat_update_s: f64,
    rodent_sinkhole_since_s: f64,
    another_rodent_sinkhole_since_s: f64,
    remaining_waves: u8,
    rodent_death: std.ArrayList(Position),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, game_type: GameType, customization: LevelFn) Board {
        var board: Board = .{
            .objects = undefined,
            .last_cat_update_s = rl.getTime(),
            .rodent_sinkhole_since_s = 0,
            .another_rodent_sinkhole_since_s = 0,
            .remaining_waves = 4,
            .rodent_death = .empty,
            .allocator = allocator,
        };

        const n = config.board_size;
        var i: i32 = 0;
        while (i < n) : (i += 1) {
            var j: i32 = 0;
            while (j < n) : (j += 1) {
                const p: Position = .{ .row = i, .column = j };
                const obj: Object = blk: {
                    if (i == 0 or i == n - 1 or j == 0 or j == n - 1) break :blk .wall;
                    if (game_type == .single_player and i == 11 and j == 11) break :blk .rodent;
                    if (game_type == .cooperative and i == 11 and j == 10) break :blk .rodent;
                    if (game_type == .cooperative and i == 11 and j == 12) break :blk .another_rodent;
                    break :blk customization(p);
                };
                board.objects[@intCast(i)][@intCast(j)] = obj;
            }
        }

        return board;
    }

    pub fn deinit(self: *Board) void {
        self.rodent_death.deinit(self.allocator);
    }

    pub fn at(self: *const Board, p: Position) Object {
        return self.objects[@intCast(p.row)][@intCast(p.column)];
    }

    pub fn set(self: *Board, p: Position, obj: Object) void {
        self.objects[@intCast(p.row)][@intCast(p.column)] = obj;
    }

    pub fn inBounds(p: Position) bool {
        return p.row >= 0 and p.row < config.board_size and p.column >= 0 and p.column < config.board_size;
    }

    pub fn distance(first: Position, second: Position) f64 {
        const dr: f64 = @floatFromInt(@abs(first.row - second.row));
        const dc: f64 = @floatFromInt(@abs(first.column - second.column));
        return dr + dc;
    }
};

pub const Game = struct {
    board: Board,
    state: GameState,
    game_type: GameType,
    points: u32,
    remaining_lives: u8,
    current_level: u8,
    speed: GameSpeed,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, game_type: GameType) Game {
        return .{
            .board = Board.init(allocator, game_type, levels[0]),
            .state = .playing,
            .game_type = game_type,
            .points = 0,
            .remaining_lives = 2,
            .current_level = 0,
            .speed = .slow,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Game) void {
        self.board.deinit();
    }

    pub fn nextLevel(self: *Game) void {
        const next = self.current_level + 1;
        if (next >= levels.len) {
            self.state = .win;
            return;
        }
        self.current_level = next;
        self.board.deinit();
        self.board = Board.init(self.allocator, self.game_type, levels[self.current_level]);
    }

    pub fn previousLevel(self: *Game) void {
        if (self.current_level == 0) return;
        self.current_level -= 1;
        self.state = .playing;
        self.board.deinit();
        self.board = Board.init(self.allocator, self.game_type, levels[self.current_level]);
    }
};

pub const LevelFn = *const fn (Position) Object;

fn level0(p: Position) Object {
    if (p.row >= 4 and p.row <= 18 and p.column >= 4 and p.column <= 18) return .obstacle;
    return .empty;
}

fn level1(p: Position) Object {
    if (rl.getRandomValue(0, 100) < 5) return .wall;
    if (p.row >= 4 and p.row <= 18 and p.column >= 4 and p.column <= 18) return .obstacle;
    return .empty;
}

fn level2(_: Position) Object {
    if (rl.getRandomValue(0, 100) < 5) return .wall;
    if (rl.getRandomValue(0, 100) < 45) return .obstacle;
    return .empty;
}

fn level3(p: Position) Object {
    if (p.row > 1 and p.row < 21 and p.column > 1 and p.column < 21) {
        if (rl.getRandomValue(0, 100) < 2) return .sinkhole;
        if ((@mod(p.row, 2) == 1 and @mod(p.column, 2) == 0) or
            (@mod(p.row, 2) == 0 and @mod(p.column, 2) == 1)) return .obstacle;
    }
    return .empty;
}

fn level4(_: Position) Object {
    if (rl.getRandomValue(0, 100) < 5) return .wall;
    if (rl.getRandomValue(0, 100) < 5) return .sinkhole;
    if (rl.getRandomValue(0, 100) < 45) return .obstacle;
    return .empty;
}

fn level5(p: Position) Object {
    if (p.row > 3 and p.row < 19 and p.column > 3 and p.column < 19) {
        if ((@mod(p.row, 2) == 1 and @mod(p.column, 2) == 0) or
            (@mod(p.row, 2) == 0 and @mod(p.column, 2) == 1)) return .wall;
    }
    if (rl.getRandomValue(0, 100) < 5) return .sinkhole;
    if (rl.getRandomValue(0, 100) < 25) return .obstacle;
    return .empty;
}

fn level6(p: Position) Object {
    if (rl.getRandomValue(0, 100) < 5) return .sinkhole;
    if (p.row >= 4 and p.row <= 18 and p.column >= 4 and p.column <= 18) return .obstacle;
    if (rl.getRandomValue(0, 100) == 0) return .trap;
    return .empty;
}

pub const levels: []const LevelFn = &.{ level0, level1, level2, level3, level4, level5, level6 };
