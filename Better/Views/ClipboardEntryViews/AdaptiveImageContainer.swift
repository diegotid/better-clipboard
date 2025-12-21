//
//  AdaptiveImageContainer.swift
//  Better
//
//  Created by Diego Rivera on 27/11/25.
//

import SwiftUI

struct AdaptiveImageContainer: View {
    let image: NSImage
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let imageSize = image.size
            let imageAspectRatio = imageSize.width / imageSize.height
            let containerAspectRatio = size.width / size.height
            let isCropped = abs(imageAspectRatio - containerAspectRatio) > 0.01
            let scaleFactor = min(size.width / imageSize.width, size.height / imageSize.height)
            let isUpscaled = scaleFactor > 1.2
            let shouldBlur = isCropped || isUpscaled
            ZStack {
                if shouldBlur {
                    Image(nsImage: image)
                    .resizable()
                    .aspectRatio(imageSize, contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .blur(radius: 6)
                    .brightness(-0.3)
                    .clipped()
                } else {
                    Image(nsImage: image)
                    .resizable()
                    .aspectRatio(imageSize, contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
