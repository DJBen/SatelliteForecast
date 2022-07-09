//
//  AlwaysPopoverModifier.swift
//  Popovers
//
//  Copyright © 2021 PSPDFKit GmbH. All rights reserved.
//

import SwiftUI

struct AlwaysPopoverModifier<PopoverContent>: ViewModifier where PopoverContent: View {
    
    let isPresented: Binding<Bool>
    let contentBlock: () -> PopoverContent

    @Environment(\.colorScheme) var colorScheme

    // Workaround for missing @StateObject in iOS 13.
    private struct Store {
        var anchorView = UIView()
    }
    @State private var store = Store()
    
    func body(content: Content) -> some View {
        return content.background(
            InternalAnchorView(uiView: store.anchorView)
        )
        .onChange(of: isPresented.wrappedValue) { isPresented in
            if isPresented {
                presentPopover()
            }
        }
    }
    
    private func presentPopover() {
        let contentController = AlwaysPopoverContentViewController(
            rootView: contentBlock(),
            isPresented: isPresented
        )
        contentController.modalPresentationStyle = .popover
        contentController.overrideUserInterfaceStyle = colorScheme == .light ? .light : .dark

        let view = store.anchorView
        guard let popover = contentController.popoverPresentationController else { return }
        popover.sourceView = view
        popover.sourceRect = view.bounds
        popover.delegate = contentController

        guard let sourceVC = view.closestVC() else { return }
        if let presentedVC = sourceVC.presentedViewController {
            presentedVC.dismiss(animated: true) {
                sourceVC.present(contentController, animated: true)
            }
        } else {
            sourceVC.present(contentController, animated: true)
        }
    }
    
    private struct InternalAnchorView: UIViewRepresentable {
        typealias UIViewType = UIView
        let uiView: UIView
        
        func makeUIView(context: Self.Context) -> Self.UIViewType {
            uiView
        }
        
        func updateUIView(_ uiView: Self.UIViewType, context: Self.Context) {
        }
    }
}
