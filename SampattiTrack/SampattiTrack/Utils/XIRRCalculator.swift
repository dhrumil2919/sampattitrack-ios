import Foundation

/// XIRRCalculator implements the Extended Internal Rate of Return calculation
/// using Newton's method for iterative convergence.
///
/// XIRR is used to calculate the annualized rate of return for a series of cash flows
/// that occur at irregular intervals, commonly used for investment performance analysis.
class XIRRCalculator {
    private static let maxIterations = 100
    private static let tolerance = 1e-6
    
    /// Calculate XIRR for a series of cash flows
    /// - Parameters:
    ///   - dates: Array of dates for cash flows
    ///   - amounts: Array of amounts (negative = investment/outflow, positive = return/inflow)
    /// - Returns: Annualized rate as percentage (e.g., 15.5 for 15.5%), or nil if calculation fails
    static func calculateXIRR(dates: [Date], amounts: [Double]) -> Double? {
        // Validation
        guard dates.count == amounts.count, dates.count >= 2 else {
            print("[XIRRCalculator] Invalid input: dates and amounts must match and have at least 2 entries")
            return nil
        }
        
        // Find date range
        guard let firstDate = dates.min(), let lastDate = dates.max() else {
            return nil
        }
        
        // Check for positive and negative flows
        let hasPositive = amounts.contains { $0 > 0 }
        let hasNegative = amounts.contains { $0 < 0 }
        let totalInvestment = amounts.filter { $0 < 0 }.reduce(0) { $0 + abs($1) }
        let totalReturn = amounts.filter { $0 > 0 }.reduce(0, +)
        
        // Handle short periods (< 7 days) - return simple return instead of annualized
        let daysDiff = lastDate.timeIntervalSince(firstDate) / 86400
        if daysDiff < 7 {
            guard totalInvestment > 0 else { return 0 }
            let simpleReturn = ((totalReturn - totalInvestment) / totalInvestment) * 100
            print("[XIRRCalculator] Short period (\(daysDiff) days), returning simple return: \(simpleReturn)%")
            return simpleReturn
        }
        
        // Edge cases
        guard hasNegative else {
            print("[XIRRCalculator] No negative cash flows (investments)")
            return nil
        }
        guard hasPositive else {
            print("[XIRRCalculator] No positive cash flows, total loss")
            return -100
        }
        
        // Normalize to years from first date
        let flows = zip(dates, amounts).map { date, amount -> (amount: Double, years: Double) in
            let days = date.timeIntervalSince(firstDate) / 86400
            return (amount, days / 365.0)
        }
        
        // Try Newton's method with different initial guesses
        let guesses = [0.1, -0.5, 0.5, 0.9, -0.9, 1.0, 2.0, 5.0, 10.0, 50.0, 100.0]
        for guess in guesses {
            if let rate = newtonXIRR(flows: flows, initialGuess: guess) {
                let xirrPercent = rate * 100
                print("[XIRRCalculator] Converged with guess \(guess): XIRR = \(xirrPercent)%")
                return xirrPercent
            }
        }
        
        // Fallback: simple return if Newton's method doesn't converge
        guard totalInvestment > 0 else { return 0 }
        let fallbackReturn = ((totalReturn - totalInvestment) / totalInvestment) * 100
        print("[XIRRCalculator] Newton's method failed to converge, using simple return: \(fallbackReturn)%")
        return fallbackReturn
    }
    
    /// Newton's method implementation for XIRR calculation
    /// Solves for rate r where: NPV = Σ(amount_i / (1 + r)^years_i) = 0
    private static func newtonXIRR(flows: [(amount: Double, years: Double)], initialGuess: Double) -> Double? {
        var x = initialGuess
        
        for iteration in 0..<maxIterations {
            var fValue = 0.0        // NPV function value
            var fDerivative = 0.0   // Derivative of NPV
            
            for flow in flows {
                let base = max(1.0 + x, 1e-9)  // Prevent negative base
                let pow = Foundation.pow(base, flow.years)
                
                // NPV formula: Σ(amount / (1+r)^years)
                fValue += flow.amount / pow
                
                // Derivative: Σ(-amount * years / (1+r)^(years+1))
                fDerivative -= (flow.amount * flow.years) / (pow * base)
            }
            
            // Check for NaN
            guard !fValue.isNaN && !fDerivative.isNaN else {
                return nil
            }
            
            // Check for convergence
            if abs(fValue) < tolerance {
                return x
            }
            
            // Avoid division by zero
            guard abs(fDerivative) >= 1e-10 else {
                return nil
            }
            
            // Newton step: x_new = x - f(x) / f'(x)
            var xNew = x - fValue / fDerivative
            
            // Clamp to prevent extreme values (XIRR < -100% is unrealistic)
            if xNew <= -1.0 {
                xNew = -0.9999
            }
            
            // Check for convergence in x
            if abs(xNew - x) < tolerance {
                return xNew
            }
            
            x = xNew
        }
        
        // Failed to converge
        return nil
    }
}
