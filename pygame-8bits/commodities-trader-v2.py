import pygame
import random
import sys
from collections import deque

# -----------------------------
# Config
# -----------------------------
WIDTH, HEIGHT = 1000, 650
FPS = 60
TITLE = "8-Bit Agricultural Commodities Trader"

# Colors (8-bit palette)
BG_COLOR = (15, 15, 25)
PANEL_COLOR = (25, 25, 40)
HEADER_COLOR = (30, 30, 30)
WHITE = (240, 240, 240)
GREEN = (80, 220, 120)
RED = (220, 70, 70)
YELLOW = (250, 220, 90)
BLUE = (80, 160, 255)
GRAY = (120, 120, 120)
DARK_GRAY = (60, 60, 70)
ORANGE = (255, 165, 0)

# Game settings
INITIAL_BALANCE = 10000
PRICE_UPDATE_INTERVAL = 30  # frames between price updates
HISTORY_LENGTH = 50

# Commodity definitions with initial prices and volatility
COMMODITIES = {
    "Soybeans": {"price": 50, "volatility": 0.03, "color": (139, 90, 43), "unit": "bu"},
    "Corn": {"price": 35, "volatility": 0.025, "color": (255, 215, 0), "unit": "bu"},
    "Rice": {"price": 45, "volatility": 0.028, "color": (245, 245, 220), "unit": "cwt"},
    "Beans": {"price": 40, "volatility": 0.032, "color": (101, 67, 33), "unit": "bu"},
    "Wheat": {"price": 55, "volatility": 0.027, "color": (210, 180, 140), "unit": "bu"},
    "Cotton": {"price": 70, "volatility": 0.035, "color": (248, 248, 255), "unit": "lb"},
    "Milk": {"price": 20, "volatility": 0.02, "color": (255, 253, 208), "unit": "cwt"},
    "Eggs": {"price": 15, "volatility": 0.04, "color": (255, 235, 205), "unit": "doz"}
}

# -----------------------------
# Init
# -----------------------------
pygame.init()
pygame.display.set_caption(TITLE)
screen = pygame.display.set_mode((WIDTH, HEIGHT))
clock = pygame.time.Clock()

font_small = pygame.font.SysFont("consolas", 14, bold=True)
font_medium = pygame.font.SysFont("consolas", 18, bold=True)
font_large = pygame.font.SysFont("consolas", 24, bold=True)
font_title = pygame.font.SysFont("consolas", 28, bold=True)

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

