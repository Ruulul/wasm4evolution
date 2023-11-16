const w4 = @import("wasm4.zig");

const smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

export fn _start() void {
    start();
}
export fn start() void {}

export fn update() void {
    w4.draw_colors.* = 2;
    w4.text("Hello from Zig!", 10, 10);

    const gamepad = w4.gamepad[0].*;
    if (gamepad & w4.button_1 != 0) {
        w4.draw_colors.* = 4;
    }

    w4.blit(&smiley, 76, 76, 8, 8, w4.BLIT_1BPP);
    w4.text("Press X to blink", 16, 90);
}
