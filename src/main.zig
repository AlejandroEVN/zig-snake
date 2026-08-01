const std = @import("std");
const print = std.debug.print;

const raylib = @import("raylib");

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 450;
const CELL_SIZE = 10;
const CELL_VEC = raylib.Vector2.init(CELL_SIZE, CELL_SIZE);
const TARGET_FPS = 60;
const DEFAULT_SPEED = 5;
const FONT_SIZE = 20;
const BG_COLOR = raylib.Color.init(22, 22, 22, 1);
const FG_COLOR = raylib.Color.init(255, 161, 0, 128);
const GAME_OVER_TEXT = "You Lost!\n";
const RESTART_TEXT = "Press R to restart or Q / ESC to quit";
const START_TEXT = "Press Enter to start or Q / ESC to quit";

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var game = try Game.init(allocator, io);
    defer game.deinit_game(allocator);

    raylib.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Snake");
    defer raylib.closeWindow();

    raylib.setTargetFPS(TARGET_FPS);

    while (!raylib.windowShouldClose()) {
        const key_pressed = raylib.getKeyPressed(); 
        handle_key_press(key_pressed, &game);

        if (key_pressed == .q) {
            break;
        }

        if (key_pressed == .r) {
            try game.restart(allocator, io);
        }

        try game.update(allocator, io);

        game.frames_counter += 1;
        try render(allocator, game);
    }
}

fn get_random_coordinates(io: std.Io) raylib.Vector2 {
    const source: std.Random.IoSource = .{ .io = io };
    const rnd = source.interface();

    const random_x_pos = @divFloor((rnd.float(f32) * @as(f32, @floatFromInt(WINDOW_WIDTH))), CELL_SIZE) * CELL_SIZE;
    const random_y_pos = @divFloor((rnd.float(f32) * @as(f32, @floatFromInt(WINDOW_HEIGHT))), CELL_SIZE) * CELL_SIZE;

    return raylib.Vector2.init(random_x_pos, random_y_pos);
}

const Direction = enum {
    up,
    right,
    down,
    left,

    fn toVector2(self: Direction) raylib.Vector2 {
        return switch (self) {
            .up => raylib.Vector2.init(0, -CELL_SIZE),
            .right => raylib.Vector2.init(CELL_SIZE, 0),
            .down => raylib.Vector2.init(0, CELL_SIZE),
            .left => raylib.Vector2.init(-CELL_SIZE, 0),
        };
    }
};

const Game = struct {
    snake_positions: std.ArrayList(raylib.Vector2),
    food_positions: std.ArrayList(raylib.Vector2),
    current_snake_direction: raylib.Vector2,
    speed: i8,
    game_over: bool,
    has_started: bool,
    allow_move: bool,
    frames_counter: usize,

    fn init(allocator: std.mem.Allocator, io: std.Io) !Game {
        const snake_positions: std.ArrayList(raylib.Vector2) = .empty;

        var game = Game{ .snake_positions = snake_positions, .food_positions = std.ArrayList(raylib.Vector2).empty, .current_snake_direction = raylib.Vector2.init(0, 0), .speed = DEFAULT_SPEED, .game_over = false, .has_started = false, .allow_move = false, .frames_counter = 0 };

        try game.snake_positions.append(allocator, raylib.Vector2.init(0, 0));
        try game.spawn_food(allocator, io);

        return game;
    }

    fn deinit_game(self: *Game, allocator: std.mem.Allocator) void {
        self.food_positions.deinit(allocator);
        self.snake_positions.deinit(allocator);
    }

    fn restart(self: *Game, allocator: std.mem.Allocator, io: std.Io) !void {
        self.game_over = false;
        self.has_started = true;
        self.snake_positions.clearRetainingCapacity();
        self.food_positions.clearRetainingCapacity();

        try self.snake_positions.append(allocator, raylib.Vector2.init(0, 0));
        try self.spawn_food(allocator, io);
    }

    fn spawn_food(self: *Game, allocator: std.mem.Allocator, io: std.Io) !void {
        const coord = get_random_coordinates(io);

        for (self.snake_positions.items) |snake_segment| {
            if (snake_segment.equals(coord)) {
                return self.spawn_food(allocator, io);
            }
        }

        try self.food_positions.append(allocator, coord);
    }

    fn score(self: Game) usize {
        return self.snake_positions.items.len - 1;
    }

    fn update(self: *Game, allocator: std.mem.Allocator, io: std.Io) !void {
        var i = self.snake_positions.items.len;
        const snake_head_curr_position = self.snake_positions.items[0];
        const snake_curr_last_segment = self.snake_positions.getLast();

        while (i > 0 and @mod(self.frames_counter, 5) == 0) {
            i -= 1;

            var snake_head_new_position: raylib.Vector2 = undefined;

            if (i == 0) {
                snake_head_new_position = snake_head_curr_position.add(self.current_snake_direction);

                if (snake_head_new_position.x >= WINDOW_WIDTH) {
                    snake_head_new_position.x = 0;
                } else if (snake_head_new_position.x + CELL_SIZE <= 0) {
                    snake_head_new_position.x = WINDOW_WIDTH - CELL_SIZE;
                }

                if (snake_head_new_position.y >= WINDOW_HEIGHT) {
                    snake_head_new_position.y = 0;
                } else if (snake_head_new_position.y + CELL_SIZE <= 0) {
                    snake_head_new_position.y = WINDOW_HEIGHT - CELL_SIZE;
                }

                self.snake_positions.items[i] = snake_head_new_position;
            } else {
                self.snake_positions.items[i] = self.snake_positions.items[i - 1];
            }

            self.allow_move = true;
        }

        for (self.snake_positions.items[1..]) |pos| {
            if (self.snake_positions.items[0].equals(pos)) {
                self.game_over = true;
            }
        }

        var shouldGrow = false;

        for (self.food_positions.items, 0..) |food_pos, index| {
            if (food_pos.equals(self.snake_positions.items[0])) {
                shouldGrow = true;
                _ = self.food_positions.orderedRemove(index);
                break;
            }
        }

        if (shouldGrow) {
            try self.snake_positions.append(allocator, snake_curr_last_segment);
            shouldGrow = false;

            try self.spawn_food(allocator, io);
        }
    }
};