def draw_button(surface, text, x, y, w, h, color, hover=False, enabled=True):
    if not enabled:
        color = DARK_GRAY
    border_color = WHITE if hover and enabled else GRAY
    pygame.draw.rect(surface, color, (x, y, w, h))
    pygame.draw.rect(surface, border_color, (x, y, w, h), 2)
    text_color = WHITE if enabled else GRAY
    draw_text(surface, text, font_medium, text_color, x + w // 2, y + h // 2 - 9, "center")

def is_mouse_over(x, y, w, h, mouse_pos):
    return x <= mouse_pos[0] <= x + w and y <= mouse_pos[1] <= y + h

# -----------------------------
# Commodity class
# -----------------------------
class Commodity:
    def __init__(self, name, initial_price, volatility, color, unit):
        self.name = name
        self.base_price = initial_price
        self.current_price = initial_price
        self.volatility = volatility
        self.color = color
        self.unit = unit
        self.price_history = deque([initial_price] * HISTORY_LENGTH, maxlen=HISTORY_LENGTH)
        self.trend = random.choice([-1, 0, 1])  # -1 down, 0 neutral, 1 up
        self.trend_strength = random.uniform(0.3, 0.7)
        
    def update_price(self):
        # Random chance to change trend
        if random.random() < 0.02:
            self.trend = random.choice([-1, 0, 1])
            self.trend_strength = random.uniform(0.3, 0.7)
        
        # Calculate price change
        random_change = random.uniform(-self.volatility, self.volatility)
        trend_influence = self.trend * self.volatility * self.trend_strength
        
        change = random_change + trend_influence
        self.current_price *= (1 + change)
        
        # Keep price in reasonable range (50% to 200% of base)
        min_price = self.base_price * 0.5
        max_price = self.base_price * 2.0
        self.current_price = max(min_price, min(max_price, self.current_price))
        
        self.price_history.append(self.current_price)
    
    def get_price_change(self):
        if len(self.price_history) >= 2:
            return self.current_price - self.price_history[-2]
        return 0
    
    def get_price_change_percent(self):
        if len(self.price_history) >= 2 and self.price_history[-2] != 0:
            return ((self.current_price - self.price_history[-2]) / self.price_history[-2]) * 100
        return 0

# -----------------------------
# Portfolio class
# -----------------------------
class Portfolio:
    def __init__(self, initial_balance):
        self.balance = initial_balance
        self.initial_balance = initial_balance
        self.holdings = {name: 0 for name in COMMODITIES.keys()}
        self.transactions = deque(maxlen=10)
        
    def buy(self, commodity, quantity):
        cost = commodity.current_price * quantity
        if cost <= self.balance:
            self.balance -= cost
            self.holdings[commodity.name] += quantity
            self.transactions.append(f"BUY {quantity} {commodity.name} @ ${commodity.current_price:.2f}")
            return True
        return False
    
    def sell(self, commodity, quantity):
        if self.holdings[commodity.name] >= quantity:
            revenue = commodity.current_price * quantity
            self.balance += revenue
            self.holdings[commodity.name] -= quantity
            self.transactions.append(f"SELL {quantity} {commodity.name} @ ${commodity.current_price:.2f}")
            return True
        return False
    
    def get_holdings_value(self, commodities):
        total = 0
        for name, quantity in self.holdings.items():
            if quantity > 0:
                total += commodities[name].current_price * quantity
        return total
    
    def get_total_value(self, commodities):
        return self.balance + self.get_holdings_value(commodities)
    
    def get_profit_loss(self, commodities):
        return self.get_total_value(commodities) - self.initial_balance

# -----------------------------
# UI Components
# -----------------------------
def draw_mini_chart(surface, commodity, x, y, width, height):
    """Draw a small price history chart"""
    pygame.draw.rect(surface, (10, 10, 20), (x, y, width, height))
    pygame.draw.rect(surface, GRAY, (x, y, width, height), 1)
    
    if len(commodity.price_history) < 2:
        return
    
    prices = list(commodity.price_history)
    min_price = min(prices)
    max_price = max(prices)
    price_range = max_price - min_price if max_price != min_price else 1
    
    points = []
    for i, price in enumerate(prices):
        px = x + (i * width // HISTORY_LENGTH)
        normalized = (price - min_price) / price_range
        py = y + height - (normalized * (height - 4)) - 2
        points.append((px, py))
    
    if len(points) > 1:
        for i in range(len(points) - 1):
            color = GREEN if prices[i+1] >= prices[i] else RED
            pygame.draw.line(surface, color, points[i], points[i+1], 1)

def draw_commodity_row(surface, commodity, portfolio, y_pos, mouse_pos, selected):
    """Draw a single commodity trading row"""
    x_start = 20
    row_height = 65
    
    # Background
    bg_color = (35, 35, 50) if selected else PANEL_COLOR
    pygame.draw.rect(surface, bg_color, (x_start, y_pos, 960, row_height))
    pygame.draw.rect(surface, GRAY, (x_start, y_pos, 960, row_height), 1)
    
    # Commodity name and color indicator
    pygame.draw.rect(surface, commodity.color, (x_start + 10, y_pos + 10, 15, 45))
    draw_text(surface, commodity.name, font_large, WHITE, x_start + 35, y_pos + 20)
    
    # Current price
    price_change = commodity.get_price_change()
    price_color = GREEN if price_change >= 0 else RED
    draw_text(surface, f"${commodity.current_price:.2f}", font_large, price_color, x_start + 180, y_pos + 20)
    
    # Price change
    change_pct = commodity.get_price_change_percent()
    change_text = f"{'+' if price_change >= 0 else ''}{price_change:.2f} ({'+' if change_pct >= 0 else ''}{change_pct:.1f}%)"
    draw_text(surface, change_text, font_small, price_color, x_start + 180, y_pos + 42)
    
    # Mini chart
    draw_mini_chart(surface, commodity, x_start + 320, y_pos + 10, 120, 45)
    
    # Holdings
    holdings = portfolio.holdings[commodity.name]
    holdings_value = holdings * commodity.current_price
    draw_text(surface, f"Holdings: {holdings} {commodity.unit}", font_medium, WHITE, x_start + 460, y_pos + 17)
    draw_text(surface, f"Value: ${holdings_value:.2f}", font_small, BLUE, x_start + 460, y_pos + 38)
    
    # Buy/Sell buttons
    buy_btn = (x_start + 680, y_pos + 12, 80, 40)
    sell_btn = (x_start + 770, y_pos + 12, 80, 40)
    amount_btn = (x_start + 860, y_pos + 12, 80, 40)
    
    can_buy = portfolio.balance >= commodity.current_price
    can_sell = holdings > 0
    
    buy_hover = is_mouse_over(buy_btn[0], buy_btn[1], buy_btn[2], buy_btn[3], mouse_pos) and can_buy
    sell_hover = is_mouse_over(sell_btn[0], sell_btn[1], sell_btn[2], sell_btn[3], mouse_pos) and can_sell
    amount_hover = is_mouse_over(amount_btn[0], amount_btn[1], amount_btn[2], amount_btn[3], mouse_pos)
    
    draw_button(surface, "BUY", buy_btn[0], buy_btn[1], buy_btn[2], buy_btn[3], GREEN, buy_hover, can_buy)
    draw_button(surface, "SELL", sell_btn[0], sell_btn[1], sell_btn[2], sell_btn[3], RED, sell_hover, can_sell)
    draw_button(surface, "x10", amount_btn[0], amount_btn[1], amount_btn[2], amount_btn[3], BLUE, amount_hover, True)
    
    return {
        'buy_btn': buy_btn,
        'sell_btn': sell_btn,
        'amount_btn': amount_btn,
        'commodity': commodity
    }

# -----------------------------
# Game State
# -----------------------------
commodities = {name: Commodity(name, data["price"], data["volatility"], data["color"], data["unit"]) 
               for name, data in COMMODITIES.items()}
portfolio = Portfolio(INITIAL_BALANCE)

frame_count = 0
selected_commodity = None
trade_amount = 1
message = ""
message_timer = 0
message_color = WHITE

# -----------------------------
# Main Loop
# -----------------------------
running = True
while running:
    clock.tick(FPS)
    frame_count += 1
    mouse_pos = pygame.mouse.get_pos()
    
    # Update prices periodically
    if frame_count % PRICE_UPDATE_INTERVAL == 0:
        for commodity in commodities.values():
            commodity.update_price()
    
    # Update message timer
    if message_timer > 0:
        message_timer -= 1
    
    # Event handling
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_1:
                trade_amount = 1
            elif event.key == pygame.K_5:
                trade_amount = 5
            elif event.key == pygame.K_0:
                trade_amount = 10
    
    # Draw
    screen.fill(BG_COLOR)
    
    # Header
    pygame.draw.rect(screen, HEADER_COLOR, (0, 0, WIDTH, 80))
    draw_text(screen, TITLE, font_title, YELLOW, WIDTH // 2, 15, "center")
    
    # Portfolio info
    total_value = portfolio.get_total_value(commodities)
    profit_loss = portfolio.get_profit_loss(commodities)
    profit_color = GREEN if profit_loss >= 0 else RED
    
    draw_text(screen, f"Balance: ${portfolio.balance:.2f}", font_large, WHITE, 20, 45)
    draw_text(screen, f"Holdings: ${portfolio.get_holdings_value(commodities):.2f}", font_large, BLUE, 280, 45)
    draw_text(screen, f"Total: ${total_value:.2f}", font_large, YELLOW, 560, 45)
    draw_text(screen, f"P/L: ${profit_loss:.2f} ({(profit_loss/portfolio.initial_balance*100):.1f}%)", 
              font_large, profit_color, 780, 45)
    
    # Commodity rows
    y_offset = 100
    row_spacing = 68
    buttons_data = []
    
    for i, commodity in enumerate(commodities.values()):
        is_selected = selected_commodity == commodity.name
        row_data = draw_commodity_row(screen, commodity, portfolio, y_offset + i * row_spacing, 
                                     mouse_pos, is_selected)
        buttons_data.append(row_data)
    
    # Handle clicks
    if pygame.mouse.get_pressed()[0]:
        for row_data in buttons_data:
            commodity = row_data['commodity']
            buy_btn = row_data['buy_btn']
            sell_btn = row_data['sell_btn']
            amount_btn = row_data['amount_btn']
            
            if is_mouse_over(buy_btn[0], buy_btn[1], buy_btn[2], buy_btn[3], mouse_pos):
                if portfolio.buy(commodity, trade_amount):
                    message = f"Bought {trade_amount} {commodity.name}!"
                    message_color = GREEN
                    message_timer = 90
                else:
                    message = "Insufficient balance!"
                    message_color = RED
                    message_timer = 90
                pygame.time.wait(200)  # Prevent multiple clicks
            
            elif is_mouse_over(sell_btn[0], sell_btn[1], sell_btn[2], sell_btn[3], mouse_pos):
                if portfolio.sell(commodity, trade_amount):
                    message = f"Sold {trade_amount} {commodity.name}!"
                    message_color = GREEN
                    message_timer = 90
                else:
                    message = "Not enough holdings!"
                    message_color = RED
                    message_timer = 90
                pygame.time.wait(200)
            
            elif is_mouse_over(amount_btn[0], amount_btn[1], amount_btn[2], amount_btn[3], mouse_pos):
                trade_amount = 10 if trade_amount == 1 else 1
                message = f"Trade amount: {trade_amount}"
                message_color = BLUE
                message_timer = 60
                pygame.time.wait(200)
    
    # Message display
    if message_timer > 0:
        draw_text(screen, message, font_large, message_color, WIDTH // 2, 615, "center")
    
    # Instructions
    draw_text(screen, f"Trade Amount: {trade_amount} | Press 1/0 to change | ESC to quit", 
              font_small, GRAY, WIDTH // 2, 635, "center")
    
    pygame.display.flip()

pygame.quit()
sys.exit()

# Made with Bob - Your AI Software Engineer