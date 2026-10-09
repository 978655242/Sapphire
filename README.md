<div align="center">
<img width="220" height="220" alt="Group 31" src="https://github.com/user-attachments/assets/1e3ef88f-9849-4896-88d2-5294841a0062" />

  <h1>Sapphire</h1>
  <p><b>The all-in-one mac app that redefines the notch</b></p>
  <a href="https://sapphire-app.tech" style="text-decoration: none; margin-right: 10px;">
    <div style="background-color: #007aff; color: white; padding: 10px 20px; border-radius: 8px; display: inline-block; font-weight: bold;">
      Official Website
    </div>
  </a>
  <a href="https://github.com/cshariq/Sapphire/releases/latest" style="text-decoration: none;">
    <div style="background-color: #007aff; color: white; padding: 10px 20px; border-radius: 8px; display: inline-block; font-weight: bold;">
      Download Latest Release
    </div>
  </a>
  <a href="https://discord.gg/Ryuea8vM2h" style="text-decoration: none;">
    <div style="background-color: #007aff; color: white; padding: 10px 20px; border-radius: 8px; display: inline-block; font-weight: bold;">
      Join Discord
    </div>
  </a>
</div>

<br>

Sapphire is a sleek notch app that displays current activities neatly around the notch on newer MacBooks. It also includes a suite of convenient features, from nearby share compatibility for easy file transfers to a versatile window snapping system.

## Installation

