import Foundation
import SwiftUI

public struct FlippingTextView: View {
    @State private var currentItemIndex = 0
    @State private var nextItemIndex = 1
    @State private var currentOffset: CGFloat = 0
    @State private var nextOffset: CGFloat = 60
    @State private var currentOpacity: Double = 1.0
    @State private var nextOpacity: Double = 0.0
    @State private var timer: Timer?
    @State private var idealSize: CGSize = .zero

    private let items: [String]
    private let font: Font
    private let fontWeight: Font.Weight
    private let foregroundColor: Color

    public init(items: [String], font: Font = .largeTitle, fontWeight: Font.Weight = .bold, foregroundColor: Color = .white) {
        self.items = items
        self.font = font
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        
        if !items.isEmpty {
            self._nextItemIndex = State(initialValue: 1 % items.count)
        }
    }

    public var body: some View {
        ZStack {
            // Measurement layer
            ZStack {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(font)
                        .fontWeight(fontWeight)
                        .multilineTextAlignment(.center)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: FlippingTextSizePreferenceKey.self, value: geometry.size)
                        })
                }
            }
            .onPreferenceChange(FlippingTextSizePreferenceKey.self) { newSize in
                guard let newSize, newSize != .zero else { return }
                if newSize.width > idealSize.width || newSize.height > idealSize.height {
                    idealSize = newSize
                }
            }
            .opacity(0)

            // Content layer
            ZStack {
                if !items.isEmpty {
                    Text(items[currentItemIndex])
                        .font(font)
                        .fontWeight(fontWeight)
                        .foregroundColor(foregroundColor)
                        .multilineTextAlignment(.center)
                        .offset(y: currentOffset)
                        .opacity(currentOpacity)

                    Text(items[nextItemIndex])
                        .font(font)
                        .fontWeight(fontWeight)
                        .foregroundColor(foregroundColor)
                        .multilineTextAlignment(.center)
                        .offset(y: nextOffset)
                        .opacity(nextOpacity)
                } else {
                    Text(" ") // Placeholder for empty array
                        .font(font)
                        .fontWeight(fontWeight)
                }
            }
            .frame(width: idealSize.width, height: idealSize.height)
        }
        .onAppear(perform: startFlipping)
        .onDisappear(perform: stopFlipping)
    }

    private func startFlipping() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            guard !items.isEmpty, items.count > 1 else { return }

            withAnimation(.easeInOut(duration: 0.5)) {
                currentOffset = -60
                currentOpacity = 0.0
                nextOffset = 0
                nextOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentItemIndex = nextItemIndex
                nextItemIndex = (nextItemIndex + 1) % items.count

                currentOffset = 0
                currentOpacity = 1.0
                nextOffset = 60
                nextOpacity = 0.0
            }
        }
    }

    private func stopFlipping() {
        timer?.invalidate()
        timer = nil
    }
}

private struct FlippingTextSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize? = nil
    static func reduce(value: inout CGSize?, nextValue: () -> CGSize?) {
        guard let nextValue = nextValue() else { return }
        if let currentValue = value {
            value = CGSize(width: max(currentValue.width, nextValue.width), height: max(currentValue.height, nextValue.height))
        } else {
            value = nextValue
        }
    }
}
