//
//  About.swift
//  Better
//
//  Created by Diego Rivera on 5/11/25.
//

import SwiftUI

struct About: View {
    private var appIconImage: Image? = {
        guard let image = NSImage(named: "BetterIcon") else {
            return nil
        }
        return Image(nsImage: image)
    }()

    private var appVersionLabel: Text? = {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return Text("Version \(version)")
    }()
    
    var body: some View {
        VStack {
            if appIconImage != nil {
                appIconImage!
                    .resizable()
                    .cornerRadius(18)
                    .frame(maxWidth: Frame.aboutIconSize, maxHeight: Frame.aboutIconSize)
            }
            Text("Better")
                .font(.title)
                .bold()
                .padding(.bottom, 10)
            if appVersionLabel != nil {
                appVersionLabel
                    .font(.subheadline)
                    .padding(.bottom, 10)
            }
            Text("© 2025 Diego Rivera")
            if let website = URL(string: "http://cuatro.studio") {
                Link("cuatro.studio", destination: website)
            }
        }
        .padding()
        .frame(width: Frame.aboutWindowWidth, height: Frame.aboutWindowHeight)
    }
}

enum Frame {
    static let aboutWindowWidth: CGFloat = 240
    static let aboutWindowHeight: CGFloat = 260
    static let aboutIconSize: CGFloat = 100
    static let menuBarHeight: Int = 20
}

#Preview {
    About()
}
