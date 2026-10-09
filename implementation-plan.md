# Implementation Plan

## Goal

Build a lightweight World of Warcraft Forever addon for the beta client, using the Retail API where supported. It detects food whose tooltip grants 5% additional experience from kills and reminds the player when the corresponding "Well fed" buff is not active.

## Proposed Addon Structure

- `ForeverExpFood.toc`: addon metadata, interface version `16001`, saved-variable declaration, and Lua file load order.
- `Core.lua`: event registration, scan scheduling, inventory and aura checks, and reminder coordination.
- `Options.lua`: in-game settings panel, first-run preference setup, and saved settings.
- `ScreenAlert.lua`: movable, timed screen-alert frame with saved appearance and position.
- `Locale.lua`: user-facing strings and tooltip-matching terms for all standard WoW locales.

Keep the initial implementation small; split files further only if the codebase or beta API requires it.

## Implementation Steps

1. **Verify beta API compatibility**
   - Use interface number `16001` and confirm the addon metadata conventions in the beta client.
   - Confirm bag APIs, bag-change events, aura APIs, event/frame scheduling, and options-panel APIs in the client.
   - Record any differences from Retail API assumptions before relying on them.

2. **Create the addon skeleton**
   - Add the `.toc` and Lua entry points with a single event handler/bootstrap path.
   - Declare a saved-variable table for preferences and setup completion.
   - Initialize missing settings with validated defaults while preserving existing user settings after updates.

3. **Implement qualifying-food detection**
   - Inspect items in carried bags only; do not count bank storage.
   - Identify qualifying food from localized tooltip text containing an exact 5% kill-XP effect, rejecting other percentages such as 15% or 25%.
   - Select locale-specific matching terms for all standard WoW locales, with English as the fallback for unknown locales.
   - Include Mithril Head Trout as a verification example using its supplied tooltip text.
   - Cache the bag-scan result and invalidate it on bag or item-data changes; handle empty slots, unavailable item data, and asynchronous item information.

4. **Implement active-buff detection**
   - Inspect active auras for the "Well fed" effect whose tooltip says kill XP is increased by 5%.
   - Use the beta-supported aura data/API and verify whether the descriptive text is available without constructing a tooltip.
   - Ensure unrelated "Well fed" buffs do not suppress the reminder unless their effect matches the XP bonus.

5. **Coordinate scans and reminders**
   - Check once when the player enters the world or reloads the UI.
   - Recheck when carried bags change, and register player-only aura updates where supported so aura events can reuse the cached bag result.
   - Retain a one-minute periodic scan as a fallback for missed or unavailable events.
   - Suppress reminders and hide visible screen alerts during combat; rescan immediately when combat ends.
   - Notify only when qualifying food is in bags and the matching buff is absent.
   - Track reminder state so repeated scans do not accidentally spam; apply the configured repeat behavior and interval.

6. **Add preferences and setup**
   - Present a first-run setup flow that asks how the player wants to be reminded.
   - Provide an in-game options panel for later changes.
   - Include independent chat and screen-alert toggles and a control for whether and how often reminders repeat.
   - Offer a disabled-by-default option to remind players to get XP food when a reliable scan finds none and the XP buff is inactive.
   - Allow players to customize screen-alert text, duration, color, and size, preview it, move it, and reset its position.
   - Add a configurable snooze duration (1, 5, 10, 15, 30, or 60 minutes; default 1 minute) and a dismiss action scoped to the current reminder condition.
   - Persist settings between sessions and validate values loaded from saved variables.

7. **Verify behavior in the beta client**
   - Confirm the addon loads without Lua errors and settings survive reloads.
   - Test qualifying food present/absent, matching buff active/inactive, and unrelated food or buffs.
   - Verify exact 5% matching and reject 15%/25% tooltip values.
   - Exercise localized matching with simulated locale strings; do not require switching the game client language.
   - Review translated tooltip phrases against reliable localized game-data references where available, and document any unverified wording.
   - Test login/reload, bag changes, and the one-minute fallback.
   - Test each alert independently, both alerts together, disabled alerts, and configured repeat behavior.
   - Confirm items in the bank do not trigger reminders and tooltip/API failures do not break scanning.

## Acceptance Criteria

- The addon loads in the target beta client without errors.
- Qualifying food in carried bags is detected from its tooltip effect; bank items are ignored.
- A matching 5% kill-XP "Well fed" buff suppresses reminders, while unrelated buffs do not.
- Checks run on login/reload, after bag changes, and at least once per minute.
- No reminders are sent during combat; pending conditions are checked immediately after combat ends.
- Players can choose preferences during first-run setup and change them in the options panel.
- Chat and screen alerts can be toggled independently, and repeat behavior is configurable and persists across sessions.
- Repeated scans do not cause reminders more frequently than the configured behavior allows.
- Screen-alert settings and position persist, and the alert can be previewed and repositioned.
- The optional no-food reminder is off by default, uses the selected alert channels and repeat interval, and is suppressed while the XP buff is active or scan data is unresolved.
- Snooze pauses both alert channels until the selected duration elapses, then resumes on the next scan; dismiss suppresses only the current condition until it changes or resolves.
- Snooze is available in 1, 5, 10, 15, 30, and 60 minute choices, defaults to 1 minute, and the alert buttons are hidden in preview mode.
- Addon controls, alerts, and locale-aware tooltip matching support all standard WoW locales, with English fallback.
- Locale-simulated tests cover matching behavior without requiring non-English client installations.

## Decisions to Confirm During Implementation

- Verify options-panel registration and remaining API assumptions in the beta client.
- Verify English tooltip behavior in the Forever client.
- Review non-English UI and tooltip terms against localized reference data; clearly track wording that cannot be independently verified.
