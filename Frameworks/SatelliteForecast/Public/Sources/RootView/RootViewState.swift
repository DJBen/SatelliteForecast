public struct RootViewState {
    public var selectedTab: Tab
    public var showExperimentalSkyNow: Bool
    
    public init(selectedTab: Tab = .forecast, showExperimentalSkyNow: Bool = false) {
        self.selectedTab = selectedTab
        self.showExperimentalSkyNow = showExperimentalSkyNow
    }
}

extension RootViewState: Equatable {}
