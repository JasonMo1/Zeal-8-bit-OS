    IFNDEF VIDEO_H
    DEFINE VIDEO_H

    ; Screen macros
    DEFC SCREEN_SCROLL_ENABLED = 0x1

    ; Colors used by default
    DEFC DEFAULT_CHARS_COLOR   = 0x0f ; Black background, white foreground

    ; Physical address of the FPGA video
    DEFC IO_VIDEO_PHYS_ADDR_START  = 0x100000
    DEFC IO_VIDEO_PHYS_ADDR_TEXT   = IO_VIDEO_PHYS_ADDR_START
    DEFC IO_VIDEO_PHYS_ADDR_COLORS = IO_VIDEO_PHYS_ADDR_TEXT + 0x2000

    ; Macros for video chip I/O registers and memory mapping
    DEFC IO_VIDEO_SET_CHAR   = 0x80
    DEFC IO_VIDEO_SET_MODE   = 0x83
    DEFC IO_VIDEO_SCROLL_Y   = 0x85
    DEFC IO_VIDEO_SET_COLOR  = 0x86
    DEFC IO_MAP_VIDEO_MEMORY = 0x84
    DEFC MAP_VRAM            = 0x00
    DEFC MAP_SPRITE_RAM      = 0x01

    ; Video modes
    DEFC TEXT_MODE_640 = 1;
    DEFC TILE_MODE_640 = 3;

    ; Macros for text-mode
    DEFC TEXT_MODE_640_480 = 1
    DEFC IO_VIDEO_800600_WIDTH = 800
    DEFC IO_VIDEO_800600_HEIGHT = 600
    DEFC IO_VIDEO_800600_X_MAX = 100
    DEFC IO_VIDEO_800600_Y_MAX = 50
    DEFC IO_VIDEO_640480_WIDTH = 640
    DEFC IO_VIDEO_640480_HEIGHT = 480
    DEFC IO_VIDEO_640480_X_MAX = 80
    DEFC IO_VIDEO_640480_Y_MAX = 40

    IFDEF TEXT_MODE_640_480
        DEFC IO_VIDEO_X_MAX = IO_VIDEO_640480_X_MAX
        DEFC IO_VIDEO_Y_MAX = IO_VIDEO_640480_Y_MAX
        DEFC IO_VIDEO_WIDTH = IO_VIDEO_640480_WIDTH
        DEFC IO_VIDEO_HEIGHT = IO_VIDEO_640480_HEIGHT
    ELSE
        DEFC IO_VIDEO_X_MAX = IO_VIDEO_800600_X_MAX
        DEFC IO_VIDEO_Y_MAX = IO_VIDEO_800600_Y_MAX
        DEFC IO_VIDEO_WIDTH = IO_VIDEO_800600_WIDTH
        DEFC IO_VIDEO_HEIGHT = IO_VIDEO_800600_HEIGHT
    ENDIF

    DEFC IO_VIDEO_MAX_CHAR = IO_VIDEO_X_MAX * IO_VIDEO_Y_MAX
    DEFC BIG_SPRITES_PER_LINE = IO_VIDEO_WIDTH / 16
    DEFC BIG_SPRITES_PER_COL = IO_VIDEO_HEIGHT / 16

    ENDIF