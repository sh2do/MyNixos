# Focus mode, lock screen extras, pond-glass clipboard and emoji picker

The user said "keep going" after the weather, boot and sound work, so these come from the list of ideas offered earlier. Every call below is mine, and the user reviews them after they're built.

## 1. Focus mode (both desktops)
- **Toggle:**
  - niri: a bar button (a lotus or moon glyph near the other toggles), Mod+Shift+F if it's free (otherwise pick a free bind and say so), and a `rice-focus [on|off|toggle]` command;
  - Umbriel: the same command and a bind;
  - the phone: a "Focus" button added to `phone-commands.sh`.
- **State:** one file, `$RICE_STATE_DIR/focus` (or similar), shared by both shells. Each shell watches it with a FileView or a slow poll.
- **While on:**
  - Notifications are held: no popups and no sounds. They're kept in a list, and critical notifications still show (with the caw).
  - When focus ends, one summary card appears: "N held while you focused", grouped by app, with the usual grouped-card look.
  - **The raven** sleeps on both desktops.
  - **The koi** drift slowly, with no music reaction.
  - **Umbriel's viper** hangs still and doesn't drip.
  - **The bar** shows a small "focus" chip with the elapsed time, updated each minute.
  - Phone forwarding of critical notifications stays on.
- **Cost:** no new always-on work.

## 2. Lock screen extras (`modules/lock`, the rice-lock Quickshell config with the Tokyo rain video)
- In the same pond-glass style, small and low on the screen:
  - **now playing** (art, title and artist) with play/pause, previous and next;
  - **the paired phone's battery** (reuse `Phone.qml` and `phone.js`) and the weather (reuse `Weather.qml`), each only when available.
- Unlocking, the password field and the video must keep working exactly as before.
- Media controls on the lock screen are acceptable here because it's a personal laptop. They're limited to play/pause, previous and next; nothing else.

## 3. Pond-glass clipboard and emoji picker (niri; Umbriel too if its launcher can call it)
- **Today:** `rice-menu clipboard` is a rofi list. Replace it with a Quickshell panel in the wallpaper picker's glass style:
  - a search field;
  - a list of cliphist entries, with image entries shown as thumbnails;
  - Enter pastes or copies; Delete removes the entry.
- **Emoji:** a second tab with a searchable emoji grid. Use a bundled emoji data file from nixpkgs (for example from `rofimoji` or `emoji-picker` data) rather than a hand-made list. Selecting one copies it, and pastes it with wtype if it's available.
- **Binds:** keep the existing clipboard bind pointing at the new panel. Add an emoji bind, Mod+Period if it's free.
- **Fallback:** `rice-menu clipboard` stays, so nothing is lost if the panel fails.
- **Cost:** none while closed.
