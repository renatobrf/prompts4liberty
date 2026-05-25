import pygame
import random
import sys
from datetime import datetime

# -----------------------------
# Config
# -----------------------------
WIDTH, HEIGHT = 900, 600
FPS = 60
TITLE = "8-Bit Stock Trading Simulator"

# Colors
BG_COLOR = (15, 15, 25)
PANEL_COLOR = (25, 25, 40)
CHART_BG = (20, 20, 35)
WHITE = (240, 240, 240)
GREEN = (80, 220, 120)
RED = (220, 70, 70)
YELLOW = (250, 220, 90)
BLUE = (80, 160, 255)
GRAY = (120, 120, 120)
DARK_GRAY = (60, 60, 70)

# Game settings
INITIAL_CASH = 10000
INITIAL_PRICE = 100
PRICE_VOLATILITY = 0.02
CHART_WIDTH = 600
CHART_HEIGHT = 300
MAX_CANDLES = 50

# -----------------------------
# Init
# -----------------------------
pygame.init()
pygame.display.set_caption(TITLE)
screen = pygame.display.set_mode((WIDTH, HEIGHT))
clock = pygame.time.Clock()

font_small = pygame.font.SysFont("consolas", 16, bold=True)
font_medium = pygame.font.SysFont("consolas", 20, bold=True)
font_large = pygame.font.SysFont("consolas", 28, bold=True)

# -----------------------------
# Helpers
# -----------------------------
def draw_text(surface, text, font, color, x, y, align="left"):
    img = font.render(text, True, color)
    if align == "center":
        x -= img.get_width() // 2
    elif align == "right":
        x -= img.get_width()
    surface.blit(img, (x, y))