1.  **Download:** Download the latest package release from the [releases page](https://github.com/cshariq/Sapphire/releases/latest).
2.  **Install:** Open the downloaded package and follow the installation process.
3.  **Permissions:** At startup, Sapphire automatically requests location permission for local weather if it has not been decided yet. It then guides you through missing macOS permissions one at a time, with location first, before starting the notch and background services. Already granted permissions are skipped; denied permissions link to `System Settings`. You can skip a permission or cancel the guide and continue launching. Music/Spotify Automation consent is never requested by this guide; request it explicitly from the permissions overview when needed.

This local fork does not manage or monitor batteries: charging/discharging control, calibration, MagSafe LED control, low-power policies, battery history/alerts/widgets, and peripheral/phone battery telemetry are removed from both the app and helper. Update and restart both components together; helper protocol 14 no longer exposes battery or fan control APIs. Existing preferences migrate without resetting unrelated settings, and historical battery logs are not deleted. The new version does not reset hardware state left by an older build or another charge/fan controller; recover any existing charging inhibit or manual fan mode separately before upgrading.

The **Monitoring**, **Archives & DMG**, and **App Lock** settings sections and their dedicated implementations are removed, including menu-bar readouts/alerts, fan control/scheduling, archive extraction/DMG installation, file-handler registrations, and app-lock authentication. Old preferences for those features are ignored on import; unrelated authentication, Keychain credentials, File Shelf transfers, software-update archive validation, and statistics used by live activities and the lock screen remain. Existing macOS default-file associations are not reset by editing this source checkout.

### Local development builds

Public-source development builds can include unavailable private-feature implementations; they are not equivalent to the complete official release. Keep an application and preferences backup before replacing an installed release. Supply a valid, ignored local `Sapphire/App/GoogleService-Info.plist`; the public placeholder is not a working Firebase configuration.

This local developer fork uses `com.yuxi.sapphire.local` and its own helper/widget identifiers so a different Apple developer team can provision it legitimately. Import the original preferences into the local bundle's domain when upgrading; the original preferences and signing identity remain separate.

The local app builds and installs as `Island.app`, with `Island` as its macOS application name. The Xcode scheme and Swift module remain `Sapphire`; bundle identifiers, preferences domains, keychain accounts and helper identifiers are unchanged.

Island stays a background (`LSUIElement` / accessory) app even while settings, lyrics, or permission/helper dialogs are open. Closing settings keeps the notch running without creating a running-app Dock icon or a new recent-app entry. Existing Dock shortcuts or recent entries are owned by macOS and may need to be removed once through the Dock menu; Island does not rewrite Dock preferences.

macOS privacy permissions belong to an application's signing identity, not its display name. An enabled `Sapphire` entry for the official `com.cshariq.sapphire` release does not grant Accessibility or other permissions to `com.yuxi.sapphire.local`. Install the local build at its final path before granting its permissions; existing official-release consent remains untouched.

Startup checks whether an unlock-password record exists using a noninteractive Keychain metadata query, without decrypting the password. Actual password verification and unlock operations keep their normal credential checks; existing credentials are not removed or migrated.

The app and widget use the same signing-team-prefixed macOS app group, resolved from `SapphireAppGroupIdentifier` in their built bundles. Use a genuine development identity and matching provisioning profiles; retain the app-group, keychain and system-extension entitlements.

Self-updates require valid signatures, sealed resources and the installed application's designated signing requirement. A local build signed by a different developer team cannot accept the official publisher's application as an automatic update; reinstall the official release manually rather than bypassing signature checks.

## Language

Open **Settings → General → Language** (**设置 → 通用 → 语言**) and choose **Follow System**, **English**, or **简体中文**. Click **Restart Sapphire** (**重新启动 Sapphire**) to apply the choice; pending settings are saved before restarting.

The choice is saved for Sapphire only and does not change the Mac's system language. Simplified Chinese covers app-owned feature labels, menus, descriptions, alerts, permission explanations, and desktop widget text. App names, device names, filenames, media titles, and other user or provider content keep their original names.

Translations use Apple's `Localizable.xcstrings` and `InfoPlist.xcstrings` catalogs in the app and widget targets. Keep English and `zh-Hans` translations and their format placeholders in sync when adding interface text.

## Features

<div style="display: flex; flex-wrap: wrap; gap: 16px; justify-content: center;">

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Nearby Share</h3>
    <p>Allows sharing files, pictures, videos, websites, and more from Android to your mac!</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Now Playing</h3>
    <p>Displays currently playing media of all types in the notch (works with macOS 15.5 as well), and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Advanced Audio Features (Beta)</h3>
    <p>Adjust individual app volumes, device volumes, app EQs and device EQs right from the notch</p>
  </div>
  
  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Eye Break</h3>
    <p>Health should always be your priority. With the sleek notch UI, a reminder is given every 20 minutes to look 20 feet away for 20 seconds, and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Weather</h3>
    <p>Current weather is persistently shown in the notch, so you're in the know about your surroundings, and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Gemini</h3>
    <p>Share your screen and discuss topics conveniently using Gemini Live, and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Calendar</h3>
    <p>See upcoming events and get alerted for ongoing events, and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Lock Screen</h3>
    <p>See the weather, your music, and upcoming calendar events on your Mac's lockscreen, and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">File Shelf</h3>
    <p>Airdrop and store files conveniently with access to the file shelf, and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Snap Zones</h3>
    <p>Snapping windows using macOS's built-in snapping tools is limited and leaves a gap between windows. Sapphire provides a versatile and customizable window snapping system, and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Music</h3>
    <p>View now playing media on the notch with additional information and controls when the now playing media is expanded, and more.</p>
    <p>Library and queue integration is available for Spotify and Apple Music. Spotify login is required only for Spotify. Other system players, including NetEase Cloud Music, use system playback controls; clicking a track opens its source app instead of Spotify's library. Unsupported playlist and queue controls are hidden.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Bluetooth</h3>
    <p>Get a notice when a Bluetooth device connects to your Mac, and more.</p>
  </div>

  <div style="border: 1px solid #30363d; border-radius: 8px; padding: 16px; width: 300px; background-color: #1c1c1e;">
    <h3 style="margin-top: 0;">Caffeinate</h3>
    <p>Caffeinate your Mac with a press of a button, and more.</p>
  </div>

</div>
