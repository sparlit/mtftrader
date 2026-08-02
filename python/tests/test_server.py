import csv
import json
import os

import pytest

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
# The empty-state phrase also appears in the auto-refresh script, so tests match the row.
EMPTY_STATE_ROW = "<tr><td colspan='7'"


class TestBootstrap:
    def test_log_dir_and_csv_header_created_on_import(self, server):
        assert os.path.isdir(server.LOG_DIR)
        with open(server.CSV_PATH, newline="") as f:
            assert next(csv.reader(f)) == CSV_COLUMNS

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

        with open(server.CSV_PATH, newline="") as f:
            rows = list(csv.reader(f))

        assert rows[0] == CSV_COLUMNS
        assert len(rows) == 2
        assert rows[1][1:] == [
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

    @pytest.mark.parametrize(
        "field,value",
        [
            ("confidence", 120.0),
            ("confidence", -1.0),
            ("rsi", 101.0),
            ("atr", -0.5),
            ("symbol", ""),
        ],
    )
    def test_rejects_out_of_range_values(self, client, signal_payload, field, value):
        payload = {**signal_payload, field: value}

        assert client.post("/api/signal", json=payload).status_code == 422

    def test_separators_in_fields_stay_on_one_csv_row(
        self, client, server, signal_payload
    ):
        client.post("/api/signal", json={**signal_payload, "session": "NY,LONDON"})

        with open(server.CSV_PATH, newline="") as f:
            rows = list(csv.reader(f))

        assert len(rows) == 2
        assert rows[1][5] == "NY,LONDON"

    def test_json_log_holding_an_object_is_reset(
        self, client, server, signal_payload
    ):
        with open(server.JSON_PATH, "w") as f:
            json.dump({"unexpected": "shape"}, f)

        response = client.post("/api/signal", json=signal_payload)

        assert response.status_code == 200
        with open(server.JSON_PATH) as f:
            assert [entry["symbol"] for entry in json.load(f)] == ["EURUSD"]


class TestListSignals:
    def test_returns_newest_first_with_totals(self, client, signal_payload):
        for i in range(3):
            client.post("/api/signal", json={**signal_payload, "symbol": f"SYM{i}"})

        body = client.get("/api/signals").json()

        assert body["total"] == 3
        assert body["count"] == 3
        assert [s["symbol"] for s in body["signals"]] == ["SYM2", "SYM1", "SYM0"]

    def test_limit_caps_returned_signals_but_not_total(self, client, signal_payload):
        for i in range(4):
            client.post("/api/signal", json={**signal_payload, "symbol": f"SYM{i}"})

        body = client.get("/api/signals", params={"limit": 2}).json()

        assert body["total"] == 4
        assert [s["symbol"] for s in body["signals"]] == ["SYM3", "SYM2"]

    def test_filters_by_symbol_and_direction_case_insensitively(
        self, client, signal_payload
    ):
        client.post("/api/signal", json=signal_payload)
        client.post("/api/signal", json={**signal_payload, "direction": "SELL"})
        client.post("/api/signal", json={**signal_payload, "symbol": "XAUUSD"})

        body = client.get(
            "/api/signals", params={"symbol": "eurusd", "direction": "sell"}
        ).json()

        assert body["total"] == 1
        assert body["signals"][0]["direction"] == "SELL"

    def test_empty_log_returns_empty_list(self, client):
        assert client.get("/api/signals").json() == {
            "count": 0,
            "total": 0,
            "signals": [],
        }

    @pytest.mark.parametrize("limit", [0, -1, 501])
    def test_rejects_out_of_range_limit(self, client, limit):
        assert client.get("/api/signals", params={"limit": limit}).status_code == 422


class TestStats:
    def test_empty_log_reports_zeroes(self, client):
        assert client.get("/api/stats").json() == {
            "total_signals": 0,
            "by_direction": {},
            "by_symbol": {},
            "average_confidence": 0.0,
            "latest_timestamp": None,
        }

    def test_aggregates_direction_symbol_and_confidence(self, client, signal_payload):
        client.post("/api/signal", json={**signal_payload, "confidence": 80.0})
        client.post(
            "/api/signal",
            json={**signal_payload, "direction": "SELL", "confidence": 60.0},
        )
        client.post(
            "/api/signal",
            json={**signal_payload, "symbol": "XAUUSD", "confidence": 40.0},
        )

        body = client.get("/api/stats").json()

        assert body["total_signals"] == 3
        assert body["by_direction"] == {"BUY": 2, "SELL": 1}
        assert body["by_symbol"] == {"EURUSD": 2, "XAUUSD": 1}
        assert body["average_confidence"] == 60.0
        assert body["latest_timestamp"]

    def test_tolerates_entries_with_missing_fields(self, client, server):
        with open(server.JSON_PATH, "w") as f:
            json.dump([{"symbol": "EURUSD"}, "not-a-dict"], f)

        body = client.get("/api/stats").json()

        assert body["total_signals"] == 1
        assert body["by_direction"] == {"UNKNOWN": 1}
        assert body["average_confidence"] == 0.0


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

    @pytest.mark.parametrize(
        "params",
        [
            {"simulations": 0},
            {"simulations": 100001},
            {"initial_capital": 0},
            {"win_rate": 1.5},
            {"win_rate": -0.1},
            {"trades": 0},
        ],
    )
    def test_rejects_invalid_parameters_instead_of_crashing(self, client, params):
        assert client.get("/api/monte_carlo", params=params).status_code == 422

    def test_trades_per_path_is_configurable(self, client):
        body = client.get(
            "/api/monte_carlo",
            params={
                "simulations": 3,
                "initial_capital": 1000,
                "win_rate": 1.0,
                "trades": 10,
            },
        ).json()

        assert body["trades_per_path"] == 10
        assert body["average_ending_capital"] == pytest.approx(
            round(1000 * (1.02**10), 2), rel=1e-9
        )

    def test_probability_of_profit_reflects_win_rate_extremes(self, client):
        winning = client.get(
            "/api/monte_carlo", params={"simulations": 5, "win_rate": 1.0}
        ).json()
        losing = client.get(
            "/api/monte_carlo", params={"simulations": 5, "win_rate": 0.0}
        ).json()

        assert winning["probability_of_profit"] == 1.0
        assert losing["probability_of_profit"] == 0.0

    def test_median_sits_between_min_and_max(self, client):
        body = client.get("/api/monte_carlo", params={"simulations": 50}).json()

        assert body["min_ending_capital"] <= body["median_ending_capital"]
        assert body["median_ending_capital"] <= body["max_ending_capital"]


class TestDashboard:
    def test_renders_empty_state_without_signals(self, client):
        response = client.get("/dashboard")

        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]
        assert EMPTY_STATE_ROW in response.text

    def test_renders_logged_signal_row(self, client, signal_payload):
        client.post("/api/signal", json=signal_payload)

        html = client.get("/dashboard").text

        assert EMPTY_STATE_ROW not in html
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

    def test_escapes_html_in_logged_values(self, client, signal_payload):
        client.post(
            "/api/signal", json={**signal_payload, "symbol": "<script>x()</script>"}
        )

        html = client.get("/dashboard").text

        assert "<script>x()</script>" not in html
        assert "&lt;script&gt;x()&lt;/script&gt;" in html

    def test_renders_entries_missing_fields(self, client, server):
        with open(server.JSON_PATH, "w") as f:
            json.dump([{"symbol": "EURUSD"}], f)

        response = client.get("/dashboard")

        assert response.status_code == 200
        assert EMPTY_STATE_ROW not in response.text

    def test_corrupt_json_log_renders_empty_state(self, client, server):
        with open(server.JSON_PATH, "w") as f:
            f.write("[[[")

        response = client.get("/dashboard")

        assert response.status_code == 200
        assert EMPTY_STATE_ROW in response.text


class TestModels:
    def test_trade_stats_model_parses_floats(self, server):
        stats = server.TradeStats(win_rate="0.6", profit_factor=1.8, max_drawdown=12.5)

        assert stats.win_rate == 0.6
        assert stats.profit_factor == 1.8
        assert stats.max_drawdown == 12.5