def draw_button(surface, text, x, y, w, h, color, hover=False):
    border_color = WHITE if hover else GRAY
    pygame.draw.rect(surface, color, (x, y, w, h))
    pygame.draw.rect(surface, border_color, (x, y, w, h), 2)
    draw_text(surface, text, font_medium, WHITE, x + w // 2, y + h // 2 - 10, "center")

def is_mouse_over(x, y, w, h, mouse_pos):
    return x <= mouse_pos[0] <= x + w and y <= mouse_pos[1] <= y + h

# -----------------------------
# Candlestick class
# -----------------------------
class Candlestick:
    def __init__(self, open_price, close_price, high, low, timestamp):
        self.open = open_price
        self.close = close_price
        self.high = high
        self.low = low
        self.timestamp = timestamp
        self.is_bullish = close_price >= open_price

# -----------------------------
# Stock class
# -----------------------------
class Stock:
    def __init__(self, name, initial_price):
        self.name = name
        self.current_price = initial_price
        self.candles = []
        self.price_history = [initial_price]
        self.tick_count = 0
        self.candle_ticks = 60  # New candle every 60 ticks (1 second at 60 FPS)
        
        # Current candle data
        self.candle_open = initial_price
        self.candle_high = initial_price
        self.candle_low = initial_price
        
    def update(self):
        # Update price with random walk
        change = random.uniform(-PRICE_VOLATILITY, PRICE_VOLATILITY)
        self.current_price *= (1 + change)
        self.current_price = max(10, self.current_price)  # Minimum price
        
        # Update candle data
        self.candle_high = max(self.candle_high, self.current_price)
        self.candle_low = min(self.candle_low, self.current_price)
        
        self.tick_count += 1
        
        # Create new candle every candle_ticks
        if self.tick_count >= self.candle_ticks:
            candle = Candlestick(
                self.candle_open,
                self.current_price,
                self.candle_high,
                self.candle_low,
                datetime.now()
            )
            self.candles.append(candle)
            
            # Keep only last MAX_CANDLES
            if len(self.candles) > MAX_CANDLES:
                self.candles.pop(0)
            
            # Reset for next candle
            self.candle_open = self.current_price
            self.candle_high = self.current_price
            self.candle_low = self.current_price
            self.tick_count = 0
        
        self.price_history.append(self.current_price)
        if len(self.price_history) > 300:
            self.price_history.pop(0)

# -----------------------------
# Portfolio class
# -----------------------------
class Portfolio:
    def __init__(self, initial_cash):
        self.cash = initial_cash
        self.shares = 0
        self.transactions = []
        
    def buy(self, stock, shares):
        cost = stock.current_price * shares
        if cost <= self.cash:
            self.cash -= cost
            self.shares += shares
            self.transactions.append(f"BUY {shares} @ ${stock.current_price:.2f}")
            return True
        return False
    
    def sell(self, stock, shares):
        if shares <= self.shares:
            revenue = stock.current_price * shares
            self.cash += revenue
            self.shares -= shares
            self.transactions.append(f"SELL {shares} @ ${stock.current_price:.2f}")
            return True
        return False
    
    def get_total_value(self, stock):
        return self.cash + (self.shares * stock.current_price)

# -----------------------------
# Chart drawing
# -----------------------------
def draw_candlestick_chart(surface, stock, x, y, width, height):
    # Background
    pygame.draw.rect(surface, CHART_BG, (x, y, width, height))
    pygame.draw.rect(surface, GRAY, (x, y, width, height), 2)
    
    if len(stock.candles) < 2:
        draw_text(surface, "Waiting for data...", font_medium, GRAY, x + width // 2, y + height // 2, "center")
        return
    
    # Calculate price range
    all_highs = [c.high for c in stock.candles]
    all_lows = [c.low for c in stock.candles]
    max_price = max(all_highs)
    min_price = min(all_lows)
    price_range = max_price - min_price
    
    if price_range == 0:
        price_range = 1
    
    # Draw grid lines
    for i in range(5):
        grid_y = y + (height * i // 4)
        pygame.draw.line(surface, DARK_GRAY, (x, grid_y), (x + width, grid_y), 1)
        price_at_line = max_price - (price_range * i / 4)
        draw_text(surface, f"${price_at_line:.1f}", font_small, GRAY, x + 5, grid_y - 8)
    
    # Draw candlesticks
    candle_width = width // MAX_CANDLES
    padding = 2
    
    for i, candle in enumerate(stock.candles):
        candle_x = x + (i * candle_width) + padding
        
        # Calculate positions
        open_y = y + height - ((candle.open - min_price) / price_range * height)
        close_y = y + height - ((candle.close - min_price) / price_range * height)
        high_y = y + height - ((candle.high - min_price) / price_range * height)
        low_y = y + height - ((candle.low - min_price) / price_range * height)
        
        color = GREEN if candle.is_bullish else RED
        
        # Draw wick (high-low line)
        wick_x = candle_x + (candle_width - padding * 2) // 2
        pygame.draw.line(surface, color, (wick_x, high_y), (wick_x, low_y), 1)
        
        # Draw body (open-close rectangle)
        body_height = abs(close_y - open_y)
        if body_height < 2:
            body_height = 2
        body_y = min(open_y, close_y)
        pygame.draw.rect(surface, color, (candle_x, body_y, candle_width - padding * 2, body_height))

# -----------------------------
# Game state
# -----------------------------
stock = Stock("TECH", INITIAL_PRICE)
portfolio = Portfolio(INITIAL_CASH)

# UI state
buy_amount = 1
sell_amount = 1
message = ""
message_timer = 0
message_color = WHITE

# Button positions
buy_btn = (700, 400, 180, 50)
sell_btn = (700, 460, 180, 50)
buy_plus = (820, 350, 30, 30)
buy_minus = (730, 350, 30, 30)
sell_plus = (820, 520, 30, 30)
sell_minus = (730, 520, 30, 30)

# -----------------------------
# Main loop
# -----------------------------
running = True
while running:
    clock.tick(FPS)
    mouse_pos = pygame.mouse.get_pos()
    
    # Event handling
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        
        if event.type == pygame.MOUSEBUTTONDOWN:
            # Buy button
            if is_mouse_over(*buy_btn, mouse_pos):
                if portfolio.buy(stock, buy_amount):
                    message = f"Bought {buy_amount} shares!"
                    message_color = GREEN
                    message_timer = 120
                else:
                    message = "Insufficient funds!"
                    message_color = RED
                    message_timer = 120
            
            # Sell button
            elif is_mouse_over(*sell_btn, mouse_pos):
                if portfolio.sell(stock, sell_amount):
                    message = f"Sold {sell_amount} shares!"
                    message_color = GREEN
                    message_timer = 120
                else:
                    message = "Not enough shares!"
                    message_color = RED
                    message_timer = 120
            
            # Buy amount controls
            elif is_mouse_over(*buy_plus, mouse_pos):
                buy_amount = min(100, buy_amount + 1)
            elif is_mouse_over(*buy_minus, mouse_pos):
                buy_amount = max(1, buy_amount - 1)
            
            # Sell amount controls
            elif is_mouse_over(*sell_plus, mouse_pos):
                sell_amount = min(portfolio.shares, sell_amount + 1)
            elif is_mouse_over(*sell_minus, mouse_pos):
                sell_amount = max(1, sell_amount - 1)
    
    # Update
    stock.update()
    if message_timer > 0:
        message_timer -= 1
    
    # Draw
    screen.fill(BG_COLOR)
    
    # Title
    draw_text(screen, TITLE, font_large, YELLOW, WIDTH // 2, 15, "center")
    
    # Chart
    draw_candlestick_chart(screen, stock, 20, 60, CHART_WIDTH, CHART_HEIGHT)
    
    # Current price display
    price_change = stock.current_price - stock.candles[-1].open if stock.candles else 0
    price_color = GREEN if price_change >= 0 else RED
    draw_text(screen, f"Current Price: ${stock.current_price:.2f}", font_large, price_color, 20, 380)
    change_text = f"Change: {'+' if price_change >= 0 else ''}{price_change:.2f} ({price_change/stock.candles[-1].open*100:.1f}%)" if stock.candles else "Change: --"
    draw_text(screen, change_text, font_medium, price_color, 20, 415)
    
    # Portfolio panel
    pygame.draw.rect(screen, PANEL_COLOR, (650, 60, 230, 300))
    pygame.draw.rect(screen, GRAY, (650, 60, 230, 300), 2)
    
    draw_text(screen, "PORTFOLIO", font_medium, YELLOW, 765, 70, "center")
    draw_text(screen, f"Cash: ${portfolio.cash:.2f}", font_medium, WHITE, 665, 110)
    draw_text(screen, f"Shares: {portfolio.shares}", font_medium, WHITE, 665, 140)
    
    holdings_value = portfolio.shares * stock.current_price
    total_value = portfolio.get_total_value(stock)
    profit = total_value - INITIAL_CASH
    profit_color = GREEN if profit >= 0 else RED
    
    draw_text(screen, f"Holdings: ${holdings_value:.2f}", font_medium, WHITE, 665, 170)
    draw_text(screen, f"Total: ${total_value:.2f}", font_medium, BLUE, 665, 200)
    draw_text(screen, f"P/L: ${profit:.2f}", font_medium, profit_color, 665, 230)
    
    profit_pct = (profit / INITIAL_CASH) * 100
    draw_text(screen, f"({'+' if profit >= 0 else ''}{profit_pct:.1f}%)", font_small, profit_color, 665, 260)
    
    # Trading controls
    draw_text(screen, "BUY", font_medium, WHITE, 765, 320, "center")
    draw_text(screen, f"Amount: {buy_amount}", font_medium, WHITE, 765, 355, "center")
    draw_button(screen, "-", *buy_minus, DARK_GRAY, is_mouse_over(*buy_minus, mouse_pos))
    draw_button(screen, "+", *buy_plus, DARK_GRAY, is_mouse_over(*buy_plus, mouse_pos))
    draw_button(screen, f"BUY ${stock.current_price * buy_amount:.2f}", *buy_btn, GREEN, is_mouse_over(*buy_btn, mouse_pos))
    
    draw_text(screen, "SELL", font_medium, WHITE, 765, 490, "center")
    draw_text(screen, f"Amount: {sell_amount}", font_medium, WHITE, 765, 525, "center")
    draw_button(screen, "-", *sell_minus, DARK_GRAY, is_mouse_over(*sell_minus, mouse_pos))
    draw_button(screen, "+", *sell_plus, DARK_GRAY, is_mouse_over(*sell_plus, mouse_pos))
    draw_button(screen, f"SELL ${stock.current_price * sell_amount:.2f}", *sell_btn, RED, is_mouse_over(*sell_btn, mouse_pos))
    
    # Message display
    if message_timer > 0:
        draw_text(screen, message, font_medium, message_color, WIDTH // 2, 450, "center")
    
    # Recent transactions
    draw_text(screen, "Recent Transactions:", font_small, GRAY, 20, 460)
    for i, transaction in enumerate(portfolio.transactions[-5:]):
        draw_text(screen, transaction, font_small, WHITE, 20, 485 + i * 20)
    
    pygame.display.flip()

pygame.quit()
sys.exit()

# Made with Bob
