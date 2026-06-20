"""Central configuration for Learn2Slither.

Every tunable constant lives here so the Environment, Interpreter and Agent
modules share a single source of truth. Import these names; never hard-code the
values elsewhere.
"""

from __future__ import annotations

# --- Board -----------------------------------------------------------------
BOARD_SIZE: int = 10
N_GREEN_APPLES: int = 2
N_RED_APPLES: int = 1
INITIAL_SNAKE_LENGTH: int = 3

# --- Cell symbols (terminal vision) ----------------------------------------
SYM_WALL: str = "W"
SYM_HEAD: str = "H"
SYM_BODY: str = "S"
SYM_GREEN: str = "G"
SYM_RED: str = "R"
SYM_EMPTY: str = "0"

# --- Actions / state space -------------------------------------------------
N_ACTIONS: int = 4
# State encoding "v1": 3 bits (danger, green_in_line, red_in_line) per the four
# directions => 12 bits => 4096 discrete states. Vision-only and board-size
# independent (no coordinates), so it respects the -42 rule and the variable
# board-size bonus.
STATE_ENCODING_VERSION: str = "v1"
N_STATES: int = 1 << 12  # 4096

# --- Rewards (tunable) ------------------------------------------------------
REWARD_EAT_GREEN: float = 20.0
REWARD_EAT_RED: float = -15.0
REWARD_STEP: float = -1.0
REWARD_DEATH: float = -100.0

# --- Q-learning hyperparameters --------------------------------------------
ALPHA: float = 0.1            # learning rate
GAMMA: float = 0.9            # discount factor
EPSILON_START: float = 1.0    # initial exploration probability
EPSILON_MIN: float = 0.01     # floor for exploration
EPSILON_DECAY: float = 0.995  # multiplicative decay applied once per session

# --- Neural-network agent (alternate update strategy) ----------------------
NN_HIDDEN_SIZE: int = 32
NN_LEARNING_RATE: float = 0.001

# --- Episode safety ---------------------------------------------------------
# Hard cap on steps within a single game so a circling snake cannot loop
# forever during headless training.
MAX_STEPS_PER_SESSION: int = 1000

# --- Visualization ----------------------------------------------------------
CELL_PIXELS: int = 40          # pixel size of one board cell
DEFAULT_FPS: int = 10          # human-readable default display speed
COLOR_BACKGROUND = (18, 18, 18)
COLOR_GRID = (40, 40, 40)
COLOR_SNAKE = (40, 120, 240)   # blue snake (subject requirement)
COLOR_HEAD = (90, 170, 255)
COLOR_GREEN_APPLE = (40, 200, 80)
COLOR_RED_APPLE = (220, 60, 60)

# --- Stats panel / lobby (bonus) -------------------------------------------
# Right-side strip drawn next to the board to show live run statistics, and
# the shared look of the configuration lobby. New names only; nothing above is
# touched so the mandatory display stays byte-identical when no stats are fed.
PANEL_PIXELS: int = 220             # width of the right stats strip in pixels
FONT_SIZE: int = 22                 # base font size for panel/lobby text
COLOR_PANEL_BG = (28, 28, 34)       # stats panel background
COLOR_PANEL_TEXT = (220, 220, 230)  # primary panel/lobby text
COLOR_PANEL_DIM = (120, 120, 130)   # dimmed/disabled widget text
COLOR_PANEL_ACCENT = (90, 170, 255)  # highlight (matches the snake head)
COLOR_WIDGET_BG = (48, 48, 58)      # lobby widget background
COLOR_WIDGET_HOVER = (70, 70, 86)   # lobby widget background when hovered

# --- Reproducibility --------------------------------------------------------
DEFAULT_SEED: int = 42
