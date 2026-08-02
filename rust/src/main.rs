use rand::Rng;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct RiskReport {
    pub initial_capital: f64,
    pub final_capital_mean: f64,
    pub value_at_risk_95: f64,
    pub expected_shortfall_95: f64,
    pub probability_of_profit: f64,
}

pub fn simulate_monte_carlo(initial_capital: f64, win_rate: f64, num_trades: usize, num_simulations: usize) -> RiskReport {
    // gen_bool panics outside [0, 1], and an empty run has no percentile to index.
    let win_rate = win_rate.clamp(0.0, 1.0);
    if num_simulations == 0 {
        return RiskReport {
            initial_capital,
            final_capital_mean: initial_capital,
            value_at_risk_95: 0.0,
            expected_shortfall_95: 0.0,
            probability_of_profit: 0.0,
        };
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

    final_capitals.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let sum: f64 = final_capitals.iter().sum();
    let mean = sum / num_simulations as f64;

    // Value at Risk at 95% confidence
    let index_95 = ((num_simulations as f64 * 0.05) as usize).min(num_simulations - 1);
    let var_value = initial_capital - final_capitals[index_95];

    // Expected Shortfall at 95% confidence; the tail always holds the worst path at minimum
    let worst_5_percent = &final_capitals[0..index_95.max(1)];
    let sum_worst: f64 = worst_5_percent.iter().sum();
    let expected_shortfall_95 = initial_capital - (sum_worst / worst_5_percent.len() as f64);

    let profitable = final_capitals
        .iter()
        .filter(|capital| **capital > initial_capital)
        .count();

    RiskReport {
        initial_capital,
        final_capital_mean: mean,
        value_at_risk_95: var_value,
        expected_shortfall_95,
        probability_of_profit: profitable as f64 / num_simulations as f64,
    }
}

fn main() {
    println!("ITIP Rust High-Performance Engine initialized.");
    let report = simulate_monte_carlo(10000.0, 0.55, 100, 10000);
    println!("Monte Carlo Simulation Results: {:?}", report);
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
    fn small_sample_tail_falls_back_to_the_worst_path() {
        // With fewer than 20 simulations the 5% tail index rounds down to 0.
        let report = simulate_monte_carlo(1000.0, 0.5, 20, 10);

        assert!((report.expected_shortfall_95 - report.value_at_risk_95).abs() < EPSILON);
    }

    #[test]
    fn single_simulation_does_not_panic() {
        let report = simulate_monte_carlo(1000.0, 0.5, 10, 1);

        assert!(report.final_capital_mean > 0.0);
    }

    #[test]
    fn zero_simulations_returns_a_neutral_report() {
        let report = simulate_monte_carlo(1000.0, 0.55, 10, 0);

        assert!((report.final_capital_mean - 1000.0).abs() < EPSILON);
        assert_eq!(report.value_at_risk_95, 0.0);
        assert_eq!(report.expected_shortfall_95, 0.0);
        assert_eq!(report.probability_of_profit, 0.0);
    }

    #[test]
    fn out_of_range_win_rate_is_clamped_instead_of_panicking() {
        let above = simulate_monte_carlo(1000.0, 4.2, 10, 20);
        let below = simulate_monte_carlo(1000.0, -3.0, 10, 20);

        assert!((above.final_capital_mean - 1000.0 * 1.02_f64.powi(10)).abs() < EPSILON);
        assert!((below.final_capital_mean - 1000.0 * 0.99_f64.powi(10)).abs() < EPSILON);
    }

    #[test]
    fn probability_of_profit_tracks_win_rate_extremes() {
        assert_eq!(
            simulate_monte_carlo(1000.0, 1.0, 10, 50).probability_of_profit,
            1.0
        );
        assert_eq!(
            simulate_monte_carlo(1000.0, 0.0, 10, 50).probability_of_profit,
            0.0
        );
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
        assert!((parsed.probability_of_profit - report.probability_of_profit).abs() < EPSILON);
    }
}
