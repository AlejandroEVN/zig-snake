const std = @import("std");
const print = std.debug.print;

const raylib = @import("raylib");

const WINDOW_WIDTH   = 800;
const WINDOW_HEIGHT  = 450;
const RENDER_SNAKE   = true;
const CELL_SIZE      = 10;
const CELL_VEC 	     = raylib.Vector2.init(CELL_SIZE, CELL_SIZE);
const TARGET_FPS     = 60;
const DEFAULT_SPEED  = 5;
const FONT_SIZE      = 20;
const BG_COLOR       = raylib.Color.init(22, 22, 22, 1);
const FG_COLOR       = raylib.Color.init(255, 161, 0, 128);
const GAME_OVER_TEXT = "You Lost!\n"; 

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var game = try Game.init(allocator, io);
    defer deinit_game(&game, allocator);

    raylib.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Snake");
    defer raylib.closeWindow();

    raylib.setTargetFPS(TARGET_FPS);

    var accumulator: i64 = 0;

    while (!raylib.windowShouldClose()) {
        const delta_time_in_ns = @as(i64, @intFromFloat(raylib.getFrameTime() * std.time.ns_per_s));
        accumulator += (@divFloor(delta_time_in_ns, game.speed));

        handle_key_press(raylib.getKeyPressed(), &game);

        if (accumulator >= delta_time_in_ns and !game.game_over) {
            try game.update(allocator, io);

            accumulator -= delta_time_in_ns;
        }

        try render(allocator, game);
    }
}

fn get_random_coordinates(io: std.Io) raylib.Vector2 {
    const source: std.Random.IoSource = .{ .io = io };
    const rnd = source.interface();

    const random_x_pos = @divFloor((rnd.float(f32) * @as(f32, @floatFromInt(WINDOW_WIDTH))), 10) * 10;
    const random_y_pos = @divFloor((rnd.float(f32) * @as(f32, @floatFromInt(WINDOW_HEIGHT))), 10) * 10;

    return raylib.Vector2.init(random_x_pos, random_y_pos);
}

const Direction = enum {
    up,
    right,
    down,
    left,

    fn toVector2(self: Direction) raylib.Vector2 {
        return switch (self) {
            .up     => raylib.Vector2.init(0, -1),
            .right  => raylib.Vector2.init(1, 0),
            .down   => raylib.Vector2.init(0, 1),
            .left   => raylib.Vector2.init(-1, 0),
        };
    }
};

const Game = struct {
    snake_positions: std.ArrayList(raylib.Vector2),
    food_positions: std.ArrayList(raylib.Vector2),
    current_snake_direction: raylib.Vector2,
    speed: i8,
    game_over: bool,

    fn init(allocator: std.mem.Allocator, io: std.Io) !Game {
        var game = Game{ 
            .snake_positions            = std.ArrayList(raylib.Vector2).empty, 
            .food_positions             = std.ArrayList(raylib.Vector2).empty, 
            .current_snake_direction    = raylib.Vector2.init(0, 0), 
            .speed                      = DEFAULT_SPEED,
            .game_over                  = false
        };
 
        try game.spawn_food(allocator, io);
        try game.snake_positions.append(allocator, raylib.Vector2.init(0, 0));

        return game;
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

        while (i > 0) {
            i -= 1;

            var snake_head_new_position: raylib.Vector2 = undefined;

            if (i == 0) {
                snake_head_new_position = snake_head_curr_position.add(self.current_snake_direction.multiply(CELL_VEC));

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
                for (self.snake_positions.items, 0..) |snake_segment, segment_num| {
                    if (segment_num == 0) { continue; } 
                    const overlaps = snake_segment.equals(snake_head_new_position);
                    if (overlaps) {
                        self.game_over = true;
                        return;
                    }
                } 
            } else {
                self.snake_positions.items[i] = self.snake_positions.items[i - 1];
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
    _ = switch (key_pressed) {
        .up => {
            if (!game.current_snake_direction.equals(Direction.down.toVector2())) { 
                game.current_snake_direction = Direction.up.toVector2();
            }
        },
        .right => {
            if (!game.current_snake_direction.equals(Direction.left.toVector2())) { 
                game.current_snake_direction = Direction.right.toVector2();
            }
        },
        .down => {
            if (!game.current_snake_direction.equals(Direction.up.toVector2())) { 
                game.current_snake_direction = Direction.down.toVector2();
            }
        },
        .left => {
            if (!game.current_snake_direction.equals(Direction.right.toVector2())) { 
                game.current_snake_direction = Direction.left.toVector2();
            }
        },
        .one => game.speed = @min(10, game.speed + 1),
        .two => game.speed = @max(1, game.speed - 1),
        else => {},
    };
}


fn deinit_game(game: *Game, allocator: std.mem.Allocator) void {
    game.food_positions.deinit(allocator);
    game.snake_positions.deinit(allocator);
}

fn render(allocator: std.mem.Allocator, game: Game) !void {
    raylib.beginDrawing();
    defer raylib.endDrawing();

    raylib.clearBackground(BG_COLOR);

    const score = try std.fmt.allocPrintSentinel(allocator, "Score: {d}", .{ game.score() }, 0);
    defer allocator.free(score);
    const score_text_size = raylib.measureText(score, FONT_SIZE);

    if (game.game_over) {
        const concated = try std.mem.concat(allocator, u8, &.{ GAME_OVER_TEXT, score });
        defer allocator.free(concated);

        raylib.drawText(
            @ptrCast(concated), 
            @divFloor(WINDOW_WIDTH, 2) - @divFloor(score_text_size, 2), 
            @divFloor(WINDOW_HEIGHT, 2) - @divFloor(FONT_SIZE, 2),
            FONT_SIZE, 
            FG_COLOR
        );

        return;
    }

    if (comptime RENDER_SNAKE) {
        for (game.snake_positions.items) |pos| {
            raylib.drawRectangleV(pos, CELL_VEC, raylib.Color.red);
        }
        for (game.food_positions.items) |pos| {
            raylib.drawRectangleV(pos, CELL_VEC, raylib.Color.green);
        }
    }

    raylib.drawText(score, WINDOW_WIDTH - score_text_size - 10, 1, FONT_SIZE, FG_COLOR);
}

