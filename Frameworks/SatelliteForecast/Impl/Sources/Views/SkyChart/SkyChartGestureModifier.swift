//
//  SkyChartGestureModifier.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/10/22.
//

import SwiftUI

struct SkyChartGestureModifier: ViewModifier {
    let isGestureEnabled: Bool
    let contentRect: CGRect

    func body(content: Content) -> some View {
        if isGestureEnabled {
            content
            .gesture(
                DragGesture(
                    minimumDistance: 0
                )
                .onChanged { value in
                    let aziEle = SkyChartUtils.aziEle(at: value.location, in: contentRect)
                    print("changed \(value.location)")
                    print("changed \(aziEle)")
                }
                .onEnded { value in
                    print("end \(value.location)")
                }
                .simultaneously(
                    with: TapGesture(
                    )
                    .onEnded {
                        print("tapped")
                    }
                )
            )
        } else {
            content
        }
    }
}

// To intercept the tap gesture while knowing its coordinate, this technique needs to be used.
// https://stackoverflow.com/a/56518293/1085698
struct TapGestureDetectionModifier: ViewModifier {
    let isEnabled: Bool
    let tapped: (CGPoint, CGRect) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.overlay {
                GeometryReader { proxy in
                    let rect = proxy.frame(in: .local)

                    TapGestureDetectionOverlay(
                        tappedCallback: { tapped($0, rect) }
                    )
                }
            }
        } else {
            content
        }
    }
}

struct TapGestureDetectionOverlay: UIViewRepresentable {
    var tappedCallback: (CGPoint) -> Void

    func makeUIView(context: UIViewRepresentableContext<TapGestureDetectionOverlay>) -> UIView {
        let v = UIView(frame: .zero)
        let gesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.tapped)
        )
        v.addGestureRecognizer(gesture)
        return v
    }

    class Coordinator: NSObject {
        var tappedCallback: ((CGPoint) -> Void)
        
        init(tappedCallback: @escaping ((CGPoint) -> Void)) {
            self.tappedCallback = tappedCallback
        }
        
        @MainActor @objc func tapped(gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            self.tappedCallback(point)
        }
    }

    func makeCoordinator() -> TapGestureDetectionOverlay.Coordinator {
        return Coordinator(tappedCallback: self.tappedCallback)
    }

    func updateUIView(
        _ uiView: UIView,
        context: UIViewRepresentableContext<TapGestureDetectionOverlay>
    ) {
    }
}
