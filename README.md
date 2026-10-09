# ForeverExpFood

A lightweight World of Warcraft Forever addon that helps you maintain the 5% kill-experience bonus from qualifying food.

## Features

- Scans carried bags for food whose tooltip grants 5% additional experience from kills.
- Checks whether the corresponding `Well Fed` XP buff is active.
- Sends configurable chat and screen reminders when food is available but the buff is inactive.
- Optionally reminds you when no qualifying food is in your bags.
- Provides a movable screen alert with custom text, duration, size, and color.
- Supports snoozing reminders or dismissing the current reminder condition.
- Suppresses reminders during combat and checks again when combat ends.
- Includes localized interface text and tooltip matching for standard WoW locales.

## Install

1. Download `ForeverExpFood.zip` from the repository and extract its `ForeverExpFood` folder into `World of Warcraft\_retail_\Interface\AddOns\`.
2. Enable **ForeverExpFood** in the AddOns list and log in.
3. Configure reminders in the in-game options. Open them with `/foreverexpfood` or `/fef`.

The addon targets interface `16001`. The game client must provide the Retail APIs used by the addon.

## License

MIT. See [LICENSE](LICENSE).
