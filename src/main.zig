const std = @import("std");
const print = std.debug.print;

const raylib = @import("raylib");

const WINDOW_WIDTH  = 800;
const WINDOW_HEIGHT = 450;
const RENDER_SNAKE  = true;
const CELL_SIZE     = 10;
const CELL_VEC 	    = raylib.Vector2.init(CELL_SIZE, CELL_SIZE);
const TARGET_FPS    = 60;
const DEFAULT_SPEED = 5;

const Direction = enum {
    up,
    right,
    down,
    left,

    fn toVector2(self: Direction) raylib.Vector2 {
        return switch (self) {
            .up     => raylib.Vector2.init(-1, 0),
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
    previous_snake_direction: raylib.Vector2,
    speed: i8,

    fn init(allocator: std.mem.Allocator, io: std.Io) Game {
        const game = Game{ 
            .snake_positions            = std.ArrayList(raylib.Vector2).empty, 
            .food_positions             = std.ArrayList(raylib.Vector2).empty, 
            .current_snake_direction    = raylib.Vector2.init(0, 0), 
            .previous_snake_direction   = raylib.Vector2.init(0, 0),  
            .speed                      = DEFAULT_SPEED
        };
 
        try game.food_positions.append(allocator, get_random_coordinates(io));

        return game;
    }

};


fn update(allocator: std.mem.Allocator, io: std.Io, game: *Game, key_pressed: raylib.KeyboardKey) !void {
    _ = switch (key_pressed) {
        .up => {
            if (!game.current_snake_direction.equals(Direction.up.toVector2())) { 
                game.current_snake_direction = Direction.up.toVector2();
            }
        },
        .right => {
            if (!game.current_snake_direction.equals(Direction.right.toVector2())) { 
                game.current_snake_direction = Direction.right.toVector2();
            }
        },
        .down => {
            if (!game.current_snake_direction.equals(Direction.down.toVector2())) { 
                game.current_snake_direction = Direction.down.toVector2();
            }
        },
        .left => {
            if (!game.current_snake_direction.equals(Direction.left.toVector2())) { 
                game.current_snake_direction = Direction.left.toVector2();
            }
        },
        .one => game.speed = @min(10, game.speed + 1),
        .two => game.speed = @max(1, game.speed - 1),
        else => {},
    };

    var i = game.snake_positions.items.len;
    const snake_head_curr_position = game.snake_positions.items[0];

        while (i > 0) {
            i -= 1;

            var snake_head_new_position: raylib.Vector2 = undefined;

            if (i == 0) {
                snake_head_new_position = snake_head_curr_position.add(game.current_snake_direction.multiply(CELL_VEC));

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

                game.snake_positions.items[i] = snake_head_new_position;
            } else {
                game.snake_positions.items[i] = game.snake_positions.items[i - 1];
            }
        }

    var shouldGrow = false;

    for (game.food_positions.items, 0..) |food_pos, index| {
        if (food_pos.equals(game.snake_positions.items[0])) {
            shouldGrow = true;
            _ = game.food_positions.orderedRemove(index);
            break;
        }
    }

    if (shouldGrow) {
        const last_snake_position = game.snake_positions.getLast();
        const new_segment_position = raylib.Vector2.subtract(last_snake_position, game.previous_snake_direction);
        game.previous_snake_direction = game.current_snake_direction;
        try game.snake_positions.append(allocator, new_segment_position);
        shouldGrow = false;

        try game.food_positions.append(allocator, get_random_coordinates(io));
    }
}

fn deinit_game(game: *Game, allocator: std.mem.Allocator) void {
    game.food_positions.deinit(allocator);
    game.snake_positions.deinit(allocator);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var game = Game.init(allocator, io);
    defer deinit_game(&game, allocator);

    raylib.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Snake");
    defer raylib.closeWindow();

    raylib.setTargetFPS(TARGET_FPS);

    try game.snake_positions.append(allocator, raylib.Vector2.init(0, 0));


    var accumulator: i64 = 0;

    while (!raylib.windowShouldClose()) {
        const delta_time_in_ns = @as(i64, @intFromFloat(raylib.getFrameTime() * std.time.ns_per_s));

        accumulator += (@divFloor(delta_time_in_ns, game.speed));

        if (accumulator >= delta_time_in_ns) {
            try update(allocator, io, &game, raylib.getKeyPressed());

            accumulator -= delta_time_in_ns;
        }


        raylib.beginDrawing();
        defer raylib.endDrawing();

        if (comptime RENDER_SNAKE) {
            for (game.snake_positions.items) |pos| {
                raylib.drawRectangleV(pos, CELL_VEC, raylib.Color.red);
            }
            for (game.food_positions.items) |pos| {
                raylib.drawRectangleV(pos, CELL_VEC, raylib.Color.green);
            }
        }

        raylib.clearBackground(raylib.Color.init(22, 22, 22, 1));
    }
}

fn get_random_coordinates(io: std.Io) raylib.Vector2 {
    const source: std.Random.IoSource = .{ .io = io };
    const rnd = source.interface();

    const random_x_pos = @divFloor((rnd.float(f32) * @as(f32, @floatFromInt(WINDOW_WIDTH))), 10) * 10;
    const random_y_pos = @divFloor((rnd.float(f32) * @as(f32, @floatFromInt(WINDOW_HEIGHT))), 10) * 10;

    return raylib.Vector2.init(random_x_pos, random_y_pos);
}

