import Flutter
import UIKit
import receive_sharing_intent

class SceneDelegate: FlutterSceneDelegate {

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    // receive_sharing_intent 1.9.0 exports ReceiveSharingIntentPlugin. The
    // older SwiftReceiveSharingIntentPlugin name does not exist in this
    // package, which caused the iOS CI compile failure.
    let plugin = ReceiveSharingIntentPlugin.instance
    if plugin.hasMatchingSchemePrefix(url: url) {
      _ = plugin.application(UIApplication.shared, open: url, options: [:])
    }
  }
}
