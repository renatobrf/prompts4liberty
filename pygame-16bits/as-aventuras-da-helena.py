import pygame
import sys
import random

WIDTH = 800
HEIGHT = 600
FPS = 60

PLAYER_SIZE = 40
PLAYER_SPEED = 5
OBSTACLE_WIDTH = 60
OBSTACLE_HEIGHT = 40
OBSTACLE_COUNT = 10

SEA_COLOR = (21, 101, 189)
LIGHT_BLUE = (92, 173, 255)
SAND_COLOR = (255, 214, 165)
PINK = (255, 120, 198)
YELLOW = (248, 231, 28)
WHITE = (255, 255, 255)
DARK_BLUE = (10, 50, 107)


def draw_background(surface):
    surface.fill(SEA_COLOR)
    for y in range(0, HEIGHT, 20):
        pygame.draw.line(surface, LIGHT_BLUE, (0, y), (WIDTH, y), 1)
    for _ in range(40):
        x = random.randint(0, WIDTH)
        y = random.randint(0, HEIGHT)
        radius = random.randint(1, 3)
        pygame.draw.circle(surface, WHITE, (x, y), radius)
    pygame.draw.rect(surface, SAND_COLOR, (0, HEIGHT - 80, WIDTH, 80))
    pygame.draw.arc(surface, YELLOW, (-120, -120, 300, 300), 0.7, 1.6, 20)


def make_player():
    player = pygame.Surface((PLAYER_SIZE, PLAYER_SIZE), pygame.SRCALPHA)
    player.fill((0, 0, 0, 0))
    pygame.draw.rect(player, PINK, (8, 12, 24, 24))
    pygame.draw.rect(player, YELLOW, (14, 18, 12, 12))
    pygame.draw.rect(player, DARK_BLUE, (12, 8, 16, 10))
    pygame.draw.circle(player, WHITE, (18, 24), 3)
    pygame.draw.circle(player, WHITE, (26, 24), 3)
    pygame.draw.line(player, DARK_BLUE, (18, 32), (26, 32), 2)
    return player


def create_obstacles():
    obstacles = []
    for i in range(OBSTACLE_COUNT):
        x = random.randint(200, WIDTH - OBSTACLE_WIDTH - 40)
        y = random.randint(100, HEIGHT - OBSTACLE_HEIGHT - 120)
        speed = random.choice([1, 2, 3])
        direction = random.choice([-1, 1])
        rect = pygame.Rect(x, y, OBSTACLE_WIDTH, OBSTACLE_HEIGHT)
        obstacles.append({'rect': rect, 'speed': speed, 'dir': direction})
    return obstacles


def draw_obstacle(surface, obstacle):
    rect = obstacle['rect']
    pygame.draw.rect(surface, (255, 102, 102), rect)
    pygame.draw.circle(surface, (255, 195, 0), rect.center, 8)
    pygame.draw.line(surface, DARK_BLUE, (rect.left + 10, rect.top + 10), (rect.right - 10, rect.bottom - 10), 3)
    pygame.draw.line(surface, DARK_BLUE, (rect.left + 10, rect.bottom - 10), (rect.right - 10, rect.top + 10), 3)


def draw_goal(surface):
    goal_rect = pygame.Rect(WIDTH - 120, 80, 90, HEIGHT - 200)
    pygame.draw.rect(surface, (80, 220, 170), goal_rect)
    pygame.draw.polygon(surface, (255, 255, 255), [(goal_rect.centerx - 20, goal_rect.centery - 60),
                                                    (goal_rect.centerx + 20, goal_rect.centery),
                                                    (goal_rect.centerx - 20, goal_rect.centery + 60)])
    return goal_rect


def draw_text(surface, text, size, pos, color=WHITE):
    font = pygame.font.SysFont('Arial', size, bold=True)
    label = font.render(text, True, color)
    rect = label.get_rect(center=pos)
    surface.blit(label, rect)


