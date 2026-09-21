import CoreGraphics

/// Temporal admission and spatial hysteresis for moving sky labels, in screen points.
/// Candidates arrive in brightness order; readable incumbents keep their slots.
struct PlanetariumLabelLayout {
    struct Candidate {
        let id: Int
        let rect: CGRect
    }
    struct Placement {
        let id: Int
        let rect: CGRect
        let opacity: Float
    }
    private struct State {
        var eligibleSince: Double?
        var visibleSince: Double?
        var retryAfter: Double = 0
    }
    private var states: [Int: State] = [:]
    var retainedIDs: Set<Int> { Set(states.compactMap { $0.value.visibleSince == nil ? nil : $0.key }) }

    mutating func reset() { states.removeAll(keepingCapacity: true) }

    mutating func layout(_ candidates: [Candidate], bounds: CGRect, obstacles: [CGRect], budget: Int, time: Double) -> [Placement] {
        let ids = Set(candidates.map(\.id))
        states = states.filter { ids.contains($0.key) }
        // Stable incumbent order also makes the winner deterministic when two labels converge.
        let ordered = candidates.sorted {
            let a = states[$0.id]?.visibleSince ?? .infinity
            let b = states[$1.id]?.visibleSince ?? .infinity
            if a != b { return a < b }
            if a.isFinite { return $0.id < $1.id }
            return false // New candidates retain the caller's brightness order (stable sort).
        }
        var result: [Placement] = []
        var occupied = obstacles
        for candidate in ordered {
            var state = states[candidate.id] ?? State()
            let incumbent = state.visibleSince != nil
            // More room is required to appear than to remain visible. Never render overlapping text.
            let padded = candidate.rect.insetBy(dx: incumbent ? -4 : -12, dy: incumbent ? -3 : -8)
            let fits = bounds.contains(padded) && !occupied.contains { $0.intersects(padded) }
            if !fits || result.count >= budget {
                if incumbent { state.retryAfter = time + 0.6 }
                state.visibleSince = nil
                state.eligibleSince = nil
            } else if incumbent {
                result.append(Placement(id: candidate.id, rect: candidate.rect,
                    opacity: Float(min(1, max(0, (time - state.visibleSince!) / 0.2)))))
                occupied.append(candidate.rect.insetBy(dx: -4, dy: -3))
            } else if time >= state.retryAfter {
                if state.eligibleSince == nil { state.eligibleSince = time }
                if time - state.eligibleSince! >= 0.25 {
                    state.visibleSince = time
                    result.append(Placement(id: candidate.id, rect: candidate.rect, opacity: 0))
                    occupied.append(candidate.rect.insetBy(dx: -4, dy: -3))
                }
            }
            states[candidate.id] = state
        }
        return result
    }
}
