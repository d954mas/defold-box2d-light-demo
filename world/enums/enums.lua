local ENUMS = {}

ENUMS.GAME_INPUT = {
    NONE = "NONE",
    TOUCHED = "TOUCHED",
    DRAG = "DRAG",
    SELECT = "SELECT",
    ZOOMING = "ZOOMING"
}

ENUMS.GAME_STATE = {
    PAUSE = "PAUSE",
    RUN = "RUN"
}

ENUMS.DIRECTION = {
    UP = "UP",
    DOWN = "DOWN",
    LEFT = "LEFT",
    RIGHT = "RIGHT"
}

ENUMS.PLAYER_ANIMATIONS = {
    IDLE = "IDLE",
    JUMP = "JUMP",
    IN_AIR_UP = "IN_AIR_UP",
    IN_AIR_DOWN = "IN_AIR_DOWN",
    RUN = "RUN",
}


return ENUMS