def main():
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption('As Aventuras da Helena')
    clock = pygame.time.Clock()

    player_img = make_player()
    player_rect = pygame.Rect(80, HEIGHT // 2 - PLAYER_SIZE // 2, PLAYER_SIZE, PLAYER_SIZE)
    obstacles = create_obstacles()
    goal_rect = pygame.Rect(WIDTH - 120, 80, 90, HEIGHT - 200)
    distance = 0
    start_time = pygame.time.get_ticks()
    game_over = False
    win = False

    while True:
        dt = clock.tick(FPS)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN and (game_over or win):
                if event.key == pygame.K_r:
                    player_rect.topleft = (80, HEIGHT // 2 - PLAYER_SIZE // 2)
                    obstacles = create_obstacles()
                    start_time = pygame.time.get_ticks()
                    game_over = False
                    win = False

        keys = pygame.key.get_pressed()
        if not game_over and not win:
            if keys[pygame.K_LEFT] and player_rect.left > 0:
                player_rect.x -= PLAYER_SPEED
            if keys[pygame.K_RIGHT] and player_rect.right < WIDTH:
                player_rect.x += PLAYER_SPEED
            if keys[pygame.K_UP] and player_rect.top > 0:
                player_rect.y -= PLAYER_SPEED
            if keys[pygame.K_DOWN] and player_rect.bottom < HEIGHT:
                player_rect.y += PLAYER_SPEED

            for obs in obstacles:
                obs['rect'].y += obs['speed'] * obs['dir']
                if obs['rect'].top <= 90 or obs['rect'].bottom >= HEIGHT - 90:
                    obs['dir'] *= -1

            for obs in obstacles:
                if player_rect.colliderect(obs['rect']):
                    game_over = True
                    break

            if player_rect.colliderect(goal_rect):
                win = True

            distance = max(0, goal_rect.left - player_rect.right)

        draw_background(screen)
        pygame.draw.rect(screen, (10, 40, 120), goal_rect)
        pygame.draw.rect(screen, (80, 220, 170), goal_rect, 8)
        pygame.draw.polygon(screen, (255, 255, 255), [(goal_rect.centerx - 25, goal_rect.centery),
                                                      (goal_rect.centerx + 15, goal_rect.centery - 30),
                                                      (goal_rect.centerx + 15, goal_rect.centery + 30)])

        for obs in obstacles:
            draw_obstacle(screen, obs)

        screen.blit(player_img, player_rect.topleft)

        draw_text(screen, 'As Aventuras da Helena', 28, (WIDTH // 2, 30), WHITE)
        draw_text(screen, f'Distância: {distance}', 22, (150, 30), WHITE)
        elapsed = (pygame.time.get_ticks() - start_time) // 1000
        draw_text(screen, f'Tempo: {elapsed}s', 22, (WIDTH - 120, 30), WHITE)

        if game_over:
            pygame.draw.rect(screen, (0, 0, 0, 180), (0, 0, WIDTH, HEIGHT), 0)
            draw_text(screen, 'Game Over', 60, (WIDTH // 2, HEIGHT // 2 - 40), (255, 100, 100))
            draw_text(screen, 'Pressione R para tentar novamente', 24, (WIDTH // 2, HEIGHT // 2 + 30), WHITE)
        elif win:
            pygame.draw.rect(screen, (0, 0, 0, 180), (0, 0, WIDTH, HEIGHT), 0)
            draw_text(screen, 'Você venceu!', 60, (WIDTH // 2, HEIGHT // 2 - 40), (120, 255, 170))
            draw_text(screen, f'Tempo final: {elapsed}s', 24, (WIDTH // 2, HEIGHT // 2 + 10), WHITE)
            draw_text(screen, 'Pressione R para jogar novamente', 24, (WIDTH // 2, HEIGHT // 2 + 50), WHITE)

        pygame.display.flip()


if __name__ == '__main__':
    main()
