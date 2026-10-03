# Testing Gluvio on your iPhone and Apple Watch (TestFlight)

TestFlight is Apple's beta channel. You install Gluvio through the TestFlight
app on your iPhone, and the Apple Watch app installs on your paired watch.
Builds for your own team ("internal testing") don't need App Review.

The GitHub workflow **TestFlight** builds, signs and uploads the app. The steps
below are the one-time setup that only the account owner can do.

## 1. Join the Apple Developer Program

<https://developer.apple.com/programs/enroll/>, US$99 a year. Approval can take
up to 48 hours. TestFlight and HealthKit both need a paid membership.

Then find your **Team ID**: <https://developer.apple.com/account> →
Membership details. It looks like `A1B2C3D4E5`.

## 2. Choose a bundle ID and register it

The bundle ID is the app's permanent, unique identifier. Use your own reverse
domain or name, for example `com.venkatsatish.gluvio`.

At <https://developer.apple.com/account/resources/identifiers/list>:

1. **Identifiers → +** → *App IDs* → *App* → Continue.
2. Description `Gluvio`, Bundle ID **Explicit** `com.venkatsatish.gluvio`.
3. Under Capabilities tick **HealthKit** and **App Groups** → Continue → Register.

The workflow's automatic signing creates the Watch, widget and App Group
identifiers on its first run. If that run fails with a provisioning error,
create them the same way:

| Identifier | Capabilities |
|---|---|
| `com.venkatsatish.gluvio.watchkitapp` | HealthKit, App Groups |
| `com.venkatsatish.gluvio.widgets` | App Groups |
| `com.venkatsatish.gluvio.watchkitapp.widgets` | App Groups |
| App Group `group.com.venkatsatish.gluvio` | (assign it to all four App IDs) |

## 3. Create the app in App Store Connect

<https://appstoreconnect.apple.com> → **Apps → + → New App**:

- Platform: **iOS**
- Name: **Gluvio**. App Store names are unique; if it's taken, use e.g.
  *Gluvio Glucose*. The name under the icon stays "Gluvio".
- Primary language: English (U.S.)
- Bundle ID: the one from step 2
- SKU: `gluvio`
- User access: Full access

## 4. Create an App Store Connect API key

App Store Connect → **Users and Access → Integrations → App Store Connect API →
Team Keys → +**

- Name: `GitHub TestFlight`
- Access: **Admin**. Signing in the cloud needs Admin to create the
  distribution certificate and profiles.

Download the `.p8` file. Apple lets you download it **only once**. Note the
**Key ID** next to the key and the **Issuer ID** at the top of the page.

## 5. Add the values to GitHub

In the Gluvio repository: **Settings → Secrets and variables → Actions**.
Type them in GitHub yourself; don't paste the key into chats or files.

**Variables** tab:

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | your Team ID, e.g. `A1B2C3D4E5` |
| `APP_BUNDLE_ID` | your bundle ID, e.g. `com.venkatsatish.gluvio` |

**Secrets** tab:

| Name | Value |
|---|---|
| `ASC_KEY_ID` | the Key ID |
| `ASC_ISSUER_ID` | the Issuer ID |
| `ASC_PRIVATE_KEY` | the whole `.p8` file opened in a text editor, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |

## 6. Upload a build

GitHub → **Actions → TestFlight → Run workflow**. It takes about 15 minutes.
Each run gets the next build number automatically.

Apple then processes the build for 5–30 minutes. It appears in App Store
Connect → your app → **TestFlight**. If it asks about export compliance, the
answer is already in the app ("no non-exempt encryption").

## 7. Install it on your iPhone and Apple Watch

1. App Store Connect → your app → **TestFlight → Internal Testing → +**: create a
   group (e.g. "Me"), add yourself, and add the build.
2. On your iPhone, install **TestFlight** from the App Store and open the
   invitation email, or open TestFlight directly. Install **Gluvio**.
3. On Apple Watch: open the **Watch** app on your iPhone → **My Watch** → scroll
   to **Gluvio** → **Install**. With *Automatic App Install* turned on, it
   installs by itself.
4. Open Gluvio on the iPhone, go through onboarding and allow Apple Health
   access. Open it once on the watch and allow access there too.

To try it without your own data, tap **Explore with sample data** on the
welcome screen.

## Good to know

- TestFlight builds expire after 90 days. Run the workflow again for a new one.
- Real readings come from Apple Health: your CGM's app (if it writes to Health),
  a Bluetooth meter, or readings you enter in Gluvio.
- Inviting people outside your team ("external testing") needs a short Beta App
  Review and a privacy policy URL.
