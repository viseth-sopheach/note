# Viseth

## iOS IPA from GitHub Actions

The `Build iOS IPA` workflow runs on a GitHub-hosted macOS 26 runner, installs
Flutter 3.50.0 dependencies, and builds the app with its Share Extension and
existing App Group (`group.com.viset.visethnote`). Download the
`viseth-ios-adhoc-ipa` artifact from the completed run in the repository's Actions
tab.

The workflow requires Apple signing secrets and stops at validation if any are
missing. It exports an **Ad Hoc** IPA for direct installation on registered
devices. Create an Apple Distribution certificate with its private key and
export it as a password-protected `.p12`. Create Ad Hoc provisioning profiles
for both bundle IDs below, include the registered iPhone's UDID in each, and
enable the existing App Group (`group.com.viset.visethnote`) for both targets.
The profiles must be issued by the same Apple Developer team as the certificate.

Add these exact names under the GitHub repository's **Settings → Secrets and
variables → Actions → New repository secret**. The workflow expects these
short names directly. If you previously added the `IOS_*` names from an older
setup guide, rename or recreate those secrets using the names below; GitHub
Actions does not treat different secret names as aliases.

| Secret | Value |
| --- | --- |
| `P12_BASE64` | Base64 of the Apple Distribution `.p12` certificate containing its private key |
| `P12_PASSWORD` | Password used when exporting that `.p12` |
| `APP_PROFILE_BASE64` | Base64 of an **Ad Hoc** profile for `com.viset.visethnote` |
| `EXT_PROFILE_BASE64` | Base64 of an **Ad Hoc** profile for `com.viset.visethnote.ShareExtension` |
| `TEAM_ID` | Apple Developer Team ID for the certificate and profiles |

To create the `.p12` Base64 value, export the Apple Distribution certificate
and its private key from Keychain Access on a Mac as a `.p12` file. Set an export
password and save it securely. Encode the file without changing its contents:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12")) | Set-Clipboard
```

Paste the clipboard value as `P12_BASE64`, and set the export password as
`P12_PASSWORD`. On macOS or Linux,
the equivalent encoding command is `base64 < distribution.p12 | tr -d '\n'`.
Encode each downloaded `.mobileprovision` file the same way and set the two
profile secrets `APP_PROFILE_BASE64` and `EXT_PROFILE_BASE64`. Set `TEAM_ID` to
the 10-character Team ID shown in the
Apple Developer membership details. Do not commit the certificate, private key,
password, profiles, or their Base64 values to the repository.

The validation step checks all five secret values and reports the exact GitHub
secret name that is missing. After they are configured, the workflow validates
the profile bundle IDs, team IDs, and App Group; signs the app and Share
Extension; verifies both signatures; and uploads `Viseth-AdHoc.ipa`. Its
`release-testing` export method preserves Ad Hoc signing for the registered
iPhone. The provisioning profiles must be renewed when they expire or when the
set of registered devices changes.

From Windows, trigger the workflow at
<https://github.com/viseth-sopheach/note/actions>; no local macOS or Xcode is
needed.
