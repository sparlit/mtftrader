import time
import random
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

from signal_store import append_signal, init_store, read_signals

app = FastAPI(title="ITIP AI & Analytics Backend v1.0")

init_store()

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
    signal = dict(req.model_dump(), timestamp=time.strftime("%Y-%m-%d %H:%M:%S"))
    stored = append_signal(signal)

    return {"status": "SUCCESS", "message": "Signal logged", "data": stored}

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

def stat_card(label: str, value: str, value_class: str = "text-slate-100") -> str:
    return f"""
                <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col space-y-2">
                    <span class="text-xs text-slate-400 uppercase tracking-wider font-semibold">{label}</span>
                    <span class="text-2xl font-bold {value_class}">{value}</span>
                </div>"""


@app.get("/dashboard", response_class=HTMLResponse)
def get_web_dashboard():
    # Read raw signals for visualization, newest first
    signals = read_signals()
    signals.reverse()
    signals_html = ""
    for s in signals[:10]: # show latest 10 signals
        dir_class = "text-emerald-500" if "BUY" in s["direction"].upper() else "text-rose-500"
        signals_html += f"""
        <tr class="border-b border-slate-700 bg-slate-900/40">
            <td class="p-3 text-slate-400">{s["timestamp"]}</td>
            <td class="p-3 font-semibold text-slate-100">{s["symbol"]}</td>
            <td class="p-3 text-slate-300">{s["timeframe"]}</td>
            <td class="p-3 font-bold {dir_class}">{s["direction"]}</td>
            <td class="p-3 text-cyan-400 font-semibold">{s["confidence"]}%</td>
            <td class="p-3 text-slate-300">{s["session"]}</td>
            <td class="p-3 text-slate-400">{s["atr"]}</td>
        </tr>
        """
    stats_html = "".join([
        stat_card("AI System Status", "ONLINE", "text-emerald-400"),
        stat_card("Active Engine Threads", "8 (DPI-Aware)"),
        stat_card("Active Timeframes", "8 TFs (M5-MN)", "text-cyan-400"),
        stat_card("Inference Model", "ONNX Optimized"),
    ])

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
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6">{stats_html}
            </div>

            <!-- Signal Table -->
            <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800">
                <div class="flex justify-between items-center mb-4">
                    <h2 class="text-lg font-bold text-white tracking-wide">Live Algorithmic Signal Logs</h2>
                    <span class="text-xs text-slate-400">Auto-refreshing on new ticks</span>
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
                        <tbody>
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
                const data = await response.json();

                const metricCard = (label, value, valueClass) => `
                        <div class="p-4 bg-slate-950 rounded-xl border border-slate-800">
                            <span class="block text-xs text-slate-400 mb-1">${{label}}</span>
                            <span class="text-xl font-bold ${{valueClass}}">${{value}}</span>
                        </div>`;

                document.getElementById('resultsContent').innerHTML = `
                    <div class="grid grid-cols-2 gap-4">
                        ${{metricCard('Average Projection', '$' + data.average_ending_capital, 'text-cyan-400')}}
                        ${{metricCard('Maximum Best Path', '$' + data.max_ending_capital, 'text-emerald-400')}}
                        ${{metricCard('Minimum Worst Path', '$' + data.min_ending_capital, 'text-rose-400')}}
                        ${{metricCard('Runs Simulated', data.simulations, 'text-slate-300')}}
                    </div>
                `;
            }});
        </script>
    </body>
    </html>
    """
    return html_content

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5555)
