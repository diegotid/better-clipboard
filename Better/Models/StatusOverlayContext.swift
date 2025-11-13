//
//  StatusOverlayContext.swift
//  Better
//
//  Created by Diego Rivera on 14/11/25.
//

import Combine

final class StatusOverlayContext: ObservableObject {
    @Published var currentIndex: Int = 1
    @Published var totalCount: Int = 1
    @Published var searchText: String = ""

    func update(index: Int, total: Int) {
        if currentIndex != index {
            currentIndex = index
        }
        if totalCount != total {
            totalCount = total
        }
    }

    func setSearchTextIfNeeded(_ value: String) {
        if searchText != value {
            searchText = value
        }
    }
}
