public enum AllPassesViewAction {
    /// Calculate the passes.
    case calculatePasses(CalculatePassesParams)
    /// Recaculate passes using the latest location.
    case recalculatePasses(CalculatePassesParams)
    case scheduleNotification(PassNotification, passSnapshots: PassSnapshots)
    case unscheduleNotification(pass: Pass)
    case deeplinkToLocationSelection
    case showLocationSettings
    case showOnboarding(Bool)
    case completeOnboarding
}
