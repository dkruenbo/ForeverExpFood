# Implementation Plan

## Goal

Build a lightweight World of Warcraft Forever addon for the beta client, using the Retail API where supported. It detects food whose tooltip grants additional experience from kills, extracts the percentage, and reminds the player when the active XP food buff is weaker than the best available food bonus.

## Proposed Addon Structure

- `ForeverExpFood.toc`: addon metadata, interface version `16001`, saved-variable declaration, and Lua file load order.
- `Core.lua`: event registration, scan scheduling, inventory and aura checks, and reminder coordination.
- `Options.lua`: in-game settings panel and saved preferences, with a scan when the panel closes.
- `ScreenAlert.lua`: movable screen-alert frame with timed or unlimited duration and saved appearance and position.
- `Locale.lua`: user-facing strings and tooltip-matching terms for all standard WoW locales.

Keep the initial implementation small; split files further only if the codebase or beta API requires it.

## Implementation Steps

1. **Verify beta API compatibility**
   - Use interface number `16001` and confirm the addon metadata conventions in the beta client.
   - Confirm bag APIs, bag-change events, aura APIs, event/frame scheduling, and options-panel APIs in the client.
   - Record any differences from Retail API assumptions before relying on them.

2. **Create the addon skeleton**
   - Add the `.toc` and Lua entry points with a single event handler/bootstrap path.
   - Declare a saved-variable table for preferences.
   - Initialize missing settings with validated defaults while preserving existing user settings after updates.

3. **Implement qualifying-food detection**
   - Inspect items in carried bags only; do not count bank storage.
   - Identify qualifying food from a localized tooltip line describing increased kill XP and extract its integer percentage; when a line contains multiple percentages, select the one most closely associated with the experience/increase terms.
   - Select locale-specific matching terms for all standard WoW locales, with English as the fallback for unknown locales.
   - Include Mithril Head Trout as a verification example using its supplied tooltip text.
   - Cache the bag-scan result and invalidate it on bag or item-data changes; handle empty slots, unavailable item data, and asynchronous item information.

4. **Implement active-buff detection**
   - Inspect active auras for the "Well fed" effect and extract its kill-XP percentage.
   - Use the beta-supported aura data/API and verify whether the descriptive text is available without constructing a tooltip.
   - Ensure unrelated buffs do not suppress reminders; an XP buff suppresses only when its percentage is equal to or higher than the best available food bonus.

5. **Coordinate scans and reminders**
   - Check once when the player enters the world or reloads the UI.
   - Recheck when carried bags change, and register player-only aura updates where supported so aura events can reuse the cached bag result.
   - Retain a one-minute periodic scan as a fallback for missed or unavailable events.
   - Suppress reminders and hide visible screen alerts during combat; rescan immediately when combat ends.
   - Notify only when qualifying food is in bags and the active XP buff is absent or weaker than the best food bonus.
   - Track reminder state so repeated scans do not accidentally spam; apply the configured repeat behavior and interval.

6. **Add preferences**
   - Start reminders with default preferences without automatically opening options or requiring setup.
   - Provide an in-game options panel and trigger a scan when it closes.
   - Include independent chat and screen-alert toggles and a control for whether and how often reminders repeat.
   - Offer a disabled-by-default option to remind players to get XP food when a reliable scan finds none and the XP buff is inactive.
   - Allow players to customize screen-alert text, duration, color, and size, preview it, move it, and reset its position.
   - Preserve 1-20 second durations and offer Unlimited at the rightmost slider position, stored as zero; previews must still time out.
   - Add a configurable snooze duration (1, 5, 10, 15, 30, or 60 minutes; default 1 minute) and a dismiss action scoped to the current reminder condition.
   - Add `/fef debug` output for recognized food/buff percentages and relevant tooltip candidate lines; keep `/fef` as the options shortcut.
   - Persist settings between sessions and validate values loaded from saved variables.

7. **Verify behavior in the beta client**
   - Confirm the addon loads without Lua errors and settings survive reloads.
   - Test qualifying food present/absent, matching buff active/inactive, and unrelated food or buffs.
   - Verify 5%, 10%, and 15% XP bonuses are extracted, while unrelated percentages are rejected and the XP value wins over a nearby non-XP percentage.
   - Use `/fef debug` in the English client to inspect detected food/buff percentages and candidate tooltip lines.
   - Exercise localized matching with simulated locale strings; do not require switching the game client language.
   - Review translated tooltip phrases against reliable localized game-data references where available, and document any unverified wording.
   - Test login/reload, bag changes, and the one-minute fallback.
   - Test each alert independently, both alerts together, disabled alerts, and configured repeat behavior.
   - Confirm items in the bank do not trigger reminders and tooltip/API failures do not break scanning.

## Acceptance Criteria

- The addon loads in the target beta client without errors.
- Qualifying food in carried bags is detected from its tooltip effect; bank items are ignored.
- The XP percentage is extracted dynamically; an equal or stronger kill-XP "Well fed" buff suppresses reminders, while unrelated buffs do not.
- Checks run on login/reload, after bag changes, and at least once per minute.
- No reminders are sent during combat; pending conditions are checked immediately after combat ends.
- Reminders work immediately with defaults, options do not open automatically, and closing the options panel triggers a scan.
- Chat and screen alerts can be toggled independently, and repeat behavior is configurable and persists across sessions.
- Repeated scans do not cause reminders more frequently than the configured behavior allows.
- Screen-alert settings and position persist, and the alert can be previewed and repositioned.
- The rightmost duration slider position disables the reminder timeout; finite durations remain 1-20 seconds, and previews remain timed.
- The optional no-food reminder is off by default, uses the selected alert channels and repeat interval, and is suppressed while the XP buff is active or scan data is unresolved.
- Snooze pauses both alert channels until the selected duration elapses, then resumes on the next scan; dismiss suppresses only the current condition until it changes or resolves.
- Snooze is available in 1, 5, 10, 15, 30, and 60 minute choices, defaults to 1 minute, and the alert buttons are hidden in preview mode.
- Addon controls, alerts, and locale-aware tooltip matching support all standard WoW locales, with English fallback.
- Locale-simulated tests cover matching behavior without requiring non-English client installations.

## Decisions to Confirm During Implementation

- Verify options-panel registration and remaining API assumptions in the beta client.
- Verify English tooltip behavior in the Forever client.
- Review non-English UI and tooltip terms against localized reference data; clearly track wording that cannot be independently verified.
