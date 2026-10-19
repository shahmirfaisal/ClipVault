# ClipVault

A free, open-source clipboard manager for macOS. ClipVault remembers everything you copy — text, links, images and files — and lets you paste any of it again with one shortcut.

## Features

- **⇧⌘V** opens your history in a panel at the bottom of the screen
- Text, links, images and files, with previews (images, PDFs, videos, documents)
- Pick a card and press **Return** — it pastes straight into the app you're using
- **Search** by typing, **⌘1–⌘9** to paste the first nine items
- **Pin** items you use often (⌘P) — pinned items are never removed
- History is kept after restarts
- Ignores passwords from password managers, plus any apps you exclude
- Change the shortcut, history size and launch-at-login in Settings

## Keyboard shortcuts (in the panel)

| Keys | Action |
|---|---|
| ← → | Select item |
| Return | Paste |
| ⌘C | Copy without pasting |
| ⌘P | Pin / unpin |
| ⌘⌫ | Delete |
| Tab | Switch between History and Pinned |
| ⌘, | Settings |
| Esc | Close |

## Install

Requires **macOS 14.6 or later** (Apple Silicon or Intel).

1. Download the latest `ClipVault-x.x.dmg` from [Releases](../../releases).
2. Open it and drag **ClipVault** into **Applications**.
3. Open ClipVault. macOS will say *"Apple could not verify ClipVault is free of malware"* — this is expected, because ClipVault isn't distributed through Apple's paid developer program. Click **Done**.
4. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the ClipVault message. Confirm with your password. You only do this once.

   If you see the same message when opening the `.dmg`, use **Open Anyway** for it in the same way.

   <details><summary>Prefer Terminal?</summary>

   After dragging ClipVault into Applications, this removes the download flag so it opens normally:

   ```bash
   xattr -dr com.apple.quarantine /Applications/ClipVault.app
   ```
   </details>
5. When asked, allow **Accessibility** for ClipVault (**System Settings → Privacy & Security → Accessibility**). This is what lets ClipVault paste for you. Without it, choosing an item only copies it.

The clipboard icon appears in your menu bar — press **⇧⌘V** to start.

## Privacy

- Your history is stored **only on your Mac**, in `~/Library/Application Support/ClipVault/`. Nothing is ever sent anywhere — ClipVault makes no network connections.
- Items that password managers mark as private are never saved.
- You can exclude other apps in Settings, and clear history at any time (pinned items are kept).

The code is open, so you can check all of this yourself.

## Build from source

Requires Xcode 16 or later.

```bash
git clone <this repo>
cd ClipVault
open ClipVault.xcodeproj
```

Then press ⌘R. To build a signed DMG, create a code-signing certificate named "ClipVault Developer" (or change `SIGN_ID` in `scripts/release.sh`) and run:

```bash
./scripts/release.sh
```

## Related

- [DropShelf](https://github.com/shahmirfaisal/DropShelf) — a free drag-and-drop shelf for macOS: shake while dragging to park files, then drop them anywhere.
- [PinShot](https://github.com/shahmirfaisal/PinShot) — floating screenshots: capture part of the screen and keep it pinned on top, with text recognition

## License

MIT — see [LICENSE](LICENSE).
