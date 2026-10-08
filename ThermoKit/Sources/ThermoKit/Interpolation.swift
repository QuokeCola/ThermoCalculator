import Foundation

@inline(__always)
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

extension Array where Element == Double {
    /// For an ascending array, returns the index `i` such that `self[i] <= x <= self[i + 1]`
    /// together with the fraction of the way `x` lies between them, or nil when `x` is outside.
    func bracket(_ x: Double) -> (index: Int, t: Double)? {
        guard count >= 2, let first, let last, x >= first, x <= last else {
            if count == 1, let first, x == first { return (0, 0) }
            return nil
        }
        var lo = 0
        var hi = count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if self[mid] <= x { lo = mid } else { hi = mid }
        }
        let span = self[hi] - self[lo]
        return (lo, span == 0 ? 0 : (x - self[lo]) / span)
    }
}

/// Finds `x` in `range` with `f(x) == 0`.
///
/// The range is scanned at `samples` points (log-spaced when `logarithmic`) to find a sign change,
/// then refined by bisection. Points where `f` throws (outside the tables) are skipped.
/// When several roots exist the one with the smallest `x` is returned.
func solveRoot(
    in range: ClosedRange<Double>,
    samples: Int = 160,
    logarithmic: Bool = false,
    tolerance: Double = 1e-10,
    _ f: (Double) throws -> Double
) -> Double? {
    func point(_ i: Int) -> Double {
        let t = Double(i) / Double(samples)
        if logarithmic {
            return exp(lerp(log(range.lowerBound), log(range.upperBound), t))
        }
        return lerp(range.lowerBound, range.upperBound, t)
    }

    var previous: (x: Double, fx: Double)?
    for i in 0...samples {
        let x = point(i)
        guard let fx = try? f(x) else {
            previous = nil
            continue
        }
        if fx == 0 { return x }
        if let p = previous, (p.fx < 0) != (fx < 0) {
            if let root = bisect(p.x, x, p.fx, tolerance: tolerance, f) { return root }
        }
        previous = (x, fx)
    }
    return nil
}

private func bisect(
    _ a0: Double, _ b0: Double, _ fa0: Double, tolerance: Double, _ f: (Double) throws -> Double
) -> Double? {
    var a = a0, b = b0, fa = fa0
    for _ in 0..<200 {
        let m = (a + b) / 2
        guard let fm = try? f(m) else { return nil }
        if fm == 0 { return m }
        if (fa < 0) == (fm < 0) { a = m; fa = fm } else { b = m }
        if abs(b - a) <= tolerance * max(1, abs(m)) { break }
    }
    return (a + b) / 2
}
