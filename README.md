# Institutional Trading Intelligence Platform (ITIP) v1.0

ITIP is an advanced, high-performance institutional trading and algorithmic analytics platform that extends MT5 into an intelligent, AI-powered system. Designed to integrate seamlessly with custom execution strategies, multi-timeframe models, and external high-performance modules written in Python and Rust.

## Architecture

The platform is designed around 10 decoupled "Brains":
1. **Market Brain** (`MQL5/Include/ITIP/MarketBrain.mqh`): Tracks multi-timeframe candles (M5, M15, M30, H1, H4, D1, W1, MN), computes sub-second remaining times, tick volume delta (cumulative volume delta), and detects smart money structure (Order Blocks & Fair Value Gaps).
2. **Strategy Brain** (`MQL5/Include/ITIP/StrategyBrain.mqh`): Manages multi-indicator confluence, persistence factor (anti-whiplash filters), and classic RSI divergences.
3. **Risk Brain** (`MQL5/Include/ITIP/RiskBrain.mqh`): Handles trade-size calculators based on account equity/ATR and enforces dynamic drawdown circuit breakers.
4. **Execution Brain** (`MQL5/Include/ITIP/ExecutionBrain.mqh`): Fires orders to the broker, runs trailing stops, and manages automated breakeven thresholds.
5. **Dashboard Brain** (`MQL5/Include/ITIP/DashboardBrain.mqh`): Draws a beautiful, high-performance GUI inside the MT5 terminal window. It utilizes real-time timers and progress bars for each timeframe in a clean, tabular format.
6. **Infrastructure Brain**: Links MQL5 to the Python backend over APIs and provides logging.
7. **AI Brain** (`python/server.py`): Serves machine learning inference, model loading, and real-time confidence updates.
8. **Research Brain** (`rust/src/main.rs`): Runs ultra-fast Monte Carlo simulators, risk projections, and statistical evaluations.
9. **Portfolio Brain**: Aggregates multi-asset correlations and cross-asset metrics.
10. **Supervisor Brain**: Ensures health monitoring, telemetry, and secure API links.

## Quick Start

### 1. MT5 EA Setup
- Place the contents of `MQL5/Experts/` inside your MT5 Terminal's `MQL5/Experts/` directory.
- Place the contents of `MQL5/Include/ITIP/` inside your MT5 Terminal's `MQL5/Include/ITIP/` directory.
- Compile `ITIP_EA.mq5` within MetaEditor and attach it to any chart.

### 2. Python AI Server
- Install dependencies:
  ```bash
  pip install fastapi uvicorn pydantic
  ```
- Run the API server:
  ```bash
  python3 python/server.py
  ```

### 3. Rust Performance Engine
- Build and run the simulation engine:
  ```bash
  cargo run --manifest-path rust/Cargo.toml
  ```

## Features Included
- Multi-timeframe evaluation with precise candle countdown timers.
- Interactive Trade Panel with GUI Action buttons (BUY, SELL, Partial Close, Breakeven/Trailing Stop).
- Built-in Drawdown Circuit Breakers to secure account equity.
- High-Performance Rust Monte Carlo risk simulation.
- Real-time CSV and JSON signal logging.
