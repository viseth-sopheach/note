# Viseth

## iOS IPA from GitHub Actions

The `Build iOS IPA` workflow runs on a GitHub-hosted macOS 26 runner, installs
Flutter 3.50.0 dependencies, and builds the app with its Share Extension and
existing App Group (`group.com.viset.visethnote`). Download the
`viseth-ios-ipa` artifact from the completed run in the repository's Actions
tab.

Without Apple signing secrets, Actions uploads `Viseth-unsigned.ipa` for build
inspection only; iOS will not install that unsigned package. To produce a
signed IPA for App Store Connect/TestFlight distribution, add these repository
Actions secrets:

| Secret | Value |
| --- | --- |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64 of the Apple Distribution `.p12` certificate containing its private key |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password used when exporting that `.p12` |
| `IOS_PROVISIONING_PROFILE_APP_BASE64` | Base64 of an App Store Connect distribution profile for `com.viset.visethnote` |
| `IOS_PROVISIONING_PROFILE_EXTENSION_BASE64` | Base64 of an App Store Connect distribution profile for `com.viset.visethnote.ShareExtension` |
| `IOS_TEAM_ID` | Apple Developer Team ID for the certificate and profiles |

Both profiles must include the `group.com.viset.visethnote` App Group, and the
App Group must be enabled for both bundle identifiers in the Apple Developer
portal. Once all five secrets are set, the workflow validates the profile IDs
and App Group, signs both targets, verifies their signatures, and uploads
`Viseth-signed.ipa`. App Store Connect builds can then be uploaded to TestFlight
for installation by testers.

From Windows, trigger the workflow at
<https://github.com/viseth-sopheach/note/actions>; no local macOS or Xcode is
needed.
