# ForeverExpFood

A lightweight World of Warcraft Forever addon that helps you maintain the kill-experience bonus from qualifying food. It reads the percentage from the tooltip; 5% is the current example, not a hard-coded limit.

## Features

- Scans carried bags for food whose tooltip grants additional experience from kills and extracts its percentage.
- Compares food bonuses with the active `Well Fed` XP buff; an equal or stronger buff suppresses reminders.
- Sends configurable chat and screen reminders when the active buff is weaker than the best food bonus.
- Optionally reminds you when no qualifying food is in your bags.
- Provides a movable screen alert with custom text, duration, size, and color.
- Supports snoozing reminders or dismissing the current reminder condition.
- Suppresses reminders during combat and checks again when combat ends.
- Includes localized interface text and tooltip matching for standard WoW locales.

## Install

1. Download `ForeverExpFood.zip` from the repository and extract its `ForeverExpFood` folder into `World of Warcraft\_retail_\Interface\AddOns\`.
2. Enable **ForeverExpFood** in the AddOns list and log in.
3. Configure reminders in the in-game options. Open them with `/foreverexpfood` or `/fef`.
4. Run `/fef debug` to print recognized XP food, active XP buffs, and relevant tooltip candidates to chat.

The addon targets interface `16001`. The game client must provide the Retail APIs used by the addon.

## License

MIT. See [LICENSE](LICENSE).
