# Regex in Log Analysis — Practical Wins

Regex is your **fastest, cheapest, and most deterministic** tool in a log pipeline. Here's how to use it effectively.

---

## 🧱 Anatomy of a Log Line

Most log lines follow predictable patterns:

```
2024-01-15 14:32:01.123 [ERROR] [order-service] OrderProcessor - Payment failed for orderId=98234 userId=441 amount=129.99
│                        │       │               │               │
timestamp               level   service         class           message + context
```

Regex works because **structure is consistent**. Once you learn your log format, you can extract anything.

---

## 1. Basic Pattern Building Blocks

These are the pieces you'll combine constantly:

```python
import re

# Timestamps
TIMESTAMP   = r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}'

# Log levels
LOG_LEVEL   = r'\b(TRACE|DEBUG|INFO|WARN|WARNING|ERROR|FATAL|CRITICAL)\b'

# Common identifiers
ORDER_ID    = r'orderId=(\d+)'
USER_ID     = r'userId=(\w+)'
HTTP_STATUS = r'\b([45]\d{2})\b'          # 4xx and 5xx only
IP_ADDRESS  = r'\b(\d{1,3}(?:\.\d{1,3}){3})\b'
DURATION_MS = r'duration[=:](\d+)ms'
EXCEPTION   = r'([A-Z]\w+Exception|[A-Z]\w+Error)'

# HTTP method + path
HTTP_REQ    = r'(GET|POST|PUT|DELETE|PATCH)\s+(/[\w/\-\.?=&%]+)'
```

---

## 2. The Three Big Win Categories

### ✅ Win #1 — Instant Noise Elimination

Drop lines you never need. This runs on every line before anything else:

```python
NOISE_PATTERNS = re.compile("|".join([
    r'GET /(health|ping|ready|alive|metrics)',   # health checks
    r'\.(js|css|png|ico|woff|svg|map)\s+200',   # static assets
    r'HikariPool.*connection',                   # DB pool chatter
    r'Tomcat.*NIO.*Poller',                      # container internals
    r'scheduling-\d+.*INFO',                     # cron noise
    r'actuator/(health|info|prometheus)',         # Spring Boot actuator
    r'ELB-HealthChecker',                        # AWS LB probes
]), re.IGNORECASE)

def is_noise(line: str) -> bool:
    return bool(NOISE_PATTERNS.search(line))
```

> **Win:** Eliminates 60–80% of log volume in most systems before any expensive processing.

---

### ✅ Win #2 — Hard Signal Extraction

Capture lines that are always relevant without needing AI:

```python
CRITICAL_PATTERNS = re.compile("|".join([
    r'\b(ERROR|FATAL|CRITICAL)\b',
    r'(Exception|Traceback|NullPointer|StackOverflow)',
    r'HTTP [45]\d{2}',
    r'(timeout|timed.?out)',
    r'(refused|unreachable|connection.?reset)',
    r'(OutOfMemory|OOMKilled)',
    r'(deadlock|rollback|transaction.?failed)',
]), re.IGNORECASE)

def is_critical(line: str) -> bool:
    return bool(CRITICAL_PATTERNS.search(line))
```

---

### ✅ Win #3 — Structured Data Extraction

Turn unstructured lines into queryable data:

```python
LOG_PATTERN = re.compile(
    r'(?P<timestamp>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})'
    r'.*?(?P<level>TRACE|DEBUG|INFO|WARN|ERROR|FATAL)'
    r'.*?\[(?P<service>[\w\-]+)\]'
    r'.*?(?P<message>.+)'
)

def parse_log_line(line: str) -> dict | None:
    match = LOG_PATTERN.search(line)
    if not match:
        return None
    
    data = match.groupdict()
    
    # Extract embedded key=value pairs dynamically
    data['context'] = dict(re.findall(r'(\w+)=([^\s,]+)', line))
    
    return data

# Input:
# "2024-01-15 14:32:01 ERROR [payment-service] Charge failed orderId=982 amount=99.99 retries=3"

# Output:
# {
#   'timestamp': '2024-01-15 14:32:01',
#   'level': 'ERROR',
#   'service': 'payment-service',
#   'message': 'Charge failed orderId=982 amount=99.99 retries=3',
#   'context': {'orderId': '982', 'amount': '99.99', 'retries': '3'}
# }
```

