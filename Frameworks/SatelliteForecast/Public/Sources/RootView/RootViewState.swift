public struct RootViewState {
    public var selectedTab: Tab
    
    public init(selectedTab: Tab = .forecast) {
        self.selectedTab = selectedTab
    }
}

extension RootViewState: Equatable {}
