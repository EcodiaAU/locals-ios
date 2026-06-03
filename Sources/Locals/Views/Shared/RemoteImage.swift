import SwiftUI
import NukeUI

/// Wrapper around NukeUI's LazyImage. We don't roll our own AsyncImage so
/// we can take Nuke's prefetch, in-memory + disk cache, and proper image
/// decoding off the main thread - the merchant photos are heavy enough
/// that built-in AsyncImage stutters during fast scrolls.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let url {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    } else if state.error != nil {
                        placeholder
                    } else {
                        placeholder.overlay(ProgressView().tint(LocalsTheme.fgMuted))
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Rectangle().fill(LocalsTheme.bgSubtle)
    }
}
