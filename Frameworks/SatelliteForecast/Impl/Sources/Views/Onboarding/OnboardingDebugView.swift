//
//  OnboardingDebugView.swift
//  SatelliteForecast
//
//  Created by Copilot on 7/22/25.
//

import SwiftUI

#if DEBUG
public struct OnboardingDebugView: View {
    let onComplete: () -> Void
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack {
            Text("Debug Onboarding")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This is a debug version of the onboarding screen")
                .font(.title3)
                .padding()
            
            Button("Complete Onboarding") {
                onComplete()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundColor(.white)
    }
}
#endif
