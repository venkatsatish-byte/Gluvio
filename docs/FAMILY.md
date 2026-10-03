# Type 1, Kids and Family features

## Safety rules (enforced in code and tests)

| Rule | How Gluvio enforces it |
|---|---|
| No insulin dose calculations, bolus suggestions or treatment advice | Insulin is **log only** (`InsulinDose`, `LogInsulinView`). There is no carb ratio, correction factor or calculator anywhere. `SafetyRuleTests` checks insulin and alert wording for calculation language. |
| Low/high screens show only the parent's care-plan text | `LowHelpView` and School Mode display `ChildProfile.carePlanLow` / `carePlanHigh` exactly as typed, split into lines. If the plan is empty they say "Get a grown-up right now". Alerts state the reading and point to the care plan, with no advice (`AlertPolicy`, tested). |
| Kids' profiles are parent-controlled, COPPA-friendly | Profiles are created and edited only outside Kid Mode. Leaving Kid Mode needs the parent PIN (salted SHA-256 in the Keychain, this device only). Gluvio has no accounts, servers, ads or analytics. A child profile stores a first name, age, avatar and care settings; photos are optional, downsized and kept in the app's private storage. |
| Disclaimer | "Gluvio is not a medical device. Follow your care team's plan." appears in onboarding, Kid Mode, the "I'm low" screen, the Parent Dashboard and School Mode (`SafetyCopy.shortDisclaimer`, tested). |
| Never shaming | Kid copy is checked against a list of shaming words (`KidCopy.bannedWords`). Wrong guesses in Carb Detective say "Good guess!". Streak rewards use the best streak ever, so nothing unlocked is taken away. |

## What's included

1. **Profiles**
   - **Onboarding:** asks who Gluvio is for: Type 1, Type 2, Prediabetes or Parent/caregiver.
   - **Caregivers:** get a **Family** tab and add children. Each child has a name, age, avatar or photo, units, target range, care-plan text for lows and highs, a recheck timer, emergency contacts, alert settings and a Kid Mode switch.
2. **Insulin (Type 1)**
   - Log rapid- or long-acting insulin with units and time.
   - It's saved to Apple Health as `insulinDelivery`, with bolus or basal as the delivery reason.
   - Insulin and carb markers appear on the glucose charts.
3. **Kid Mode**
   - **Look and wording:** big buttons, rounded type, and friendly status words ("In the zone!", "Climbing a hill", "Running low") above a smaller number.
   - **Glu:** an original mascot drawn with SwiftUI shapes. It's happy when in range, sleepy when low, wobbly when high, and curious when there's no recent reading.
   - **Daily quests:** check before meals, log a meal, drink water. Each quest earns a star, and there's a bonus star for doing all three.
   - **Rewards:** stars and streaks unlock colors, hats and backgrounds.
   - **Carb Detective:** 18 foods, including idli, dosa, chapati, rice, banana, poha, upma, dal, samosa, laddoo and mango.
4. **"I'm low"**
   - A giant button on the Kid Mode home screen.
   - Shows the parent's care-plan steps in large text, with a countdown to recheck.
   - Posts a notification on this iPhone and schedules a recheck reminder.
   - Offers **Text my grown-ups** (a pre-written message in Messages that the child sends) and a call button for each contact.
5. **Parent Dashboard**
   - Latest reading with trend, the last 24 hours with meal and insulin markers, and time in range for today and the last 7 days.
   - An overnight view (10 pm–7 am).
   - A weekly summary of patterns and quest progress.
   - Alert settings: low/high thresholds, quiet hours, and "only alert when out of range". Very lows always alert.
6. **School Mode:** a read-only sheet, shareable as a PDF. It shows the child's name, photo, age, targets, care-plan steps, emergency contacts and current reading, if there's one from the last hour.

## Limits to know

- **Alerts reach only this iPhone.** Gluvio has no server, and App Store Guideline 5.1.3 keeps health data out of the app's own iCloud. So alerts can't be pushed to a second parent's phone. Options for later:
  - the CGM maker's follow app (e.g. Dexcom Follow, LibreLinkUp), which already does this;
  - a CloudKit *shared* database between family members, which needs careful privacy review;
  - a small push backend.
- **Readings for a child come from one of two places:**
  - Apple Health on this iPhone, for the one child marked "Readings come from Apple Health on this iPhone";
  - readings logged in Gluvio (in Kid Mode or by a parent).
- **Forgetting the parent PIN.** There's no recovery by design, so a child can't get around it. A parent who forgets it can delete and reinstall Gluvio, which removes local data.

## Testing in the simulator

These need a **Debug** build, which is what Xcode's ▶ Run and `scripts/run-on-mac.sh` make. The sample family is two children: Aarav (8, CGM) and Meera (12, fingersticks). It includes lows, highs, logged insulin and two weeks of quest history. The parent PIN is **1234**.

**With the script:**

```bash
./scripts/run-on-mac.sh --family     # Family tab and Parent Dashboard
./scripts/run-on-mac.sh --kid        # straight into Kid Mode for Aarav
```

**In Xcode:** Settings → Developer → **Load sample family**. You can also add launch arguments (Product → Scheme → Edit Scheme → Run → Arguments):

| Arguments | Opens |
|---|---|
| `-demoMode YES -demoFamily YES` | Family tab |
| `… -kidMode Aarav` | Kid Mode for Aarav |
| `… -demoKidReading low` (or `veryLow`, `high`, `inRange`) | Forces Aarav's latest reading, to see each Glu mood and alert |
| `… -kidScreen low` (or `quests`, `carbs`, `customize`, `check`, `meal`) | Opens that Kid Mode screen |
| `… -parentScreen dashboard` (or `school`, `editor`) | Opens Aarav's dashboard, School Mode or profile editor |

### What to try

| Area | Try this |
|---|---|
| Kid Mode | "I'm low" shows the care plan and countdown. "Water" adds a glass. "Check my number", "I ate", "Quests", "Carb Detective" and "My Glu" each open their screen. Leave by tapping 🔒 and entering 1234. |
| Parent Dashboard | Family → Aarav: the chart shows meal and insulin markers. Look at the overnight view and the weekly summary. Use "Start Kid Mode". |
| Alerts | In Aarav's profile (Edit → Alerts), set thresholds or quiet hours. Then log a low reading with Log → Glucose reading; a notification appears. |
| School Mode | Aarav → School Mode → PDF → share. |
| Type 1 adult | Settings → "Gluvio is for" → Type 1. Today gets an Insulin button, and insulin markers appear on the chart. |
