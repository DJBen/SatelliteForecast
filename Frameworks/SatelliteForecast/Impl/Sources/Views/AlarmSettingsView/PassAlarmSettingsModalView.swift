//
//  PassAlarmSettingsModalView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/21/22.
//

import SwiftUI
@preconcurrency import CombineRex
import SatelliteForecast
@preconcurrency import SatelliteKit

public enum PassAlarmSettingsModalViewAction {
    case dismissModal
    case scheduleAlarm(PassNotification, passSnapshots: PassSnapshots)
    case unscheduleAlarm(Pass)
}

extension PassAlarmSettingsModalViewAction: Equatable {}

public struct PassAlarmSettingsModalViewState {
    public var scheduledPassNotifications: Set<ScheduledPassNotification>
    public var showAlarmConfigurationModal: Bool

    public init(
        scheduledPassNotifications: Set<ScheduledPassNotification> = [],
        showAlarmConfigurationModal: Bool = false
    ) {
        self.scheduledPassNotifications = scheduledPassNotifications
        self.showAlarmConfigurationModal = showAlarmConfigurationModal
    }
}

extension PassAlarmSettingsModalViewState: Equatable {}

public struct PassAlarmSettingsModalViewContext {
    public let satelliteName: String
    public let category: SatelliteCategory?
    public let passSnapshots: PassSnapshots
    public let observer: LatLonAlt

    public init(
        satelliteName: String,
        category: SatelliteCategory?,
        passSnapshots: PassSnapshots,
        observer: LatLonAlt
    ) {
        self.satelliteName = satelliteName
        self.category = category
        self.passSnapshots = passSnapshots
        self.observer = observer
    }
}

/// A modal view for alarm settings of an individual pass
public struct PassAlarmSettingsModalView: View {
    @ObservedObject var viewModel: ObservableViewModel<PassAlarmSettingsModalViewAction, PassAlarmSettingsModalViewState>
    let context: PassAlarmSettingsModalViewContext

    @State var selectedTiming: PassNotification.Timing = .rise
    @State var offsetDuration: TimeInterval = 0

    public init(
        viewModel: ObservableViewModel<PassAlarmSettingsModalViewAction, PassAlarmSettingsModalViewState>,
        context: PassAlarmSettingsModalViewContext
    ) {
        self.viewModel = viewModel
        self.context = context

        if let scheduledPassNotification = viewModel.state.scheduledPassNotifications.first(where: { $0.id == context.passSnapshots.pass.notificationIdentifier }) {
            _selectedTiming = State(initialValue: scheduledPassNotification.notification.timing)
            _offsetDuration = State(initialValue: -scheduledPassNotification.notification.timeOffset)
        } else {
            _selectedTiming = State(initialValue: .rise)
            _offsetDuration = State(initialValue: 0)
        }
    }

    private var isNotificationScheduled: Bool {
        return viewModel.state.scheduledPassNotifications.contains(where: { $0.id == context.passSnapshots.pass.notificationIdentifier })
    }

    private func description(for timing: PassNotification.Timing) -> String {
        switch timing {
        case .rise:
            return TimingCell.rise
        case .transit:
            return TimingCell.transit
        case .highestIlluminated:
            return TimingCell.highestIlluminated
        case .set:
            return TimingCell.set
        }
    }

    private func datePosition(for timing: PassNotification.Timing) -> Pass.DatePosition? {
        switch timing {
        case .rise:
            return context.passSnapshots.pass.rise
        case .transit:
            return context.passSnapshots.pass.transit
        case .highestIlluminated:
            return context.passSnapshots.pass.highestIlluminated
        case .set:
            return context.passSnapshots.pass.set
        }
    }

    private var sortedTimings: [PassNotification.Timing] {
        PassNotification.Timing.allCases.filter { timing -> Bool in
            datePosition(for: timing) != nil
        }
        .sorted(by: { datePosition(for: $0)!.julianDate < datePosition(for: $1)!.julianDate })
    }

