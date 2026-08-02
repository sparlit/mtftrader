import json
import os

import pytest

CSV_HEADER = "timestamp,symbol,timeframe,direction,confidence,session,atr,rsi\n"


class TestBootstrap:
    def test_log_dir_and_csv_header_created_on_import(self, server):
        assert os.path.isdir(server.LOG_DIR)
        with open(server.CSV_PATH) as f:
            assert f.readline() == CSV_HEADER

    def test_existing_csv_is_not_overwritten(self, server):
        with open(server.CSV_PATH, "a") as f:
            f.write("2024-01-01 00:00:00,EURUSD,H1,BUY,90.0,LONDON,0.001,55.0\n")

        import importlib

        reloaded = importlib.reload(server)
        with open(reloaded.CSV_PATH) as f:
            lines = f.readlines()
        assert len(lines) == 2


class TestReadRoot:
    def test_returns_online_status_payload(self, client):
        response = client.get("/")
        assert response.status_code == 200
        assert response.json() == {
            "status": "ONLINE",
            "system": "ITIP AI Subsystem",
            "version": "1.0.0",
            "onnx_optimized": True,
            "cuda_support": False,
        }


class TestLogSignal:
    def test_returns_logged_signal(self, client, signal_payload):
        response = client.post("/api/signal", json=signal_payload)

        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "SUCCESS"
        assert body["message"] == "Signal logged"
        assert body["data"]["timestamp"]
        for key, value in signal_payload.items():
            assert body["data"][key] == value

    def test_appends_row_to_csv(self, client, server, signal_payload):
        client.post("/api/signal", json=signal_payload)

        with open(server.CSV_PATH) as f:
            lines = f.readlines()

        assert lines[0] == CSV_HEADER
        assert len(lines) == 2
        fields = lines[1].strip().split(",")
        assert fields[1:] == [
            "EURUSD",
            "H1",
            "BUY",
            "87.5",
            "LONDON",
            "0.0012",
            "61.4",
        ]

    def test_appends_to_json_log_across_requests(self, client, server, signal_payload):
        client.post("/api/signal", json=signal_payload)
        client.post("/api/signal", json={**signal_payload, "symbol": "XAUUSD"})

        with open(server.JSON_PATH) as f:
            data = json.load(f)

        assert [entry["symbol"] for entry in data] == ["EURUSD", "XAUUSD"]

    def test_corrupt_json_log_is_replaced_instead_of_failing(
        self, client, server, signal_payload
    ):
        with open(server.JSON_PATH, "w") as f:
            f.write("{not json")

        response = client.post("/api/signal", json=signal_payload)

        assert response.status_code == 200
        with open(server.JSON_PATH) as f:
            data = json.load(f)
        assert len(data) == 1
        assert data[0]["symbol"] == "EURUSD"

    @pytest.mark.parametrize("missing_field", ["symbol", "confidence", "atr"])
    def test_rejects_payload_missing_required_field(
        self, client, signal_payload, missing_field
    ):
        payload = dict(signal_payload)
        del payload[missing_field]

        assert client.post("/api/signal", json=payload).status_code == 422

    def test_rejects_non_numeric_confidence(self, client, signal_payload):
        payload = {**signal_payload, "confidence": "very-high"}

        assert client.post("/api/signal", json=payload).status_code == 422

    def test_coerces_numeric_strings(self, client, signal_payload):
        payload = {**signal_payload, "confidence": "42.5"}

        response = client.post("/api/signal", json=payload)

        assert response.status_code == 200
        assert response.json()["data"]["confidence"] == 42.5


class TestCorrelation:
    def test_matrix_is_square_over_expected_symbols(self, client):
        response = client.get("/api/correlation")

        assert response.status_code == 200
        matrix = response.json()["correlation_matrix"]
        symbols = ["EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "XAUUSD"]
        assert list(matrix) == symbols
        for symbol in symbols:
            assert list(matrix[symbol]) == symbols

    def test_self_correlation_is_one_and_others_in_range(self, client):
        matrix = client.get("/api/correlation").json()["correlation_matrix"]

        for s1, row in matrix.items():
            for s2, value in row.items():
                if s1 == s2:
                    assert value == 1.0
                else:
                    assert -0.8 <= value <= 0.8
                    assert round(value, 2) == value


class TestMonteCarlo:
    def test_defaults(self, client):
        response = client.get("/api/monte_carlo")

        assert response.status_code == 200
        body = response.json()
        assert body["simulations"] == 1000
        assert body["initial_capital"] == 10000.0

    def test_bounds_are_consistent(self, client):
        body = client.get(
            "/api/monte_carlo",
            params={"simulations": 50, "initial_capital": 5000, "win_rate": 0.5},
        ).json()

        assert body["min_ending_capital"] <= body["average_ending_capital"]
        assert body["average_ending_capital"] <= body["max_ending_capital"]

    def test_always_winning_strategy_compounds_gains(self, client):
        body = client.get(
            "/api/monte_carlo",
            params={"simulations": 5, "initial_capital": 1000, "win_rate": 1.0},
        ).json()

        expected = round(1000 * (1.02**50), 2)
        assert body["min_ending_capital"] == pytest.approx(expected, rel=1e-9)
        assert body["max_ending_capital"] == pytest.approx(expected, rel=1e-9)

    def test_always_losing_strategy_compounds_losses(self, client):
        body = client.get(
            "/api/monte_carlo",
            params={"simulations": 5, "initial_capital": 1000, "win_rate": 0.0},
        ).json()

        expected = round(1000 * (0.99**50), 2)
        assert body["average_ending_capital"] == pytest.approx(expected, rel=1e-9)

    def test_rejects_non_numeric_simulations(self, client):
        assert client.get("/api/monte_carlo?simulations=many").status_code == 422


class TestDashboard:
    def test_renders_empty_state_without_signals(self, client):
        response = client.get("/dashboard")

        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]
        assert "No active signal logs yet" in response.text

    def test_renders_logged_signal_row(self, client, signal_payload):
        client.post("/api/signal", json=signal_payload)

        html = client.get("/dashboard").text

        assert "No active signal logs yet" not in html
        assert "EURUSD" in html
        assert "text-emerald-500" in html

    def test_sell_signals_use_rose_colour(self, client, signal_payload):
        client.post("/api/signal", json={**signal_payload, "direction": "SELL"})

        html = client.get("/dashboard").text

        assert "text-rose-500" in html

    def test_shows_newest_first_and_caps_at_ten_rows(self, client, signal_payload):
        for i in range(12):
            client.post("/api/signal", json={**signal_payload, "symbol": f"SYM{i:02d}"})

        html = client.get("/dashboard").text

        assert html.index("SYM11") < html.index("SYM02")
        assert "SYM00" not in html
        assert "SYM01" not in html

    def test_corrupt_json_log_renders_empty_state(self, client, server):
        with open(server.JSON_PATH, "w") as f:
            f.write("[[[")

        response = client.get("/dashboard")

        assert response.status_code == 200
        assert "No active signal logs yet" in response.text


class TestModels:
    def test_trade_stats_model_parses_floats(self, server):
        stats = server.TradeStats(win_rate="0.6", profit_factor=1.8, max_drawdown=12.5)

        assert stats.win_rate == 0.6
        assert stats.profit_factor == 1.8
        assert stats.max_drawdown == 12.5
