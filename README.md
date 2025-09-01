# FatherBuffAlerts

**WoW 1.12 (Vanilla) / Lua 5.0**  
Per-character **multi-buff** expiry alerts with a **sound** and an optional **center-screen splash** (with live **countdown**). Configure everything in-game via **/fba settings** or the **minimap button**.

---

## Changelog

### 2.1.0

- **Settings UI:** In-game window with two tabs:
  - **Tracked** — view/edit/remove buffs you’re tracking; per-buff settings.
  - **Spellbook** — suggests names from your spellbook; click a name then **+ Add**.
- **Minimap button:** Draggable around the minimap; left-click to open settings.
- **First-run onboarding:** Settings open automatically so you can choose buffs.
- **Per-character master enable** exposed in UI.
- **Performance:** Disabled or removed buffs are skipped from processing.

### 2.0.0

- **New addon:** FatherBuffAlerts (`/fba`) with **per-character** saved variables.
- Track **multiple buffs**, each with its **own**:
  - Alert delay (seconds before expiry)
  - Sound (default / none / custom file path)
  - Combat-only toggle
  - Optional **long-buff reminder** (see below)
- **Center-screen splash** with optional **live countdown** and movable position.
- **Spellbook suggestion** list to help add buff names quickly.

---

## Features

- ✅ **Per-character** configuration (enable only on the characters you want).
- ✅ Track **any number of buffs** (spells, consumables, item buffs like _Well Fed_, _Scroll of Agility_, etc.).
- ✅ **Per-buff settings**:
  - **Delay**: alert when _X_ seconds remain (e.g., 4.0s).
  - **Sound**: `default` (loud bell), `none` (silent), or a **custom** file path.
  - **Combat-only**: play the alert only while you’re in combat.
  - **Long-buff reminder**: if a particular buff instance lasts **≥ 9 minutes**, the addon warns you **5 minutes** before it expires (per-buff toggle).
- ✅ **On-screen splash** (Critline-style) with optional **live countdown** (“…in 3.8s, 3.7s, …”).
- ✅ **Minimap button** + **/fba settings** to open the configuration quickly.

---

## Installation

1. Copy the folder to:
   Interface\AddOns\FatherBuffAlerts\
2. Restart the game and enable **FatherBuffAlerts** in the AddOns list.

> **Client:** Vanilla 1.12, Lua 5.0.  
> **SavedVariables (per character):** `FatherBuffAlertsDB`

---

## Quick Start

1. Type **`/fba settings`** (opens automatically the first time).
2. In the **Spellbook** tab, click a spell/buff name you want to track, then press **+ Add**.  
   Or type a custom buff name (e.g., _Well Fed_, _Scroll of Agility_) in the **Add** box and press **+ Add**.
3. Switch to the **Tracked** tab, click a buff, and adjust:

- **Enable**, **Delay**, **Sound**, **Combat-only**, **Long-buff reminder**.

4. (Optional) In the top of the window, toggle global **Splash** and **Live countdown**.
5. Use **/fba unlock** to drag the splash position; **/fba lock** to save.

---

## The Settings Window

- **Open:** Minimap button (drag it around the minimap) **or** `/fba settings`.
- **Top toggles (global):**
- **Enabled (per-character)** — master on/off.
- **Show on-screen splash** — enable/disable the visual alert.
- **Show live countdown text** — switch between a live timer or a static message.
- **Show minimap button** — show/hide the minimap shortcut.
- **Tabs:**
- **Tracked**
- Shows all **tracked buffs**. Click one to edit details on the right.
- **Remove** deletes it from tracking (zero cost thereafter).
- **Test** plays the sound and shows a preview splash.
- **Spellbook**
- Lists spell names from your **Spellbook** (filterable).
- Click a name, then press **+ Add** to track it.
- **Add custom:**
- At the bottom: type any buff name and click **+ Add** (e.g., _Well Fed_, _Elixir of the Mongoose_).

---

## Per-Buff Settings

- **Enable this buff** — turn tracking on/off for this specific buff.
- **Delay (seconds)** — when to alert before the buff ends (e.g., 4.0).
- **Sound**
- `default` — loud, reliable bell (`Sound\Doodad\BellTollHorde.wav`).
- `none` — silent splash only.
- `custom` — enter a game sound path (examples below).
- **Only alert in combat** — suppress alerts out of combat.
- **5m reminder for ≥9m buffs** — if the current instance lasts **≥ 9 minutes**, you’ll also get a reminder **5 minutes** prior to expiry (for **that** instance only).

