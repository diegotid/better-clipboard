//
//  StatusOverlayContext.swift
//  Better
//
//  Created by Diego Rivera on 14/11/25.
//

import Combine

final class StatusOverlayContext: ObservableObject {
    enum OverlayMode {
        case history
        case translationInput
    }

    @Published var currentIndex: Int = 1
    @Published var totalCount: Int = 1
    @Published var searchText: String = ""
    @Published var translationInputText: String = ""
    @Published var isUpdatingEntries: Bool = false
    @Published var filterPinned: Bool = false
    @Published var filterType: CopiedContentType? = nil
    @Published var overlayMode: OverlayMode = .history
    
    var filtered: Bool {
        filterPinned || filterType != nil
    }

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

    func setTranslationInputTextIfNeeded(_ value: String) {
        if translationInputText != value {
            translationInputText = value
        }
    }

    func setUpdatingEntries(_ value: Bool) {
        if isUpdatingEntries != value {
            isUpdatingEntries = value
        }
    }
}
