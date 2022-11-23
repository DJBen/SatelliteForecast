//
//  TimeDurationPicker.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/21/22.
//

import SwiftUI

struct TimeDurationPicker: UIViewRepresentable {
    typealias UIViewType = UIPickerView

    @Binding var duration: TimeInterval
    var isDisabled: Bool = false

    func makeUIView(context: Context) -> UIPickerView {
        let timeDurationPicker = UIPickerView()
        timeDurationPicker.delegate = context.coordinator
        let index0 = Int(duration / 3600)
        let index1 = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)
        let index2 = Int(duration.truncatingRemainder(dividingBy: 60))
        timeDurationPicker.selectRow(index0, inComponent: 0, animated: false)
        timeDurationPicker.selectRow(index1, inComponent: 1, animated: false)
        timeDurationPicker.selectRow(index2, inComponent: 2, animated: false)
        timeDurationPicker.isUserInteractionEnabled = !isDisabled

        // Add fixed labels to highlight view
        let hourLabel = UILabel()
        hourLabel.text = "hours"
        hourLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        hourLabel.textColor = UIColor.label
        hourLabel.translatesAutoresizingMaskIntoConstraints = false
        timeDurationPicker.subviews[1].addSubview(hourLabel)
        hourLabel.firstBaselineAnchor.constraint(equalTo: timeDurationPicker.subviews[1].bottomAnchor, constant: -9).isActive = true
        hourLabel.leadingAnchor.constraint(equalTo: timeDurationPicker.subviews[1].leadingAnchor, constant: 38).isActive = true

        let minuteLabel = UILabel()
        minuteLabel.text = "min"
        minuteLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        minuteLabel.textColor = UIColor.label
        minuteLabel.translatesAutoresizingMaskIntoConstraints = false
        timeDurationPicker.subviews[1].addSubview(minuteLabel)
        minuteLabel.firstBaselineAnchor.constraint(equalTo: timeDurationPicker.subviews[1].bottomAnchor, constant: -9).isActive = true
        minuteLabel.leadingAnchor.constraint(equalTo: timeDurationPicker.subviews[1].leadingAnchor, constant: 148).isActive = true

        let secLabel = UILabel()
        secLabel.text = "sec"
        secLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        secLabel.textColor = UIColor.label
        secLabel.translatesAutoresizingMaskIntoConstraints = false
        timeDurationPicker.subviews[1].addSubview(secLabel)
        secLabel.firstBaselineAnchor.constraint(equalTo: timeDurationPicker.subviews[1].bottomAnchor, constant: -9
        ).isActive = true
        secLabel.leadingAnchor.constraint(equalTo: timeDurationPicker.subviews[1].leadingAnchor, constant: 261).isActive = true

        return timeDurationPicker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        uiView.isUserInteractionEnabled = !isDisabled
    }

    func makeCoordinator() -> TimeDurationPicker.Coordinator {
        Coordinator(duration: $duration)
    }

    class Coordinator: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
        private var duration: Binding<TimeInterval>

        init(duration: Binding<TimeInterval>) {
            self.duration = duration
        }

        // MARK: - UIPickerViewDelegate
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            duration.wrappedValue = TimeInterval(pickerView.selectedRow(inComponent: 0) * 3600 + pickerView.selectedRow(inComponent: 1) * 60 + pickerView.selectedRow(inComponent: 2))
        }

        // MARK: - UIPickerViewDataSource
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 3
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0:
                return 25
            case 1, 2:
                return 60
            default:
                return 0
            }
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            return pickerView.frame.width / 3
        }

        func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            let mutableString = NSMutableAttributedString(
                string: "\(row)",
                attributes: [.paragraphStyle: paragraphStyle]
            )
            mutableString.append(
                NSAttributedString(
                    string: "xxxxx",
                    attributes: [
                        .foregroundColor: UIColor.clear,
                        .paragraphStyle: paragraphStyle
                    ]
                )
            )
            return mutableString.copy() as? NSAttributedString
        }
    }
}

#if DEBUG

struct TimeDurationPicker_Previews: PreviewProvider {
    static var previews: some View {
        TimeDurationPicker(duration: .constant(60.0 * 30.0))
    }
}

#endif
