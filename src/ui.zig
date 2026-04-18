const std = @import("std");
const rl = @import("raylib");
const game = @import("game.zig");
const config = @import("config.zig");

const Object = game.Object;
const Position = game.Position;
const Game = game.Game;

const BS: i32 = config.board_size;
const SQ: i32 = config.square_size;
const TS: i32 = config.texture_square_size;
const SBH: i32 = config.status_bar_height;

const resources = @import("resources");

const Animation = struct {
    texture: rl.Texture2D,
    frame_counter: i32,

    fn finished(self: Animation) bool {
        const frame_count = @divTrunc(self.texture.width, TS);
        const current_frame = @mod(@divTrunc(self.frame_counter, 10), frame_count);
        return self.frame_counter > (frame_count - 1) * 10 and current_frame == 0;
    }

    fn draw(self: *Animation, p: Position) void {
        const frame_count = @divTrunc(self.texture.width, TS);
        const current_frame = @mod(@divTrunc(self.frame_counter, 10), frame_count);
        const src: rl.Rectangle = .{
            .x = @floatFromInt(current_frame * TS),
            .y = 0,
            .width = @floatFromInt(TS),
            .height = @floatFromInt(TS),
        };
        const dest: rl.Rectangle = .{
            .x = @floatFromInt(p.column * SQ),
            .y = @floatFromInt(SBH + p.row * SQ),
            .width = @floatFromInt(SQ),
            .height = @floatFromInt(SQ),
        };
        rl.drawTexturePro(self.texture, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
        self.frame_counter += 1;
    }
};

pub const UI = struct {
    textures: [std.enums.values(Object).len]rl.Texture2D,
    rodent_lives: rl.Texture2D,
    rodent_death: rl.Texture2D,
    clock: rl.Texture2D,
    animations: [@intCast(BS)][@intCast(BS)]?Animation,
    show_help: bool,

    pub fn init() !UI {
        const width = SQ * BS;
        const height = SQ * BS + SBH;
        rl.initWindow(width, height, "Zig, Rodent's Revenge!");
        rl.setTargetFPS(60);

        var textures: [std.enums.values(Object).len]rl.Texture2D = undefined;
        textures[@intFromEnum(Object.rodent)] = try loadTextureFromBytes(resources.rodent_png);
        textures[@intFromEnum(Object.another_rodent)] = try loadTextureFromBytes(resources.rodent_png);
        textures[@intFromEnum(Object.rodent_sinkhole)] = try loadTextureFromBytes(resources.sinkhole_rodent_png);
        textures[@intFromEnum(Object.another_rodent_sinkhole)] = try loadTextureFromBytes(resources.sinkhole_rodent_png);
        textures[@intFromEnum(Object.cat)] = try loadTextureFromBytes(resources.cat_png);
        textures[@intFromEnum(Object.cat_resting)] = try loadTextureFromBytes(resources.cat_rest_png);
        textures[@intFromEnum(Object.cheese)] = try loadTextureFromBytes(resources.cheese_png);
        textures[@intFromEnum(Object.obstacle)] = try loadTextureFromBytes(resources.obstacle_png);
        textures[@intFromEnum(Object.wall)] = try loadTextureFromBytes(resources.wall_png);
        textures[@intFromEnum(Object.sinkhole)] = try loadTextureFromBytes(resources.sinkhole_png);
        textures[@intFromEnum(Object.trap)] = try loadTextureFromBytes(resources.trap_png);
        textures[@intFromEnum(Object.empty)] = textures[@intFromEnum(Object.cheese)];

        var animations: [@intCast(BS)][@intCast(BS)]?Animation = undefined;
        for (0..@intCast(BS)) |i| {
            for (0..@intCast(BS)) |j| animations[i][j] = null;
        }

        return .{
            .textures = textures,
            .rodent_lives = try loadTextureFromBytes(resources.rodent_lives_png),
            .rodent_death = try loadTextureFromBytes(resources.rodent_death_png),
            .clock = try loadTextureFromBytes(resources.clock_png),
            .animations = animations,
            .show_help = false,
        };
    }

    pub fn close() void {
        rl.closeWindow();
    }

    pub fn draw(self: *UI, g: *Game) void {
        for (g.board.rodent_death.items) |p| {
            self.animations[@intCast(p.row)][@intCast(p.column)] = .{
                .texture = self.rodent_death,
                .frame_counter = 0,
            };
        }
        g.board.rodent_death.clearRetainingCapacity();

        rl.drawRectangle(0, 0, SQ * BS, SBH, .light_gray);

        var i: i32 = 0;
        while (i < g.remaining_lives) : (i += 1) {
            const x: f32 = @floatFromInt(SQ + i * SQ);
            const y: f32 = @floatFromInt(SQ);
            const scale: f32 = @as(f32, @floatFromInt(SQ)) / @as(f32, @floatFromInt(self.rodent_lives.width));
            rl.drawTextureEx(self.rodent_lives, .{ .x = x, .y = y }, 0, scale, .white);
        }

        const clock_x: f32 = @floatFromInt(@divTrunc(SQ * BS, 2) - SQ);
        const clock_y: f32 = @floatFromInt(@divTrunc(SQ, 2));
        const clock_scale: f32 = @as(f32, @floatFromInt(SQ * 2)) / @as(f32, @floatFromInt(self.clock.height));
        rl.drawTextureEx(self.clock, .{ .x = clock_x, .y = clock_y }, 0, clock_scale, .white);

        var buf: [128]u8 = undefined;
        const font: i32 = @divTrunc(SQ, 2);

        const level = std.fmt.bufPrintZ(&buf, "Level: {d}", .{g.current_level + 1}) catch "Level: ?";
        const level_w = rl.measureText(level, font);
        rl.drawText(level, SQ * (BS - 1) - level_w, @divTrunc(SQ, 2), font, .black);

        const score = std.fmt.bufPrintZ(&buf, "Score: {d}", .{g.points}) catch "Score: ?";
        const score_w = rl.measureText(score, font);
        rl.drawText(score, SQ * (BS - 1) - score_w, SQ, font, .black);

        const diff = std.fmt.bufPrintZ(&buf, "Difficulty: {s}", .{g.speed.name()}) catch "Difficulty: ?";
        const diff_w = rl.measureText(diff, font);
        rl.drawText(diff, SQ * (BS - 1) - diff_w, @divTrunc(SQ * 3, 2), font, .black);

        const help_text: [:0]const u8 = "? for help";
        const help_w = rl.measureText(help_text, font);
        rl.drawText(help_text, SQ * (BS - 1) - help_w, SQ * 2, font, .black);

        const board_bg = rl.Color.init(195, 195, 0, 255);
        var r: i32 = 0;
        while (r < BS) : (r += 1) {
            var c: i32 = 0;
            while (c < BS) : (c += 1) {
                rl.drawRectangle(c * SQ, SBH + r * SQ, SQ, SQ, board_bg);
                const ri: usize = @intCast(r);
                const ci: usize = @intCast(c);
                if (self.animations[ri][ci]) |*anim| {
                    if (anim.finished()) {
                        self.animations[ri][ci] = null;
                    } else {
                        anim.draw(.{ .row = r, .column = c });
                        continue;
                    }
                }
                const obj = g.board.objects[ri][ci];
                if (obj == .empty) continue;
                const tex = self.textures[@intFromEnum(obj)];
                const scale: f32 = @as(f32, @floatFromInt(SQ)) / @as(f32, @floatFromInt(tex.width));
                const dx: f32 = @floatFromInt(c * SQ);
                const dy: f32 = @floatFromInt(SBH + r * SQ);
                rl.drawTextureEx(tex, .{ .x = dx, .y = dy }, 0, scale, tintFor(obj));
            }
        }

        if (config.draw_grid) drawGrid();

        switch (g.state) {
            .game_over => displayText("Game Over", SQ),
            .win => displayText("You win!", SQ),
            .pause => displayText("Paused. Press P to continue.", SQ),
            .playing => {},
        }

        if (self.show_help) {
            displayText(
                "Arrow keys: Move the rodent (8 directions)\n" ++
                    "P: Pause the game\n" ++
                    "Right Shift + UP: Increase difficulty (speeds up the cats)\n" ++
                    "Right Shift + DOWN: Decrease difficulty (speeds up the cats)\n" ++
                    "Right Shift + RIGHT: Skip to the next level\n" ++
                    "Right Shift + LEFT: Go back to the previous level\n" ++
                    "Right Shift + M: Toggle between single player and cooperative\n" ++
                    "?: Toggle this help screen\n" ++
                    "ESC: Quit the game",
                @divTrunc(SQ, 2),
            );
        }
    }
};

fn tintFor(obj: Object) rl.Color {
    return if (obj == .another_rodent) .gray else .white;
}

fn loadTextureFromBytes(data: [:0]const u8) !rl.Texture2D {
    const image = try rl.loadImageFromMemory(".png", data);
    defer rl.unloadImage(image);
    return try rl.loadTextureFromImage(image);
}

fn displayText(text: [:0]const u8, font_size: i32) void {
    const text_w = rl.measureText(text, font_size);
    const box_w = text_w + 20;
    var lines: i32 = 0;
    for (text) |ch| {
        if (ch == '\n') lines += 1;
    }
    var box_h = font_size + font_size * lines + 10;
    if (lines > 1) box_h += 10;
    const x = @divTrunc(SQ * BS, 2) - @divTrunc(box_w, 2);
    const y = @divTrunc(BS * SQ, 2) - @divTrunc(box_h, 2);
    rl.drawRectangle(x, y, box_w, box_h, .white);
    rl.drawText(text, x + 10, y + 5, font_size, .black);
}

fn drawGrid() void {
    const limit = BS * SQ;
    var i: i32 = 0;
    while (i < limit) : (i += 1) {
        const x: f32 = @floatFromInt(SQ * i);
        rl.drawLineV(.{ .x = x, .y = 0 }, .{ .x = x, .y = @floatFromInt(limit) }, .light_gray);
    }
    i = 0;
    while (i < limit) : (i += 1) {
        const y: f32 = @floatFromInt(SQ * i);
        rl.drawLineV(.{ .x = 0, .y = y }, .{ .x = @floatFromInt(limit), .y = y }, .light_gray);
    }
}
