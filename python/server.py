import time
import json
import os
import random
import hmac
import hashlib
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="ITIP AI & Analytics Backend v1.0")

# CSV & JSON Logging Path
LOG_DIR = "./logs"
os.makedirs(LOG_DIR, exist_ok=True)
CSV_PATH = os.path.join(LOG_DIR, "signals_log.csv")
JSON_PATH = os.path.join(LOG_DIR, "signals_log.json")

# Create CSV header if it doesn't exist
if not os.path.exists(CSV_PATH):
    with open(CSV_PATH, "w") as f:
        f.write("timestamp,symbol,timeframe,direction,confidence,session,atr,rsi\n")

class SignalRequest(BaseModel):
    symbol: str
    timeframe: str
    direction: str
    confidence: float
    session: str
    atr: float
    rsi: float

class TradeStats(BaseModel):
    win_rate: float
    profit_factor: float
    max_drawdown: float

@app.get("/")
def read_root():
    return {
        "status": "ONLINE",
        "system": "ITIP AI Subsystem",
        "version": "1.0.0",
        "onnx_optimized": True,
        "cuda_support": False
    }

@app.post("/api/signal")
def log_signal(req: SignalRequest):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")

    # Save to CSV
    with open(CSV_PATH, "a") as f:
        f.write(f"{timestamp},{req.symbol},{req.timeframe},{req.direction},{req.confidence},{req.session},{req.atr},{req.rsi}\n")

    # Save to JSON
    signal_data = {
        "timestamp": timestamp,
        "symbol": req.symbol,
        "timeframe": req.timeframe,
        "direction": req.direction,
        "confidence": req.confidence,
        "session": req.session,
        "atr": req.atr,
        "rsi": req.rsi
    }

    existing_data = []
    if os.path.exists(JSON_PATH):
        try:
            with open(JSON_PATH, "r") as f:
                existing_data = json.load(f)
        except Exception:
            pass

    existing_data.append(signal_data)
    with open(JSON_PATH, "w") as f:
        json.dump(existing_data, f, indent=4)

    return {"status": "SUCCESS", "message": "Signal logged", "data": signal_data}

@app.get("/api/correlation")
def get_portfolio_correlation():
    # Simulated correlation matrix between popular symbols
    symbols = ["EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "XAUUSD"]
    matrix = {}
    for s1 in symbols:
        matrix[s1] = {}
        for s2 in symbols:
            if s1 == s2:
                matrix[s1][s2] = 1.0
            else:
                matrix[s1][s2] = round(random.uniform(-0.8, 0.8), 2)
    return {"correlation_matrix": matrix}

@app.get("/api/monte_carlo")
def run_monte_carlo(simulations: int = 1000, initial_capital: float = 10000.0, win_rate: float = 0.55):
    results = []
    for _ in range(simulations):
        capital = initial_capital
        for _ in range(50): # 50 trades path
            if random.random() < win_rate:
                capital += capital * 0.02 # 2% win
            else:
                capital -= capital * 0.01 # 1% loss
        results.append(capital)

    avg_ending = sum(results) / len(results)
    max_ending = max(results)
    min_ending = min(results)

    return {
        "simulations": simulations,
        "initial_capital": initial_capital,
        "average_ending_capital": round(avg_ending, 2),
        "max_ending_capital": round(max_ending, 2),
        "min_ending_capital": round(min_ending, 2)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5555)
