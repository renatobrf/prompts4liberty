import pygame
import random
import sys

# -----------------------------
# Config
# -----------------------------
WIDTH, HEIGHT = 800, 480
FPS = 60
TITLE = "8-Bit Market Stocks"

SKY = (20, 24, 82)
GROUND = (30, 30, 30)
WHITE = (240, 240, 240)
GREEN = (80, 220, 120)
RED = (220, 70, 70)
YELLOW = (250, 220, 90)
BLUE = (80, 160, 255)
GRAY = (120, 120, 120)

PLAYER_SPEED = 5
ITEM_SPEED = 4
SPAWN_EVENT = pygame.USEREVENT + 1

# -----------------------------
# Init
# -----------------------------
pygame.init()
pygame.display.set_caption(TITLE)
screen = pygame.display.set_mode((WIDTH, HEIGHT))
clock = pygame.time.Clock()

font_small = pygame.font.SysFont("consolas", 20, bold=True)
font_big = pygame.font.SysFont("consolas", 32, bold=True)

pygame.time.set_timer(SPAWN_EVENT, 900)

# -----------------------------
# Helpers
# -----------------------------
def draw_text(surface, text, font, color, x, y):
    img = font.render(text, True, color)
    surface.blit(img, (x, y))

def clamp(v, low, high):
    return max(low, min(v, high))

# -----------------------------
# Game objects
# -----------------------------
class Player:
    def __init__(self):
        self.w = 28
        self.h = 28
        self.x = 80
        self.y = HEIGHT // 2
        self.portfolio = 100
        self.lives = 3
        self.invuln_timer = 0

    @property
    def rect(self):
        return pygame.Rect(self.x, self.y, self.w, self.h)

    def update(self, keys):
        dx = 0
        dy = 0
        if keys[pygame.K_LEFT]:
            dx -= PLAYER_SPEED
        if keys[pygame.K_RIGHT]:
            dx += PLAYER_SPEED
        if keys[pygame.K_UP]:
            dy -= PLAYER_SPEED
        if keys[pygame.K_DOWN]:
            dy += PLAYER_SPEED

        self.x = clamp(self.x + dx, 0, WIDTH - self.w)
        self.y = clamp(self.y + dy, 40, HEIGHT - self.h - 20)

        if self.invuln_timer > 0:
            self.invuln_timer -= 1

    def draw(self, surface):
        color = YELLOW if self.invuln_timer % 10 < 5 else BLUE if self.invuln_timer > 0 else BLUE
        pygame.draw.rect(surface, color, self.rect)
        pygame.draw.rect(surface, WHITE, self.rect, 2)

        points = [
            (self.x + 4, self.y + 20),
            (self.x + 10, self.y + 14),
            (self.x + 16, self.y + 16),
            (self.x + 22, self.y + 8),
        ]
        pygame.draw.lines(surface, WHITE, False, points, 2)

class MarketItem:
    def __init__(self, kind):
        self.kind = kind
        self.size = random.randint(18, 26)
        self.x = WIDTH + random.randint(0, 100)
        self.y = random.randint(50, HEIGHT - 60)

        if kind == "profit":
            self.color = GREEN
            self.value = random.randint(8, 18)
        elif kind == "boost":
            self.color = YELLOW
            self.value = random.randint(15, 25)
        else:
            self.color = RED
            self.value = -random.randint(10, 22)

    @property
    def rect(self):
        return pygame.Rect(self.x, self.y, self.size, self.size)

    def update(self):
        self.x -= ITEM_SPEED

    def draw(self, surface):
        pygame.draw.rect(surface, self.color, self.rect)
        pygame.draw.rect(surface, WHITE, self.rect, 2)

        cx = self.x + self.size // 2
        cy = self.y + self.size // 2

        if self.kind in ("profit", "boost"):
            pygame.draw.line(surface, WHITE, (self.x + 4, self.y + self.size - 5), (cx, cy), 2)
            pygame.draw.line(surface, WHITE, (cx, cy), (self.x + self.size - 4, self.y + 4), 2)
        else:
            pygame.draw.line(surface, WHITE, (self.x + 4, self.y + 4), (self.x + self.size - 4, self.y + self.size - 4), 2)
            pygame.draw.line(surface, WHITE, (self.x + self.size - 4, self.y + 4), (self.x + 4, self.y + self.size - 4), 2)

# -----------------------------
# Game state
# -----------------------------
player = Player()
items = []
score = 0
level = 1
frame_count = 0
game_over = False

# -----------------------------
# Main loop
# -----------------------------
while True:
    clock.tick(FPS)
    frame_count += 1

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit()
            sys.exit()

        if event.type == SPAWN_EVENT and not game_over:
            roll = random.random()
            if roll < 0.55:
                items.append(MarketItem("profit"))
            elif roll < 0.75:
                items.append(MarketItem("boost"))
            else:
                items.append(MarketItem("crash"))

        if event.type == pygame.KEYDOWN and game_over:
            if event.key == pygame.K_r:
                player = Player()
                items = []
                score = 0
                level = 1
                frame_count = 0
                game_over = False

    keys = pygame.key.get_pressed()

    if not game_over:
        player.update(keys)

        for item in items[:]:
            item.update()

            if item.rect.colliderect(player.rect):
                if item.kind == "profit":
                    player.portfolio += item.value
                    score += item.value
                elif item.kind == "boost":
                    player.portfolio += item.value
                    score += item.value * 2
                elif item.kind == "crash" and player.invuln_timer == 0:
                    player.portfolio += item.value
                    player.lives -= 1
                    player.invuln_timer = 50

                items.remove(item)
                continue

            if item.x + item.size < 0:
                items.remove(item)

        level = 1 + score // 80

        if player.lives <= 0 or player.portfolio <= 0:
            game_over = True

    screen.fill(SKY)

    for x in range(0, WIDTH, 32):
        pygame.draw.line(screen, (35, 40, 100), (x, 40), (x, HEIGHT), 1)
    for y in range(40, HEIGHT, 32):
        pygame.draw.line(screen, (35, 40, 100), (0, y), (WIDTH, y), 1)

    pygame.draw.rect(screen, GROUND, (0, 0, WIDTH, 40))
    draw_text(screen, f"Portfolio: ${player.portfolio}", font_small, GREEN if player.portfolio > 50 else RED, 12, 10)
    draw_text(screen, f"Lives: {player.lives}", font_small, WHITE, 250, 10)
    draw_text(screen, f"Score: {score}", font_small, WHITE, 360, 10)
    draw_text(screen, f"Level: {level}", font_small, WHITE, 500, 10)
    draw_text(screen, "Move: Arrows", font_small, GRAY, 620, 10)

    for item in items:
        item.draw(screen)

    player.draw(screen)

    draw_text(screen, "Collect green/yellow stocks, avoid red crashes", font_small, WHITE, 160, HEIGHT - 28)

    if game_over:
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        screen.blit(overlay, (0, 0))

        draw_text(screen, "MARKET CLOSED", font_big, WHITE, WIDTH // 2 - 140, HEIGHT // 2 - 60)
        draw_text(screen, f"Final Score: {score}", font_small, YELLOW, WIDTH // 2 - 80, HEIGHT // 2 - 15)
        draw_text(screen, "Press R to restart", font_small, WHITE, WIDTH // 2 - 95, HEIGHT // 2 + 20)

    pygame.display.flip()

# Made with Bob
