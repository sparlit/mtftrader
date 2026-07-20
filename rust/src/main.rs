use rand::Rng;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct RiskReport {
    pub initial_capital: f64,
    pub final_capital_mean: f64,
    pub value_at_risk_95: f64,
    pub expected_shortfall_95: f64,
}

pub fn simulate_monte_carlo(initial_capital: f64, win_rate: f64, num_trades: usize, num_simulations: usize) -> RiskReport {
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
    let index_95 = (num_simulations as f64 * 0.05) as usize;
    let var_value = initial_capital - final_capitals[index_95];

    // Expected Shortfall at 95% confidence
    let worst_5_percent = &final_capitals[0..index_95];
    let sum_worst: f64 = worst_5_percent.iter().sum();
    let expected_shortfall_95 = if !worst_5_percent.is_empty() {
        initial_capital - (sum_worst / worst_5_percent.len() as f64)
    } else {
        0.0
    };

    RiskReport {
        initial_capital,
        final_capital_mean: mean,
        value_at_risk_95: var_value,
        expected_shortfall_95,
    }
}

fn main() {
    println!("ITIP Rust High-Performance Engine initialized.");
    let report = simulate_monte_carlo(10000.0, 0.55, 100, 10000);
    println!("Monte Carlo Simulation Results: {:?}", report);
}
