Lightweight World of Warcraft Forever addon using the Retail API, targeting the new beta client.

The addon helps players maximize XP from kills by tracking food that grants a 5% experience bonus. It checks the player's bags and reminds them to eat qualifying food when its buff is not active.

## Features

- Scans the player's bags in the background once per minute.
- Detects qualifying food by its tooltip text, including the effect "experience gained from kills is increased by 5%." Mithril Head Trout is one example.
- Detects the active effect from the "Well fed" buff whose tooltip says "Experience gained from kills increased by 5%."
- Lets players choose reminder preferences during setup and change them later in an in-game options panel.
- Supports chat and screen alerts, each independently toggleable.
- Lets players customize whether and how often reminders repeat.
- Offers an opt-in reminder when no qualifying XP food is in the player's bags and the XP buff is inactive; this option is off by default.
- Lets players customize the screen alert text, display duration, text color, and size.
- Lets players preview and move the screen alert, with its position saved between sessions and a reset option.
- Provides a snooze button on screen alerts; snooze duration is configurable (1, 5, 10, 15, 30, or 60 minutes) and defaults to 1 minute.
- Snoozing pauses both chat and screen reminders; alerts resume on the first scan after the selected duration if the condition remains.
- Provides a dismiss button that suppresses the current reminder condition until it changes or resolves, without muting later conditions.

## Usage

- Install the addon in the World of Warcraft Forever addons folder and enable it in-game.
- Choose reminder preferences during setup, or adjust them later in the options panel.
- Optionally enable reminders to restock XP food when none is available in bags.
- Use the options panel to customize, preview, and reposition the screen alert.
- Snooze a reminder temporarily or dismiss the current reminder condition from the screen alert.
- The addon automatically checks bags once per minute and reminds the player when qualifying food is available and the matching XP buff is inactive.
