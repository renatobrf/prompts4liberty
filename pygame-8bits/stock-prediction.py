import pygame
import random
import sys
from collections import deque
import time

# -----------------------------
# Config
# -----------------------------
WIDTH, HEIGHT = 800, 600
FPS = 60
TITLE = "8-Bit Stock Predictor"

# Colors (8-bit palette)
SKY = (20, 24, 82)
GROUND = (30, 30, 30)
WHITE = (240, 240, 240)
GREEN = (80, 220, 120)
RED = (220, 70, 70)
YELLOW = (250, 220, 90)
BLUE = (80, 160, 255)
GRAY = (120, 120, 120)
DARK_GRAY = (60, 60, 60)
CHART_BG = (15, 15, 40)

# Game settings
PREDICTION_TIME = 5  # seconds
CHART_POINTS = 100
PRICE_VOLATILITY = 0.02
TREND_CHANGE_CHANCE = 0.01

# -----------------------------
# Init
# -----------------------------
pygame.init()
pygame.display.set_caption(TITLE)
screen = pygame.display.set_mode((WIDTH, HEIGHT))
clock = pygame.time.Clock()

font_small = pygame.font.SysFont("consolas", 18, bold=True)
font_medium = pygame.font.SysFont("consolas", 24, bold=True)
font_big = pygame.font.SysFont("consolas", 36, bold=True)

# -----------------------------
# Helpers
# -----------------------------
def draw_text(surface, text, font, color, x, y, center=False):
    img = font.render(text, True, color)
    if center:
        rect = img.get_rect(center=(x, y))
        surface.blit(img, rect)
    else:
        surface.blit(img, (x, y))

