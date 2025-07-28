public enum PassAlarmSettingsModalViewAction {
    case dismissModal
    case scheduleAlarm(PassNotification, passSnapshots: PassSnapshots)
    case unscheduleAlarm(Pass)
}

extension PassAlarmSettingsModalViewAction: Equatable {}