---

## Sounds

- **Default bell:** `Sound\Doodad\BellTollHorde.wav`
- **Examples:**
- `Sound\Spells\Strike.wav`
- `Interface\AddOns\FatherBuffAlerts\alert.wav` (your own file)
- **Tip:** To test a path:
  /script PlaySoundFile([[Sound\Spells\Strike.wav]])

---

## Slash Commands

- **UI & status**
- `/fba settings` — open settings window
- `/fba enable` — master on/off (per character)
- `/fba status` — show global and per-buff info
- `/fba unlock` / `/fba lock` — move/lock splash position
- **Managing buffs**
- `/fba list` — list all tracked buffs
- `/fba add <Buff Name>` — add a buff by name  
  (or from the UI: Spellbook tab → click name → **+ Add**)
- `/fba add #<n>` — add from the last `/fba suggest` list by index
- `/fba remove <Buff Name>` — stop tracking a buff
- `/fba suggest [filter]` — list spellbook names (optionally filtered)
- **Per-buff settings via chat**
- `/fba set <Buff> delay <seconds>`
- `/fba set <Buff> sound default|none|<path>`
- `/fba set <Buff> combat` (toggle)
- `/fba set <Buff> enable` (toggle)
- `/fba set <Buff> long` (toggle 5m reminder)
- **Splash**
- `/fba alert` — toggle the on-screen splash (global)
- `/fba countdown` — toggle live countdown text (global)
- `/fba test <Buff>` — test that buff’s sound + splash

**Examples**
/fba settings
/fba add Well Fed
/fba set Well Fed long
/fba set Well Fed sound Sound\Spells\Strike.wav
/fba set Well Fed delay 8
/fba alert
/fba countdown

---

## How It Works

- Every ~0.1s the addon scans your **active buffs**.
- For each **tracked & enabled** buff:
  - If time left `≤ (threshold + small cushion)`, it plays the configured **sound** and shows the **splash**.
  - If **long-buff reminder** is on _and_ the buff instance lasts **≥ 9 minutes**, it uses a **5-minute pre-warning** for that instance (no DB change).
- If multiple buffs are under threshold, the **closest to expiring** drives the **live countdown** text.

---

## Performance Notes

- **Disabled** buffs remain in your list but aren’t processed beyond bookkeeping.
- **Removed** buffs are not processed at all.
- Keep your tracked list lean for the lowest overhead (Vanilla is CPU-tight).

---

## Troubleshooting

- **No sound**
  - Check in-game **Enable Sound** and **Sound Effects**.
  - Try `/fba test <Buff>`.
  - For custom paths, test:
    ```
    /script PlaySoundFile([[<your\path\here.wav]]])
    ```
- **Splash not visible**
  - Ensure **Splash** is on (UI toggle or `/fba alert`).
  - If **Countdown** is off, splash fades; use `/fba test <Buff>` to preview.
  - Use `/fba unlock` to relocate; `/fba lock` to save.
- **Wrong buff name**
  - Use the exact **buff name** displayed on your character (tooltip).
  - Add from the **Spellbook** tab to avoid typos when it matches the buff.

---

## File Layout

FatherBuffAlerts/
├─ FatherBuffAlerts.toc
├─ FBA_Core.lua # scanning, logic, slash commands, per-char DB
├─ FBA_Alerts.lua # splash UI (center text, countdown, positioning)
├─ FBA_Spells.lua # spellbook suggestions
└─ FBA_UI.lua # settings window + minimap button

**TOC highlights**

- `## Interface: 11200`
- `## SavedVariablesPerCharacter: FatherBuffAlertsDB`

---

## FAQ

**Q: Can it alert for food/scroll/elixir buffs?**  
Yes. Add the **buff name** (e.g., _Well Fed_, _Elixir of the Mongoose_). As long as it shows as a player buff, it can be tracked.

**Q: Can I silence certain buffs but keep the splash?**  
Yes — set **Sound** to `none` for that buff.

**Q: Can I use my own WAV/MP3?**  
Yes — place the file somewhere and set the **custom path** (e.g., `Interface\AddOns\FatherBuffAlerts\alert.wav`).

---

Happy buff tracking! Open **/fba settings** or click the **minimap button** to get started.
