import Flutter
import UIKit
import receive_sharing_intent

class SceneDelegate: FlutterSceneDelegate {

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    let plugin = SwiftReceiveSharingIntentPlugin.instance
    if plugin.hasMatchingSchemePrefix(url: url) {
      _ = plugin.application(UIApplication.shared, open: url, options: [:])
    }
  }
}