    @ViewBuilder private func timingCell(
        _ timing: PassNotification.Timing,
        isFirst: Bool,
        isLast: Bool
    ) -> some View {
        Button {
            selectedTiming = timing
        } label: {
            HStack {
                Text(
                    description(for: timing)
                )
                .if(isNotificationScheduled) { text in
                    text.foregroundColor(.secondary)
                }

                Spacer()

                Text(
                    TimingCell.formattedDatePosition(datePosition(for: timing)!)
                )
                .foregroundColor(.secondary)

                if selectedTiming == timing {
                    Image(
                        systemName: "circle.inset.filled"
                    )
                    .foregroundColor(.secondary)
                } else {
                    Image(
                        systemName: "circle"
                    )
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .if(isFirst) {
                $0.padding(.top, 4)
            }
            .if(isLast) {
                $0.padding(.bottom, 4)
            }
        }
        .buttonStyle(AlarmTimingButtonStyle())
        .disabled(isNotificationScheduled)
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .center) {
                VStack(spacing: 0) {
                    ForEach(enumerated: sortedTimings, id: \.self) { index, timing in
                        timingCell(
                            timing,
                            isFirst: index == 0,
                            isLast: index == sortedTimings.count - 1
                        )

                        if index != sortedTimings.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)

                HStack {
                    Text(
                        Self.leadTimeLabel
                    )
                    .font(.headline.lowercaseSmallCaps().weight(.regular))
                    .foregroundColor(Color(UIColor.label))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                TimeDurationPicker(
                    duration: $offsetDuration,
                    isDisabled: isNotificationScheduled
                )

                Spacer()

                HStack {
                    Image(
                        systemName: "bell"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundColor(Color(UIColor.secondaryLabel))

                    Text(
                        Self.alarmLabelText(
                            date: Date(
                                julianDate: datePosition(
                                    for: selectedTiming
                                )!.julianDate
                            )
                            .addingTimeInterval(-offsetDuration)
                        )
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundColor(Color(UIColor.secondaryLabel))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                if isNotificationScheduled {
                    Button(role: .destructive) {
                        viewModel.dispatch(
                            .unscheduleAlarm(
                                context.passSnapshots.pass
                            )
                        )
                    } label: {
                        Text(
                            DeleteButton.title
                        )
                        // Inverse the foreground color because bordered prominent will be entirely white
                        .foregroundColor(Color(uiColor: .label.inversed()))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        let passNotification = PassNotification(
                            pass: context.passSnapshots.pass,
                            satelliteName: context.satelliteName,
                            category: context.category,
                            observer: context.observer,
                            timing: selectedTiming,
                            timeOffset: -offsetDuration
                        )
                        viewModel.dispatch(
                            .scheduleAlarm(
                                passNotification,
                                passSnapshots: context.passSnapshots
                            )
                        )
                    } label: {
                        Text(
                            ConfirmButton.title
                        )
                        // Inverse the foreground color because bordered prominent will be entirely white
                        .foregroundColor(Color(uiColor: .label.inversed()))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle(Text(isNotificationScheduled ? NavigationBar.viewAlarmTitle : NavigationBar.title))
            .navigationBarTitleDisplayMode(UIScreen.main.bounds.height > 700 ? .automatic : .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        NavigationBar.dismiss,
                        role: .cancel
                    ) {
                        viewModel.dispatch(.dismissModal)
                    }
                }
            }
        }
    }
}

struct AlarmTimingButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        if configuration.isPressed {
            return configuration.label.background(Color(UIColor.tertiarySystemGroupedBackground))
        } else {
            return configuration.label.background(Color(UIColor.secondarySystemGroupedBackground))
        }
    }
}

extension PassAlarmSettingsModalView {
    enum NavigationBar {
        static let title = NSLocalizedString(
            "PassAlarmSettingsModalView.navigationBar.title",
            tableName: nil,
            bundle: .module,
            value: "Schedule alarm",
            comment: "Navigation title of pass alarm settings."
        )

        static let viewAlarmTitle = NSLocalizedString(
            "PassAlarmSettingsModalView.navigationBar.title",
            tableName: nil,
            bundle: .module,
            value: "View alarm",
            comment: "Navigation title of pass alarm settings, view alarm"
        )

        static let dismiss = NSLocalizedString(
            "PassAlarmSettingsModalView.navigationBar.discard",
            tableName: nil,
            bundle: .module,
            value: "Dismiss",
            comment: "Title of discard button of pass alarm settings."
        )
    }

    static let leadTimeLabel = NSLocalizedString(
        "PassAlarmSettingsModalView.leadTimeLabel.title",
        tableName: nil,
        bundle: .module,
        value: "Remind me ahead of time...",
        comment: "Title of lead time label of pass alarm settings."
    )

    static func alarmLabelText(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter.string(from: date)
    }

    enum ConfirmButton {
        static let title = NSLocalizedString(
            "PassAlarmSettingsModalView.confirmButton.title",
            tableName: nil,
            bundle: .module,
            value: "Schedule alarm",
            comment: "Title of confirm button of pass alarm settings."
        )
    }

    enum DeleteButton {
        static let title = NSLocalizedString(
            "PassAlarmSettingsModalView.deleteButton.title",
            tableName: nil,
            bundle: .module,
            value: "Delete alarm",
            comment: "Title of delete button of pass alarm settings."
        )
    }

    enum TimingCell {
        static func formattedDatePosition(
            _ datePosition: Pass.DatePosition
        ) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .medium
            return dateFormatter.string(from: Date(julianDate: datePosition.julianDate))
        }

        static let rise = NSLocalizedString(
            "PassAlarmSettingsModalView.timingCell.rise",
            tableName: nil,
            bundle: .module,
            value: "Upon rising",
            comment: "Description of the alarm timing, rise."
        )

        static let transit = NSLocalizedString(
            "PassAlarmSettingsModalView.timingCell.transit",
            tableName: nil,
            bundle: .module,
            value: "Highest point",
            comment: "Description of the alarm timing, transit."
        )

        static let set = NSLocalizedString(
            "PassAlarmSettingsModalView.timingCell.set",
            tableName: nil,
            bundle: .module,
            value: "Upon setting",
            comment: "Description of the alarm timing, set."
        )

        static let highestIlluminated = NSLocalizedString(
            "PassAlarmSettingsModalView.timingCell.highestIlluminated",
            tableName: nil,
            bundle: .module,
            value: "Highest illuminated",
            comment: "Description of the alarm timing, highest illuminated."
        )
    }
}

#if DEBUG

struct PassAlarmSettingsModalView_Previews: PreviewProvider {
    static var previews: some View {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21155.08058252  .00001489  00000-0  35252-4 0  9997
            2 25544  51.6446  47.5538 0003512  61.1482  91.5411 15.48950578286563
            """
        )
        // 2000 Broadway, Redwood City, CA 94063
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        // Date range
        let startDate = Date(timeIntervalSinceReferenceDate: 20 * 365 * 86400)
        let julianDateRange = startDate.advanced(by: -60 * 60 * 2).julianDate...startDate.advanced(by: 60 * 60 * 30).julianDate
        let coarseSnapshots = try! SatelliteInfo(elements: elements).generateSnapshots(
            observer: observer,
            julianDateRange: julianDateRange,
            interval: 60
        )
        let passSnapshotsList = try! SatelliteInfo(elements: elements).findPasses(
            observer: observer,
            coarseSnapshots: coarseSnapshots
        )

        PassAlarmSettingsModalView(
            viewModel: .mock(
                state: PassAlarmSettingsModalViewState()
            ),
            context: PassAlarmSettingsModalViewContext(
                satelliteName: "ISS (ZARYA)",
                category: nil,
                passSnapshots: passSnapshotsList[0],
                observer: LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
            )
        )
    }
}

#endif

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
