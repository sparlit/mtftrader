use std::error::Error;
use std::fmt;
use std::process::ExitCode;

use rand::Rng;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug, PartialEq)]
pub struct RiskReport {
    pub initial_capital: f64,
    pub final_capital_mean: f64,
    pub value_at_risk_95: f64,
    pub expected_shortfall_95: f64,
}

#[derive(Debug, PartialEq)]
pub enum SimulationError {
    InvalidWinRate(f64),
    InvalidCapital(f64),
    NoSimulations,
    NoTrades,
}

impl fmt::Display for SimulationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SimulationError::InvalidWinRate(value) => {
                write!(f, "win rate must be a probability between 0.0 and 1.0, got {value}")
            }
            SimulationError::InvalidCapital(value) => {
                write!(f, "initial capital must be finite and greater than zero, got {value}")
            }
            SimulationError::NoSimulations => write!(f, "number of simulations must be greater than zero"),
            SimulationError::NoTrades => write!(f, "number of trades must be greater than zero"),
        }
    }
}

impl Error for SimulationError {}

pub fn simulate_monte_carlo(
    initial_capital: f64,
    win_rate: f64,
    num_trades: usize,
    num_simulations: usize,
) -> Result<RiskReport, SimulationError> {
    if !initial_capital.is_finite() || initial_capital <= 0.0 {
        return Err(SimulationError::InvalidCapital(initial_capital));
    }
    if !win_rate.is_finite() || !(0.0..=1.0).contains(&win_rate) {
        return Err(SimulationError::InvalidWinRate(win_rate));
    }
    if num_simulations == 0 {
        return Err(SimulationError::NoSimulations);
    }
    if num_trades == 0 {
        return Err(SimulationError::NoTrades);
    }

    let mut rng = rand::thread_rng();
    let mut final_capitals = Vec::with_capacity(num_simulations);

    for _ in 0..num_simulations {
        let mut capital = initial_capital;
        for _ in 0..num_trades {
            if rng.gen_bool(win_rate) {
                capital += capital * 0.02; // 2% gain
            } else {
                capital -= capital * 0.01; // 1% loss
            }
        }
        final_capitals.push(capital);
    }

    final_capitals.sort_by(|a, b| a.total_cmp(b));

    let sum: f64 = final_capitals.iter().sum();
    let mean = sum / num_simulations as f64;

    // Value at Risk at 95% confidence
    let index_95 = ((num_simulations as f64 * 0.05) as usize).min(num_simulations - 1);
    let var_value = initial_capital - final_capitals[index_95];

    // Expected Shortfall at 95% confidence
    let worst_5_percent = &final_capitals[0..index_95];
    let sum_worst: f64 = worst_5_percent.iter().sum();
    let expected_shortfall_95 = if !worst_5_percent.is_empty() {
        initial_capital - (sum_worst / worst_5_percent.len() as f64)
    } else {
        var_value
    };

    Ok(RiskReport {
        initial_capital,
        final_capital_mean: mean,
        value_at_risk_95: var_value,
        expected_shortfall_95,
    })
}

