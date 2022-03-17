//
//  DynamicTabBarItemView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/5/22.
//

import SwiftUI

/// A view that offers different children to render based on whether it is selected.
struct DynamicTabBarItemView<Content, SelectedContent>: View where Content: View, SelectedContent: View {
    @Binding var isSelected: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let selectedContent: () -> SelectedContent

    init(
        isSelected: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder selectedContent: @escaping () -> SelectedContent
    ) {
        self._isSelected = isSelected
        self.content = content
        self.selectedContent = selectedContent
    }

    var body: some View {
        if isSelected {
            selectedContent()
        } else {
            content()
        }
    }
}

#if DEBUG

struct DynamicTabBarItemView_Previews: PreviewProvider {
    static var previews: some View {
        DynamicTabBarItemView(
            isSelected: .constant(true),
            content: {
                Text(verbatim: "Should not show unselected 1")
            },
            selectedContent: {
                Text(verbatim: "Should show selected 1")
            }
        )

        DynamicTabBarItemView(
            isSelected: .constant(false),
            content: {
                Text(verbatim: "Should show unselected 2")
            },
            selectedContent: {
                Text(verbatim: "Should not show selected 2")
            }
        )
    }
}

#endif
