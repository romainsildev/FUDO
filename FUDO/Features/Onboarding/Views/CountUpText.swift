import SwiftUI

/// A number that climbs. SwiftUI does not animate an interpolated `Text`, so the
/// view itself is `Animatable`: the system drives `animatableData` frame by frame
/// and the body re-renders the formatted value.
///
/// `format` is passed in rather than baked: OB 06 runs the value through
/// `ShockMath.headline(for:)`, so the number in flight and the number at rest can
/// never be written two different ways.
struct CountUpText: View, Animatable {
    var value: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}
