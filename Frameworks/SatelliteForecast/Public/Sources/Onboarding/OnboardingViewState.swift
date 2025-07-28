
public struct OnboardingViewState {
    public var hasCompletedOnboarding: Bool = false
    public var currentPage: Int = 0
    
    public init(hasCompletedOnboarding: Bool = false, currentPage: Int = 0) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.currentPage = currentPage
    }
}

extension OnboardingViewState: Equatable {}
