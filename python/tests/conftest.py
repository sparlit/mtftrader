import importlib
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

PYTHON_DIR = Path(__file__).resolve().parents[1]
if str(PYTHON_DIR) not in sys.path:
    sys.path.insert(0, str(PYTHON_DIR))


@pytest.fixture
def server(tmp_path, monkeypatch):
    """Reload the server module with its log files inside an isolated tmp dir."""
    monkeypatch.chdir(tmp_path)
    import server as server_module

    return importlib.reload(server_module)


@pytest.fixture
def client(server):
    with TestClient(server.app) as test_client:
        yield test_client


@pytest.fixture
def signal_payload():
    return {
        "symbol": "EURUSD",
        "timeframe": "H1",
        "direction": "BUY",
        "confidence": 87.5,
        "session": "LONDON",
        "atr": 0.0012,
        "rsi": 61.4,
    }