fn main() -> ExitCode {
    println!("ITIP Rust High-Performance Engine initialized.");
    match simulate_monte_carlo(10000.0, 0.55, 100, 10000) {
        Ok(report) => {
            println!("Monte Carlo Simulation Results: {report:?}");
            ExitCode::SUCCESS
        }
        Err(err) => {
            eprintln!("ITIP Rust engine: Monte Carlo simulation failed: {err}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_invalid_inputs() {
        assert_eq!(
            simulate_monte_carlo(10000.0, 1.5, 10, 10),
            Err(SimulationError::InvalidWinRate(1.5))
        );
        assert_eq!(
            simulate_monte_carlo(0.0, 0.5, 10, 10),
            Err(SimulationError::InvalidCapital(0.0))
        );
        assert_eq!(
            simulate_monte_carlo(10000.0, 0.5, 10, 0),
            Err(SimulationError::NoSimulations)
        );
        assert_eq!(
            simulate_monte_carlo(10000.0, 0.5, 0, 10),
            Err(SimulationError::NoTrades)
        );
    }

    #[test]
    fn small_sample_does_not_panic() {
        // index_95 collapses to 0, leaving an empty tail slice for expected shortfall.
        let report = simulate_monte_carlo(10000.0, 0.55, 5, 1).expect("simulation should succeed");
        assert!(report.final_capital_mean.is_finite());
        assert!(report.expected_shortfall_95.is_finite());
    }

    #[test]
    fn reports_finite_metrics_for_typical_run() {
        let report = simulate_monte_carlo(10000.0, 0.55, 50, 500).expect("simulation should succeed");
        assert_eq!(report.initial_capital, 10000.0);
        assert!(report.final_capital_mean > 0.0);
        assert!(report.value_at_risk_95.is_finite());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const EPSILON: f64 = 1e-6;

    #[test]
    fn always_winning_compounds_two_percent_per_trade() {
        let report = simulate_monte_carlo(1000.0, 1.0, 10, 100);
        let expected = 1000.0 * 1.02_f64.powi(10);

        assert!((report.final_capital_mean - expected).abs() < EPSILON);
        assert!((report.value_at_risk_95 - (1000.0 - expected)).abs() < EPSILON);
    }

    #[test]
    fn always_losing_compounds_one_percent_per_trade() {
        let report = simulate_monte_carlo(1000.0, 0.0, 10, 100);
        let expected = 1000.0 * 0.99_f64.powi(10);

        assert!((report.final_capital_mean - expected).abs() < EPSILON);
        assert!((report.expected_shortfall_95 - (1000.0 - expected)).abs() < EPSILON);
    }

    #[test]
    fn zero_trades_preserves_initial_capital() {
        let report = simulate_monte_carlo(2500.0, 0.55, 0, 100);

        assert!((report.final_capital_mean - 2500.0).abs() < EPSILON);
        assert!(report.value_at_risk_95.abs() < EPSILON);
        assert!(report.expected_shortfall_95.abs() < EPSILON);
    }

    #[test]
    fn expected_shortfall_is_zero_when_tail_sample_is_empty() {
        // With fewer than 20 simulations the 5% tail index rounds down to 0.
        let report = simulate_monte_carlo(1000.0, 0.5, 20, 10);

        assert_eq!(report.expected_shortfall_95, 0.0);
    }

    #[test]
    fn report_echoes_initial_capital() {
        let report = simulate_monte_carlo(7331.5, 0.6, 5, 50);

        assert!((report.initial_capital - 7331.5).abs() < EPSILON);
    }

    #[test]
    fn mixed_win_rate_keeps_mean_between_worst_and_best_paths() {
        let num_trades = 40;
        let report = simulate_monte_carlo(1000.0, 0.55, num_trades, 500);

        let all_losses = 1000.0 * 0.99_f64.powi(num_trades as i32);
        let all_wins = 1000.0 * 1.02_f64.powi(num_trades as i32);

        assert!(report.final_capital_mean >= all_losses);
        assert!(report.final_capital_mean <= all_wins);
    }

    #[test]
    fn expected_shortfall_is_at_least_value_at_risk() {
        let report = simulate_monte_carlo(1000.0, 0.5, 50, 1000);

        assert!(report.expected_shortfall_95 >= report.value_at_risk_95 - EPSILON);
    }

    #[test]
    fn report_round_trips_through_json() {
        let report = simulate_monte_carlo(1000.0, 1.0, 3, 100);
        let json = serde_json::to_string(&report).expect("serialization failed");
        let parsed: RiskReport = serde_json::from_str(&json).expect("deserialization failed");

        assert!((parsed.final_capital_mean - report.final_capital_mean).abs() < EPSILON);
        assert!((parsed.value_at_risk_95 - report.value_at_risk_95).abs() < EPSILON);
        assert!((parsed.expected_shortfall_95 - report.expected_shortfall_95).abs() < EPSILON);
    }
}