fn handle_key_press(key_pressed: raylib.KeyboardKey, game: *Game) void {
    if (!game.allow_move) {
        return;
    }

    if (key_pressed == .up and game.current_snake_direction.y == 0) {
        game.current_snake_direction = Direction.up.toVector2();
        game.allow_move = false;
    }

    if (key_pressed == .down and game.current_snake_direction.y == 0) {
        game.current_snake_direction = Direction.down.toVector2();
        game.allow_move = false;
    }

    if (key_pressed == .left and game.current_snake_direction.x == 0) {
        game.current_snake_direction = Direction.left.toVector2();
        game.allow_move = false;
    }

    if (key_pressed == .right and game.current_snake_direction.x == 0) {
        game.current_snake_direction = Direction.right.toVector2();
        game.allow_move = false;
    }

    if (key_pressed == .enter) {
        game.has_started = true;
    }
}

fn render(allocator: std.mem.Allocator, game: Game) !void {
    raylib.beginDrawing();
    defer raylib.endDrawing();

    raylib.clearBackground(BG_COLOR);

    const score = try std.fmt.allocPrintSentinel(allocator, "Score: {d}", .{game.score()}, 0);
    defer allocator.free(score);
    const score_text_size = raylib.measureText(score, FONT_SIZE);

    if (!game.has_started) {
        raylib.drawText(START_TEXT, @divFloor(WINDOW_WIDTH, 2) - @divFloor(raylib.measureText(START_TEXT, FONT_SIZE), 2), @divFloor(WINDOW_HEIGHT, 2), FONT_SIZE, FG_COLOR);

        return;
    }

    if (game.game_over) {
        const concated = try std.mem.concat(allocator, u8, &.{ GAME_OVER_TEXT, score });
        defer allocator.free(concated);

        raylib.drawText(@ptrCast(concated), @divFloor(WINDOW_WIDTH, 2) - @divFloor(score_text_size, 2), @divFloor(WINDOW_HEIGHT, 4) - FONT_SIZE, FONT_SIZE, FG_COLOR);

        raylib.drawText(RESTART_TEXT, @divFloor(WINDOW_WIDTH, 2) - @divFloor(raylib.measureText(RESTART_TEXT, FONT_SIZE), 2), @divFloor(WINDOW_HEIGHT, 2), FONT_SIZE, FG_COLOR);

        return;
    }

    for (game.snake_positions.items, 0..) |pos, i| {
        const color = if (i == 0) raylib.Color.green else  raylib.Color.dark_green;
        raylib.drawRectangleV(pos, CELL_VEC, color);
    }
    for (game.food_positions.items) |pos| {
        raylib.drawRectangleV(pos, CELL_VEC, raylib.Color.red);
    }

    raylib.drawText(score, WINDOW_WIDTH - score_text_size - 10, 1, FONT_SIZE, FG_COLOR);
}
