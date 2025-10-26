import SwiftUI
import CoreMotion
import SatelliteKit
import SatelliteForecast

/// A view that guides the user to orient their device with the screen pointing down and camera pointing skyward
struct DeviceOrientationGuidanceView: View {
    let deviceMotionResult: Loadable<CMDeviceMotion, Error>
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isCriteriaMet: Bool = false
    @State private var shouldShow: Bool = true
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Lift up your device towards the sky", bundle: .module)
                    .font(.caption)
                    .foregroundColor(Color(UIColor.label))
                
                if case .loaded(let motion) = deviceMotionResult {
                    let pitch = motion.attitude.pitch * rad2deg
                    let roll = motion.attitude.roll * rad2deg
                    let progress = min(max(0, 1 - (abs(pitch) / 90)), max(0, 1 - (min(abs(roll - 180), abs(roll + 180)) / 30)))
                    let currentCriteriaMet = abs(pitch) < 30 && min(abs(roll - 180), abs(roll + 180)) < 30
                    
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 16, height: 16)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                currentCriteriaMet ? Color.green : Color.orange,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .frame(width: 16, height: 16)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: progress)
                        
                        if currentCriteriaMet {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    .onChange(of: currentCriteriaMet, initial: true) { oldValue, newValue in
                        if newValue != oldValue {
                            isCriteriaMet = newValue
                            
                            if newValue {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    shouldShow = false
                                }
                            } else {
                                withAnimation(.easeIn(duration: 0.25)) {
                                    shouldShow = true
                                }
                            }
                        }
                    }
                }
            }
            
            // Show detailed progress when device motion is available
            if case .loaded(let motion) = deviceMotionResult {
                let pitch = motion.attitude.pitch * rad2deg
                let roll = motion.attitude.roll * rad2deg
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Pitch:", bundle: .module, comment: "The attitude noun as in 'roll', 'pitch', 'yaw'")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(pitch))°", bundle: .module)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(abs(pitch) < 30 ? .green : .orange)
                        }
                        
                        ProgressView(value: max(0, 1 - (abs(pitch) / 90)))
                            .progressViewStyle(LinearProgressViewStyle(tint: abs(pitch) < 30 ? .green : .orange))
                            .scaleEffect(y: 0.5)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Roll:", bundle: .module, comment: "The attitude noun as in 'roll', 'pitch', 'yaw'")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(roll))°", bundle: .module)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(min(abs(roll - 180), abs(roll + 180)) < 30 ? .green : .orange)
                        }
                        
                        ProgressView(value: max(0, 1 - (min(abs(roll - 180), abs(roll + 180)) / 30)))
                            .progressViewStyle(LinearProgressViewStyle(tint: min(abs(roll - 180), abs(roll + 180)) < 30 ? .green : .orange))
                            .scaleEffect(y: 0.5)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Color.clear.blurEffect()
                .cornerRadius(8)
                .blurEffectStyle(colorScheme == .light ? .systemMaterialLight : .systemMaterialDark)
                .vibrancyEffectStyle(.fill)
        )
        .padding(.horizontal, 32)
        .opacity(shouldShow ? 1.0 : 0.0)
    }
}
