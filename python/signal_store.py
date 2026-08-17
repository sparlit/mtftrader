"""Shared persistence helpers for ITIP signal logs (CSV + JSON)."""

import json
import os
from typing import Any, Dict, List

LOG_DIR = "./logs"
CSV_PATH = os.path.join(LOG_DIR, "signals_log.csv")
JSON_PATH = os.path.join(LOG_DIR, "signals_log.json")

# Single source of truth for the signal record layout (CSV column order + JSON keys)
SIGNAL_FIELDS = (
    "timestamp",
    "symbol",
    "timeframe",
    "direction",
    "confidence",
    "session",
    "atr",
    "rsi",
)


def init_store() -> None:
    """Creates the log directory and the CSV header when missing."""
    os.makedirs(LOG_DIR, exist_ok=True)
    if not os.path.exists(CSV_PATH):
        with open(CSV_PATH, "w") as f:
            f.write(",".join(SIGNAL_FIELDS) + "\n")


def read_signals() -> List[Dict[str, Any]]:
    """Returns all logged signals, or an empty list if the log is missing/corrupt."""
    if not os.path.exists(JSON_PATH):
        return []
    try:
        with open(JSON_PATH, "r") as f:
            return json.load(f)
    except Exception:
        return []


def append_signal(signal: Dict[str, Any]) -> Dict[str, Any]:
    """Appends a signal to both the CSV and JSON logs and returns the stored record."""
    record = {field: signal[field] for field in SIGNAL_FIELDS}

    with open(CSV_PATH, "a") as f:
        f.write(",".join(str(record[field]) for field in SIGNAL_FIELDS) + "\n")

    signals = read_signals()
    signals.append(record)
    with open(JSON_PATH, "w") as f:
        json.dump(signals, f, indent=4)

    return record
