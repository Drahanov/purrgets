import SwiftUI

/// The first-launch intro, in two steps: meet Mr. Joe Long asleep on a pile of widgets and shake
/// him off, then pull him (hanging from the top of the screen) to see that a longer cat is more time.
struct IntroFlow: View {
    var done: () -> Void

    @State private var pulling = false

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            if pulling {
                PullCatOnboarding(entrance: true, done: done)
                    .transition(.opacity)
            } else {
                MeetJoe(leapt: {
                    withAnimation(.easeOut(duration: 0.2)) { pulling = true }
                }, skip: done)
                .transition(.opacity)
            }
        }
        .task {
            #if DEBUG
            // For screenshots: --intro-pull goes straight to step two.
            if ProcessInfo.processInfo.arguments.contains("--intro-pull") { pulling = true }
            #endif
        }
    }
}