---

## 3. Building a Tiered Filter Pipeline

Combine everything into a clean pipeline:

```python
class LogFilter:
    def __init__(self):
        self.noise    = re.compile(r'GET /(health|ping)|\.js\s+200|actuator', re.I)
        self.critical = re.compile(r'ERROR|FATAL|Exception|5\d{2}', re.I)
        self.business = re.compile(
            r'(order|payment|checkout|cart|invoice|refund|auth|login|signup)',
            re.I
        )

    def classify(self, line: str) -> str:
        if self.noise.search(line):    return "DISCARD"
        if self.critical.search(line): return "CRITICAL"
        if self.business.search(line): return "BUSINESS"
        return "AMBIGUOUS"  # → send to LLM

filter = LogFilter()

results = {"DISCARD": 0, "CRITICAL": [], "BUSINESS": [], "AMBIGUOUS": []}

with open("app.log") as f:
    for line in f:
        label = filter.classify(line.strip())
        if label == "DISCARD":
            results["DISCARD"] += 1
        else:
            results[label].append(line.strip())
```

---

## 4. Real-World Patterns Cheat Sheet

```python
PATTERNS = {
    # Security
    "sql_injection":   r"('--|;--|OR\s+1=1|UNION\s+SELECT)",
    "path_traversal":  r"\.\./|\.\.\\",
    "brute_force":     r"(failed login|invalid password).{0,50}(\d+\s+times|attempt)",

    # Performance
    "slow_query":      r"(slow query|query took|execution time)[^\d]*(\d+)\s*ms",
    "high_latency":    r"latency[=: ]*(\d{4,})\s*ms",   # 1000ms+
    "timeout":         r"(read|connect|socket).{0,20}timeout",

    # Business
    "payment_fail":    r"(payment|charge|transaction).{0,30}(fail|declin|error)",
    "order_event":     r"order(Id)?[=: ]*(\d+).{0,50}(creat|updat|cancel|ship)",
    "user_action":     r"user(Id)?[=: ]*(\w+).{0,50}(login|logout|register|delete)",

    # Infrastructure
    "oom":             r"(OutOfMemoryError|OOMKilled|Cannot allocate memory)",
    "disk_full":       r"(No space left|disk full|ENOSPC)",
    "cert_expiry":     r"(certificate|cert).{0,30}(expir|invalid|untrusted)",
}
```

---

## 5. Measuring Your Wins

Always benchmark your filter effectiveness:

```python
def analyze_filter_impact(log_file: str, filter: LogFilter):
    total = critical = business = ambiguous = discarded = 0
    
    with open(log_file) as f:
        for line in f:
            total += 1
            label = filter.classify(line)
            if label == "DISCARD":    discarded += 1
            elif label == "CRITICAL": critical += 1
            elif label == "BUSINESS": business += 1
            else:                     ambiguous += 1
    
    kept = total - discarded
    print(f"Total lines    : {total:,}")
    print(f"Discarded      : {discarded:,}  ({discarded/total:.0%})")
    print(f"Critical       : {critical:,}")
    print(f"Business       : {business:,}")
    print(f"Ambiguous→LLM  : {ambiguous:,}  (LLM cost surface)")
    print(f"Noise reduction: {discarded/total:.0%}")
```

---

## Summary

| Technique                | What it does                                      | Speed       | Cost     |
|--------------------------|---------------------------------------------------|-------------|----------|
| Noise regex              | Drops health checks, static assets, infra chatter | ⚡ Instant  | Free     |
| Critical regex           | Guarantees ERROR/FATAL always captured            | ⚡ Instant  | Free     |
| Business keyword regex   | Targets domain-specific events                    | ⚡ Instant  | Free     |
| Named group parsing      | Turns log lines into structured dicts             | ⚡ Fast     | Free     |
| key=value extraction     | Pulls embedded context dynamically                | ⚡ Fast     | Free     |
| LLM filter               | Handles ambiguous/complex cases                   | 🐢 Slow    | 💰 Paid  |

> **The golden rule:** Regex handles the predictable **80%**. LLM handles the uncertain **20%**. Never send noise to the LLM.
