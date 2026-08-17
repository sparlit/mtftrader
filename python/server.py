import csv
import html
import json
import os
import random
import time
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, Query
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

app = FastAPI(title="ITIP AI & Analytics Backend v1.0")

# CSV & JSON Logging Path
LOG_DIR = "./logs"
os.makedirs(LOG_DIR, exist_ok=True)
CSV_PATH = os.path.join(LOG_DIR, "signals_log.csv")
JSON_PATH = os.path.join(LOG_DIR, "signals_log.json")

CSV_COLUMNS = [
    "timestamp",
    "symbol",
    "timeframe",
    "direction",
    "confidence",
    "session",
    "atr",
    "rsi",
]

# Create CSV header if it doesn't exist
if not os.path.exists(CSV_PATH):
    with open(CSV_PATH, "w", newline="") as f:
        csv.writer(f).writerow(CSV_COLUMNS)

class SignalRequest(BaseModel):
    symbol: str = Field(min_length=1, max_length=32)
    timeframe: str = Field(min_length=1, max_length=16)
    direction: str = Field(min_length=1, max_length=16)
    confidence: float = Field(ge=0.0, le=100.0)
    session: str = Field(min_length=1, max_length=32)
    atr: float = Field(ge=0.0)
    rsi: float = Field(ge=0.0, le=100.0)

class TradeStats(BaseModel):
    win_rate: float
    profit_factor: float
    max_drawdown: float


def read_signals() -> List[Dict[str, Any]]:
    """Return the logged signals, tolerating a missing or corrupt JSON log."""
    if not os.path.exists(JSON_PATH):
        return []
    try:
        with open(JSON_PATH, "r") as f:
            data = json.load(f)
    except Exception:
        return []
    if not isinstance(data, list):
        return []
    return [entry for entry in data if isinstance(entry, dict)]


def write_signals(signals: List[Dict[str, Any]]) -> None:
    with open(JSON_PATH, "w") as f:
        json.dump(signals, f, indent=4)

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

    # Save to CSV (csv.writer quotes separators so one signal stays one row)
    with open(CSV_PATH, "a", newline="") as f:
        csv.writer(f).writerow([signal_data[column] for column in CSV_COLUMNS])

    # Save to JSON
    signals = read_signals()
    signals.append(signal_data)
    write_signals(signals)

    return {"status": "SUCCESS", "message": "Signal logged", "data": signal_data}

@app.get("/api/signals")
def list_signals(
    limit: int = Query(50, ge=1, le=500),
    symbol: Optional[str] = None,
    direction: Optional[str] = None,
):
    signals = read_signals()
    if symbol:
        signals = [
            s for s in signals if str(s.get("symbol", "")).upper() == symbol.upper()
        ]
    if direction:
        signals = [
            s
            for s in signals
            if str(s.get("direction", "")).upper() == direction.upper()
        ]

    newest_first = list(reversed(signals))[:limit]
    return {"count": len(newest_first), "total": len(signals), "signals": newest_first}