def draw_button(surface, text, x, y, w, h, color, hover=False):
    """Draw a retro-style button"""
    border_color = WHITE if hover else GRAY
    pygame.draw.rect(surface, color, (x, y, w, h))
    pygame.draw.rect(surface, border_color, (x, y, w, h), 3)
    draw_text(surface, text, font_medium, WHITE, x + w // 2, y + h // 2, center=True)

# -----------------------------
# Stock Price Generator
# -----------------------------
class StockPrice:
    def __init__(self):
        self.base_price = 100.0
        self.current_price = self.base_price
        self.trend = random.choice([-1, 1])  # -1 for down, 1 for up
        self.history = deque(maxlen=CHART_POINTS)
        
        # Initialize with some history
        for _ in range(CHART_POINTS):
            self.history.append(self.current_price)
    
    def update(self):
        """Update stock price with random walk and trend"""
        # Random chance to change trend
        if random.random() < TREND_CHANGE_CHANCE:
            self.trend *= -1
        
        # Calculate price change
        random_change = random.uniform(-PRICE_VOLATILITY, PRICE_VOLATILITY)
        trend_influence = self.trend * PRICE_VOLATILITY * 0.5
        
        change = random_change + trend_influence
        self.current_price *= (1 + change)
        
        # Keep price in reasonable range
        self.current_price = max(50, min(200, self.current_price))
        
        self.history.append(self.current_price)
    
    def get_trend_direction(self):
        """Get actual trend direction for the next period"""
        return "UP" if self.trend > 0 else "DOWN"

# -----------------------------
# Game State
# -----------------------------
class Game:
    def __init__(self):
        self.stock = StockPrice()
        self.score = 0
        self.streak = 0
        self.total_predictions = 0
        self.correct_predictions = 0
        
        self.state = "WAITING"  # WAITING, PREDICTING, RESULT
        self.prediction = None
        self.prediction_start_time = 0
        self.prediction_start_price = 0
        self.result_timer = 0
        
        self.chart_rect = pygame.Rect(50, 100, 700, 300)
        self.up_button = pygame.Rect(200, 450, 150, 60)
        self.down_button = pygame.Rect(450, 450, 150, 60)
        
        self.mouse_pos = (0, 0)
    
    def update(self):
        """Update game state"""
        self.stock.update()
        
        if self.state == "PREDICTING":
            elapsed = time.time() - self.prediction_start_time
            if elapsed >= PREDICTION_TIME:
                self.check_prediction()
        
        elif self.state == "RESULT":
            self.result_timer -= 1
            if self.result_timer <= 0:
                self.state = "WAITING"
    
    def make_prediction(self, direction):
        """Player makes a prediction"""
        if self.state == "WAITING":
            self.prediction = direction
            self.prediction_start_time = time.time()
            self.prediction_start_price = self.stock.current_price
            self.state = "PREDICTING"
    
    def check_prediction(self):
        """Check if prediction was correct"""
        price_change = self.stock.current_price - self.prediction_start_price
        actual_direction = "UP" if price_change > 0 else "DOWN"
        
        self.total_predictions += 1
        
        if self.prediction == actual_direction:
            self.correct_predictions += 1
            points = 10 + (self.streak * 2)
            self.score += points
            self.streak += 1
            self.result = "CORRECT!"
            self.result_color = GREEN
        else:
            self.streak = 0
            self.result = "WRONG!"
            self.result_color = RED
        
        self.state = "RESULT"
        self.result_timer = 120  # 2 seconds at 60 FPS
    
    def draw_chart(self, surface):
        """Draw the stock price chart"""
        # Background
        pygame.draw.rect(surface, CHART_BG, self.chart_rect)
        pygame.draw.rect(surface, WHITE, self.chart_rect, 2)
        
        # Grid lines
        for i in range(5):
            y = self.chart_rect.top + (self.chart_rect.height // 4) * i
            pygame.draw.line(surface, DARK_GRAY, 
                           (self.chart_rect.left, y), 
                           (self.chart_rect.right, y), 1)
        
        # Draw price line
        if len(self.stock.history) > 1:
            points = []
            prices = list(self.stock.history)
            min_price = min(prices)
            max_price = max(prices)
            price_range = max_price - min_price if max_price != min_price else 1
            
            for i, price in enumerate(prices):
                x = self.chart_rect.left + (i * self.chart_rect.width // CHART_POINTS)
                # Normalize price to chart height
                normalized = (price - min_price) / price_range
                y = self.chart_rect.bottom - (normalized * (self.chart_rect.height - 20)) - 10
                points.append((x, y))
            
            # Draw line with gradient effect
            for i in range(len(points) - 1):
                color = GREEN if prices[i+1] > prices[i] else RED
                pygame.draw.line(surface, color, points[i], points[i+1], 2)
            
            # Draw current price point
            if points:
                pygame.draw.circle(surface, YELLOW, (int(points[-1][0]), int(points[-1][1])), 5)
        
        # Price labels
        draw_text(surface, f"${self.stock.current_price:.2f}", font_medium, YELLOW, 
                 self.chart_rect.right - 100, self.chart_rect.top + 10)
    
    def draw_ui(self, surface):
        """Draw UI elements"""
        # Title bar
        pygame.draw.rect(surface, GROUND, (0, 0, WIDTH, 80))
        draw_text(surface, "8-BIT STOCK PREDICTOR", font_big, WHITE, WIDTH // 2, 25, center=True)
        draw_text(surface, f"Score: {self.score}", font_medium, YELLOW, 20, 50)
        draw_text(surface, f"Streak: {self.streak}", font_medium, GREEN, 200, 50)
        
        if self.total_predictions > 0:
            accuracy = (self.correct_predictions / self.total_predictions) * 100
            draw_text(surface, f"Accuracy: {accuracy:.1f}%", font_medium, BLUE, 400, 50)
        
        # Chart
        self.draw_chart(surface)
        
        # Prediction timer
        if self.state == "PREDICTING":
            elapsed = time.time() - self.prediction_start_time
            remaining = max(0, PREDICTION_TIME - elapsed)
            draw_text(surface, f"Time: {remaining:.1f}s", font_big, YELLOW, 
                     WIDTH // 2, self.chart_rect.bottom + 30, center=True)
            
            # Show prediction
            pred_color = GREEN if self.prediction == "UP" else RED
            draw_text(surface, f"Predicting: {self.prediction}", font_medium, pred_color,
                     WIDTH // 2, self.chart_rect.bottom + 70, center=True)
        
        # Result display
        elif self.state == "RESULT":
            draw_text(surface, self.result, font_big, self.result_color,
                     WIDTH // 2, self.chart_rect.bottom + 50, center=True)
        
        # Buttons
        if self.state == "WAITING":
            up_hover = self.up_button.collidepoint(self.mouse_pos)
            down_hover = self.down_button.collidepoint(self.mouse_pos)
            
            draw_button(surface, "▲ UP", self.up_button.x, self.up_button.y,
                       self.up_button.width, self.up_button.height, GREEN, up_hover)
            draw_button(surface, "▼ DOWN", self.down_button.x, self.down_button.y,
                       self.down_button.width, self.down_button.height, RED, down_hover)
            
            draw_text(surface, "Predict the price in 5 seconds!", font_small, WHITE,
                     WIDTH // 2, 420, center=True)
        
        # Instructions
        draw_text(surface, "Click UP or DOWN to predict | ESC to quit", font_small, GRAY,
                 WIDTH // 2, HEIGHT - 20, center=True)

# -----------------------------
# Main Game Loop
# -----------------------------
def main():
    game = Game()
    running = True
    
    while running:
        clock.tick(FPS)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
            
            elif event.type == pygame.MOUSEMOTION:
                game.mouse_pos = event.pos
            
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # Left click
                    if game.state == "WAITING":
                        if game.up_button.collidepoint(event.pos):
                            game.make_prediction("UP")
                        elif game.down_button.collidepoint(event.pos):
                            game.make_prediction("DOWN")
        
        # Update
        game.update()
        
        # Draw
        screen.fill(SKY)
        game.draw_ui(screen)
        
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

# -----------------------------
# Entry Point
# -----------------------------
if __name__ == "__main__":
    main()

# Made with Bob - Your AI Software Engineer