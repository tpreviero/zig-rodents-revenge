const std = @import("std");
const rl = @import("raylib");
const game = @import("game.zig");
const config = @import("config.zig");
const rodent = @import("rodent.zig");
const cat = @import("cat.zig");
const ui_mod = @import("ui.zig");

const Game = game.Game;
const UI = ui_mod.UI;
const Position = game.Position;

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var ui = try UI.init();
    defer UI.close();

    var g = Game.init(allocator, .single_player);
    defer g.deinit();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.ray_white);

        if (rl.isKeyDown(.right_shift) and rl.isKeyPressed(.slash)) {
            ui.show_help = !ui.show_help;
        }

        update(&g);
        ui.draw(&g);
    }
}

fn update(g: *Game) void {
    if (rl.isKeyPressed(.p)) {
        g.state = if (g.state == .pause) .playing else .pause;
    }

    if (rl.isKeyDown(.right_shift)) {
        if (rl.isKeyPressed(.right)) {
            g.nextLevel();
            return;
        }
        if (rl.isKeyPressed(.left)) {
            g.previousLevel();
            return;
        }
        if (rl.isKeyPressed(.up)) {
            g.speed = g.speed.faster();
            return;
        }
        if (rl.isKeyPressed(.down)) {
            g.speed = g.speed.slower();
            return;
        }
        if (rl.isKeyPressed(.m)) {
            if (g.game_type == .single_player) {
                g.remaining_lives += 1;
                g.game_type = .cooperative;
            } else {
                g.game_type = .single_player;
                if (rodent.findAnotherRodent(&g.board)) |p| g.board.set(p, .empty);
            }
        }
    }

    if (g.state == .playing) {
        const now = rl.getTime();
        if (now - g.board.last_cat_update_s >= g.speed.updateIntervalS()) {
            cat.updateCats(&g.board);
            g.board.last_cat_update_s = now;
        }
    }

    if (rodent.findRodent(&g.board) == null) {
        if (g.remaining_lives == 0) {
            g.state = .game_over;
            return;
        }
        g.remaining_lives -= 1;
        rodent.respawnRodent(g);
    }

    if (g.game_type == .cooperative and rodent.findAnotherRodent(&g.board) == null) {
        if (g.remaining_lives == 0) {
            g.state = .game_over;
            return;
        }
        g.remaining_lives -= 1;
        rodent.respawnAnotherRodent(g);
    }

    const bs: usize = @intCast(config.board_size);
    var cats_buf: [bs * bs]Position = undefined;
    const cat_count = cat.findAllCats(&g.board, &cats_buf);
    if (cat_count == 0 and g.board.remaining_waves == 0) {
        g.nextLevel();
    }

    if (g.state == .playing) {
        rodent.moveRodent(g);
    }
}
