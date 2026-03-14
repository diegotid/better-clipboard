//
//  LinkCardView.swift
//  Better
//
//  Created by Diego Rivera on 3/17/25.
//

import SwiftUI

struct LinkCard: View {
    let url: URL
    let metatags: LinkMetatags?
    
    var body: some View {
        ZStack {
            if let imageURL = metatags?.image {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Color.secondary.opacity(0.12)
                    case .failure:
                        Color.secondary.opacity(0.12)
                    case .success(let image):
                        GeometryReader { geo in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                    @unknown default:
                        Color.secondary.opacity(0.12)
                    }
                }
            } else {
                Color.secondary.opacity(0.08)
            }
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "safari")
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayTitle)
                                .font(.headline)
                                .lineLimit(2)
                            Text(url.host ?? url.absoluteString)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    if let description = metatags?.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .lineLimit(3)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.primary)
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var displayTitle: String {
        if let title = metatags?.title, !title.isEmpty {
            return title
        }
        return url.absoluteString
    }
}
