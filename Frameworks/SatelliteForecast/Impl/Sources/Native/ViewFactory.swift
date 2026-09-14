import SwiftUI

/// A typed view-building closure. Contains no state, subscriptions, or action routing.
@MainActor
public struct ViewFactory<Context, ProducedView: View> {
  private let build: (Context) -> ProducedView
  public init(_ build: @escaping (Context) -> ProducedView) { self.build = build }
  public func view(_ context: Context) -> ProducedView { build(context) }
  public static func pure(_ view: ProducedView) -> Self { Self { _ in view } }
  public static var crash: Self { Self { _ in fatalError("Preview destination was opened") } }
}
extension ViewFactory where Context == Void {
  public func view() -> ProducedView { build(()) }
}
