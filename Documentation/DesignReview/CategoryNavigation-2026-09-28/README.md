# Category navigation transitions

The category stack now binds directly to a local SwiftUI State path, synchronizing
with the existing model/session path after changes. Pass-grid navigation shares
that local binding. This avoids routing native link transactions through a
computed model-state binding. Existing destination registrations are unchanged.

`testCategoryNavigationPushesAndBackSynchronizes` hosts the actual category view,
pushes each of the three category values with an animated transaction, confirms
the UIKit transition coordinator reports an animated transition, and pops back
through UINavigationController while checking that the model path returns empty.
It uses cached empty catalogs to avoid network work. This verifies native route
transitions and synchronization; it does not synthesize physical taps on rows.
The existing destination-during-catalog-reload regression also passes.

Reviewed `categories-dark.png` on the dark iPhone 17 Pro Max simulator. Simulator
and device builds passed; installed and launched on the connected iPhone.