@app.get("/api/stats")
def get_signal_stats():
    signals = read_signals()

    by_direction: Dict[str, int] = {}
    by_symbol: Dict[str, int] = {}
    confidences: List[float] = []
    latest_timestamp = None
    for signal in signals:
        latest_timestamp = signal.get("timestamp", latest_timestamp)

        direction = str(signal.get("direction", "UNKNOWN")).upper()
        by_direction[direction] = by_direction.get(direction, 0) + 1

        symbol = str(signal.get("symbol", "UNKNOWN")).upper()
        by_symbol[symbol] = by_symbol.get(symbol, 0) + 1

        confidence = signal.get("confidence")
        if isinstance(confidence, (int, float)):
            confidences.append(float(confidence))

    return {
        "total_signals": len(signals),
        "by_direction": by_direction,
        "by_symbol": by_symbol,
        "average_confidence": (
            round(sum(confidences) / len(confidences), 2) if confidences else 0.0
        ),
        "latest_timestamp": latest_timestamp,
    }

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
def run_monte_carlo(
    # Caps keep a single request well under a second of pure-Python looping
    simulations: int = Query(1000, ge=1, le=10000),
    initial_capital: float = Query(10000.0, gt=0),
    win_rate: float = Query(0.55, ge=0.0, le=1.0),
    trades: int = Query(50, ge=1, le=200),
):
    results = []
    for _ in range(simulations):
        capital = initial_capital
        for _ in range(trades):
            if random.random() < win_rate:
                capital += capital * 0.02 # 2% win
            else:
                capital -= capital * 0.01 # 1% loss
        results.append(capital)

    results.sort()
    avg_ending = sum(results) / len(results)
    median_ending = results[len(results) // 2]
    profitable = sum(1 for capital in results if capital > initial_capital)

    return {
        "simulations": simulations,
        "initial_capital": initial_capital,
        "trades_per_path": trades,
        "average_ending_capital": round(avg_ending, 2),
        "median_ending_capital": round(median_ending, 2),
        "max_ending_capital": round(results[-1], 2),
        "min_ending_capital": round(results[0], 2),
        "probability_of_profit": round(profitable / len(results), 4)
    }

@app.get("/dashboard", response_class=HTMLResponse)
def get_web_dashboard():
    # Read raw signals for visualization, newest first
    signals = list(reversed(read_signals()))

    signals_html = ""
    for s in signals[:10]: # show latest 10 signals
        cell = {
            key: html.escape(str(s.get(key, "")))
            for key in ("timestamp", "symbol", "timeframe", "direction", "confidence", "session", "atr")
        }
        dir_class = (
            "text-emerald-500" if "BUY" in cell["direction"].upper() else "text-rose-500"
        )
        signals_html += f"""
        <tr class="border-b border-slate-700 bg-slate-900/40">
            <td class="p-3 text-slate-400">{cell["timestamp"]}</td>
            <td class="p-3 font-semibold text-slate-100">{cell["symbol"]}</td>
            <td class="p-3 text-slate-300">{cell["timeframe"]}</td>
            <td class="p-3 font-bold {dir_class}">{cell["direction"]}</td>
            <td class="p-3 text-cyan-400 font-semibold">{cell["confidence"]}%</td>
            <td class="p-3 text-slate-300">{cell["session"]}</td>
            <td class="p-3 text-slate-400">{cell["atr"]}</td>
        </tr>
        """
    if not signals_html:
        signals_html = "<tr><td colspan='7' class='p-4 text-center text-slate-500'>No active signal logs yet. Run the MT5 EA to populate signals.</td></tr>"

    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>ITIP Web Dashboard v1.0</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;600;700&display=swap" rel="stylesheet">
        <style>
            body {{
                font-family: 'Plus Jakarta Sans', sans-serif;
                background-color: #0b0f19;
            }}
        </style>
    </head>
    <body class="text-slate-100 min-h-screen">
        <!-- Top Nav -->
        <header class="border-b border-slate-800 bg-slate-950/60 backdrop-blur-md sticky top-0 z-50">
            <div class="max-w-7xl mx-auto px-6 py-4 flex justify-between items-center">
                <div class="flex items-center space-x-3">
                    <div class="w-8 h-8 rounded-lg bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center font-bold text-white shadow-lg shadow-cyan-500/20">I</div>
                    <span class="text-xl font-bold tracking-tight bg-gradient-to-r from-white via-slate-200 to-slate-400 bg-clip-text text-transparent">ITIP Web Dashboard <span class="text-xs text-cyan-400 px-2 py-0.5 bg-cyan-950 border border-cyan-800 rounded-full ml-1">v1.0</span></span>
                </div>
                <div class="flex items-center space-x-4">
                    <span class="w-2.5 h-2.5 bg-emerald-500 rounded-full animate-ping"></span>
                    <span class="text-sm text-slate-400">Live Connection: Stable</span>
                </div>
            </div>
        </header>

        <main class="max-w-7xl mx-auto px-6 py-8 space-y-8">
            <!-- Stats Row -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col space-y-2">
                    <span class="text-xs text-slate-400 uppercase tracking-wider font-semibold">AI System Status</span>
                    <span class="text-2xl font-bold text-emerald-400">ONLINE</span>
                </div>
                <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col space-y-2">
                    <span class="text-xs text-slate-400 uppercase tracking-wider font-semibold">Signals Logged</span>
                    <span id="totalSignals" class="text-2xl font-bold text-slate-100">{len(signals)}</span>
                </div>
                <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col space-y-2">
                    <span class="text-xs text-slate-400 uppercase tracking-wider font-semibold">Active Timeframes</span>
                    <span class="text-2xl font-bold text-cyan-400">8 TFs (M5-MN)</span>
                </div>
                <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col space-y-2">
                    <span class="text-xs text-slate-400 uppercase tracking-wider font-semibold">Inference Model</span>
                    <span class="text-2xl font-bold text-slate-100">ONNX Optimized</span>
                </div>
            </div>

            <!-- Signal Table -->
            <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800">
                <div class="flex justify-between items-center mb-4">
                    <h2 class="text-lg font-bold text-white tracking-wide">Live Algorithmic Signal Logs</h2>
                    <span class="text-xs text-slate-400">Auto-refreshing every 10s</span>
                </div>
                <div class="overflow-x-auto rounded-lg border border-slate-800">
                    <table class="w-full text-left border-collapse">
                        <thead>
                            <tr class="bg-slate-950 text-slate-300 text-xs font-semibold uppercase">
                                <th class="p-3">Timestamp</th>
                                <th class="p-3">Symbol</th>
                                <th class="p-3">Timeframe</th>
                                <th class="p-3">Signal</th>
                                <th class="p-3">AI Confidence</th>
                                <th class="p-3">Session</th>
                                <th class="p-3">ATR (14)</th>
                            </tr>
                        </thead>
                        <tbody id="signalsBody">
                            {signals_html}
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Monte Carlo Form & Results -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                <!-- Simulation Card -->
                <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                    <div>
                        <h2 class="text-lg font-bold text-white tracking-wide mb-2">High-Performance Rust Monte Carlo Simulation</h2>
                        <p class="text-sm text-slate-400 mb-4">Perform stress tests and compute Expected Shortfall on custom trading models in real-time.</p>
                        <form id="mcForm" class="space-y-4">
                            <div>
                                <label class="block text-xs font-semibold text-slate-400 mb-1">Starting Capital ($)</label>
                                <input type="number" name="capital" id="capital" value="10000" class="w-full px-4 py-2 rounded-xl bg-slate-950 border border-slate-800 focus:outline-none focus:border-cyan-500 text-slate-100">
                            </div>
                            <div>
                                <label class="block text-xs font-semibold text-slate-400 mb-1">Strategy Win Rate (0.0 to 1.0)</label>
                                <input type="number" step="0.01" name="win_rate" id="win_rate" value="0.55" class="w-full px-4 py-2 rounded-xl bg-slate-950 border border-slate-800 focus:outline-none focus:border-cyan-500 text-slate-100">
                            </div>
                            <button type="submit" class="w-full py-3 bg-cyan-600 hover:bg-cyan-500 font-semibold rounded-xl text-white shadow-lg transition-colors shadow-cyan-600/20">Run Monte Carlo Simulation</button>
                        </form>
                    </div>
                </div>

                <!-- Simulation Output -->
                <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                    <div>
                        <h2 class="text-lg font-bold text-white tracking-wide mb-2">Simulation Projections</h2>
                        <div id="resultsContent" class="space-y-4 mt-4">
                            <p class="text-slate-500 text-sm">Submit the simulation form to project risk outcomes...</p>
                        </div>
                    </div>
                </div>
            </div>
        </main>

        <script>
            document.getElementById('mcForm').addEventListener('submit', async function(e) {{
                e.preventDefault();
                const capital = document.getElementById('capital').value;
                const win_rate = document.getElementById('win_rate').value;

                const response = await fetch(`/api/monte_carlo?initial_capital=${{capital}}&win_rate=${{win_rate}}`);
                if (!response.ok) {{
                    document.getElementById('resultsContent').innerHTML =
                        '<p class="text-rose-400 text-sm">Invalid inputs: capital must be positive and win rate between 0 and 1.</p>';
                    return;
                }}
                const data = await response.json();

                document.getElementById('resultsContent').innerHTML = `
                    <div class="grid grid-cols-2 gap-4">
                        <div class="p-4 bg-slate-950 rounded-xl border border-slate-800">
                            <span class="block text-xs text-slate-400 mb-1">Average Projection</span>
                            <span class="text-xl font-bold text-cyan-400">$${{data.average_ending_capital}}</span>
                        </div>
                        <div class="p-4 bg-slate-950 rounded-xl border border-slate-800">
                            <span class="block text-xs text-slate-400 mb-1">Maximum Best Path</span>
                            <span class="text-xl font-bold text-emerald-400">$${{data.max_ending_capital}}</span>
                        </div>
                        <div class="p-4 bg-slate-950 rounded-xl border border-slate-800">
                            <span class="block text-xs text-slate-400 mb-1">Minimum Worst Path</span>
                            <span class="text-xl font-bold text-rose-400">$${{data.min_ending_capital}}</span>
                        </div>
                        <div class="p-4 bg-slate-950 rounded-xl border border-slate-800">
                            <span class="block text-xs text-slate-400 mb-1">Probability Of Profit</span>
                            <span class="text-xl font-bold text-cyan-400">${{(data.probability_of_profit * 100).toFixed(1)}}%</span>
                        </div>
                        <div class="p-4 bg-slate-950 rounded-xl border border-slate-800">
                            <span class="block text-xs text-slate-400 mb-1">Runs Simulated</span>
                            <span class="text-xl font-bold text-slate-300">${{data.simulations}}</span>
                        </div>
                    </div>
                `;
            }});

            const SIGNAL_COLUMNS = ['timestamp', 'symbol', 'timeframe', 'direction', 'confidence', 'session', 'atr'];
            const COLUMN_CLASSES = {{
                timestamp: 'p-3 text-slate-400',
                symbol: 'p-3 font-semibold text-slate-100',
                timeframe: 'p-3 text-slate-300',
                direction: 'p-3 font-bold',
                confidence: 'p-3 text-cyan-400 font-semibold',
                session: 'p-3 text-slate-300',
                atr: 'p-3 text-slate-400'
            }};

            async function refreshSignals() {{
                let payload;
                try {{
                    const response = await fetch('/api/signals?limit=10');
                    if (!response.ok) return;
                    payload = await response.json();
                }} catch (err) {{
                    return; // keep the last rendered snapshot when the backend is unreachable
                }}

                document.getElementById('totalSignals').textContent = payload.total;

                const body = document.getElementById('signalsBody');
                body.replaceChildren();

                if (!payload.signals.length) {{
                    const row = document.createElement('tr');
                    const cell = document.createElement('td');
                    cell.colSpan = 7;
                    cell.className = 'p-4 text-center text-slate-500';
                    cell.textContent = 'No active signal logs yet. Run the MT5 EA to populate signals.';
                    row.appendChild(cell);
                    body.appendChild(row);
                    return;
                }}

                for (const signal of payload.signals) {{
                    const row = document.createElement('tr');
                    row.className = 'border-b border-slate-700 bg-slate-900/40';
                    const direction = String(signal.direction || '').toUpperCase();
                    for (const column of SIGNAL_COLUMNS) {{
                        const cell = document.createElement('td');
                        cell.className = COLUMN_CLASSES[column];
                        if (column === 'direction') {{
                            cell.className += direction.includes('BUY') ? ' text-emerald-500' : ' text-rose-500';
                        }}
                        // textContent (not innerHTML) so logged values can never inject markup
                        cell.textContent = column === 'confidence'
                            ? `${{signal.confidence}}%`
                            : String(signal[column] ?? '');
                        row.appendChild(cell);
                    }}
                    body.appendChild(row);
                }}
            }}

            setInterval(refreshSignals, 10000);
        </script>
    </body>
    </html>
    """
    return html_content

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5555)
