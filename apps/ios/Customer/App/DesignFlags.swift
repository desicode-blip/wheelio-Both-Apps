import Foundation

/// Designs that are built and kept, but hidden for now. Flip a flag to bring one back
/// exactly as it was (nothing was deleted). See docs/hidden-designs.md.
enum DesignFlags {
    /// C40 "Hi there / Book your first wash / How it works" Home for first-time customers.
    /// Off: first-time customers land straight on "What are we washing?" (C05).
    static let firstWashHome = false
    /// "Step 1 of 5" progress bar on the first booking step (C05). Later steps keep it.
    static let firstStepProgress = false
}
