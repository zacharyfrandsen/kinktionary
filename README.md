# Kinktionary

A consent-first glossary and community app for adults, built with Flutter for Android and iOS. The source is published so anyone can read it, audit how data is handled, suggest changes or build on it. It is MIT licensed.

Kinktionary is educational. It is not medical, legal or mental-health advice, and it is for adults only (an 18+ age confirmation appears on first launch).

## Contents
- [Features](#features)
- [How the app is organised](#how-the-app-is-organised)
- [Data and privacy](#data-and-privacy)
- [Security model](#security-model)
- [Where to look when auditing](#where-to-look-when-auditing)
- [Run it yourself](#run-it-yourself)
- [Editing the content](#editing-the-content)
- [Tests and tooling](#tests-and-tooling)
- [Known limitations](#known-limitations)
- [Contributing](#contributing)
- [Reporting a security problem](#reporting-a-security-problem)

## Features

### Learn
- **Glossary** with 180+ terms across roles, dynamics, activities, consent and safety, gear, community, genders and orientations. Search by name, definition or details, filter by category, and filter to saved terms.
- **Term pages** with a short definition, a longer explanation, a safety note where relevant, and links to related terms.
- **Bookmarks and private notes** on any term. Both stay on the device unless you sign in (see Data and privacy), and both can be browsed and searched from your profile.
- **Guided paths** such as "Start here", "Talking it through", "Safety first" and "Meeting people safely". Each path walks through one term at a time with Back and Next, remembers where you stopped, lets you jump to any step, and ends with a reflection prompt.
- **Safety and consent basics**, one tap from the search bar on the Feed and Glossary screens.

### Community (signed-in members only)
- **Feed** of posts with a topic (Experience, Question, Reflection, Advice) and up to five tags. Tags can be suggested, custom, or taken from glossary terms, and tapping a tag searches for it.
- **Replies and likes**, with editing and deleting of your own posts.
- Visitors who are not signed in see a sign-in prompt instead of the feed.

### People
- **Accounts** with name, username, email, password and an optional private phone number. Usernames are unique, checked live while typing, and cannot be changed afterwards.
- **Profiles** shown as a "business card": photo, name, username, pronouns, status line, location, interests, and your own accent and banner gradient colours. Stats for friends, followers, following, posts, likes and replies are all tappable.
- **Friends** with private labels and nicknames only you can see, **following**, and **blocking** (which hides someone's posts and replies and stops their requests and replies to you).
- A friends list that is visible on public profiles. It contains only who the friends are, never your private labels.

### Settings
- Edit profile, including private email, password and phone changes (changes to email or password ask for your current password).
- Accent and heading colours, background colour or gradient, background icon colour and strength, all synced to your account so a new device looks the same.
- Requests for data deletion or data recovery, and an in-app Open source page with the data statement.
- A donations page (the link is set at build time).

## How the app is organised

```
lib/
  main.dart                  App start, Firebase and App Check setup
  data_store.dart            Local state and account-settings sync (ChangeNotifier)
  models.dart                Terms, paths, profiles, posts, replies
  social_models.dart         Friends, requests, blocked users
  theme.dart, appearance.dart  Material 3 dark theme and user colour overrides
  screens/                   One file per screen
  services/                  Firebase access (profile, social, sign-in state)
  widgets/                   Shared UI (search row, profile header, colour picker, background)
assets/data/                 terms.json, paths.json, consent.json (generated or hand-edited)
data_source/                 YAML and JSON sources the terms are built from
firebase/                    Firestore and Storage security rules, indexes
tools/                       Content build script and icon generator
test/                        Widget and unit tests
```

- **State:** a single `DataStore` holds terms, paths, posts, bookmarks, notes, preferences and path progress. Screens listen to it with `ListenableBuilder`.
- **Local storage:** `shared_preferences` for bookmarks, notes, progress, appearance and cached posts.
- **Cloud:** Firebase Authentication, Cloud Firestore and Cloud Storage, protected by Firebase App Check (Play Integrity on Android, App Attest on iOS).
- **Theme:** Material 3, dark only. Users can override the accent and heading colours, and the background is a solid colour or gradient with a recolourable icon pattern over it.

## Data and privacy

**Only on your device**
- Age confirmation, wallpaper settings, cached posts.
- Bookmarks, notes and path progress. When you are signed in, these are also copied to a private document in your account so they follow you to a new device. Nobody else can read it.

**In the cloud, for signed-in users**
- Email and password (handled by Firebase Authentication; the app never sees your password after sign-in).
- Public profile: name, username, pronouns, bio, photo, status, location, interests and profile colours. Other signed-in members can see these.
- Private contact document: optional phone number. It is never shown on your profile.
- Posts, tags, replies and likes you create.
- Friends, friend requests, followers, following and blocked lists. Friend labels, nicknames, requests and the blocked list are visible only to you.
- Data deletion and recovery requests you submit.

**Not collected:** no ads, no analytics, no tracking SDKs, no data sold or shared for advertising. Firebase App Check uses device attestation to block abuse of the backend.

Deletion and recovery requests are stored as documents and handled by a person. There is no automated deletion pipeline in this repository.

## Security model

Everything the app can read or write in the cloud is governed by `firebase/firestore.rules` and `firebase/storage.rules`. In summary:

- Reading profiles, posts, replies, followers and the public friends list requires being signed in.
- You can only create, edit or delete your own profile, posts and replies. Likes and like counts are validated so a client cannot set arbitrary counts.
- Private data (phone number, account settings, friend labels, friend requests, blocked users) is readable only by its owner.
- Usernames are reserved through a separate `handles` collection so they stay unique. A single username can be looked up while signed out, only so the sign-up form can show whether a name is free. Listing usernames requires sign-in.
- Data requests can be created but never read or changed by clients.
- Field names, types and sizes are checked on every write.

Treat the rules as the real security boundary. The Flutter client enforces the same checks for usability, but it is not trusted.

## Where to look when auditing

| Area | Files |
| --- | --- |
| Access rules for all cloud data | `firebase/firestore.rules`, `firebase/storage.rules` |
| Sign-up, sign-in, profile, phone, data requests | `lib/services/firebase_profile_service.dart` |
| Email and password changes | `lib/widgets/account_dialogs.dart` |
| Friends, following, blocking | `lib/services/firebase_social_service.dart` |
| Local storage and account settings sync | `lib/data_store.dart` |
| Statement shown to users | `lib/screens/open_source_screen.dart` |
| Content (terms, paths, consent text) | `data_source/`, `assets/data/` |

## Run it yourself

You need Flutter and your own Firebase project. No credentials are included in this repository.

1. `flutter pub get`
2. Create a Firebase project with Authentication (email/password), Firestore, Storage and App Check.
3. Run `flutterfire configure`. This replaces the placeholder `lib/firebase_options.dart` and adds `android/app/google-services.json`.
4. Deploy the rules: `firebase deploy --only firestore:rules,storage --config firebase/firebase.json`
5. `flutter run --dart-define=APP_CHECK_DEBUG=true`, then register the App Check debug token that is printed in the log in the Firebase console. Without it, sign-in is rejected.

Build options:
- `--dart-define=DONATION_URL=https://...` sets the donation page link.
- `--dart-define=APP_CHECK_DEBUG_TOKEN=<your token>` keeps one debug token across reinstalls.

**Android release:** add an upload key in `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) and run `flutter build appbundle --release`. Add the Play signing certificate SHA-256 to your Firebase app so Play Integrity works.

**iOS:** needs a Mac with Xcode and CocoaPods. Run `pod install` in `ios/`. Release builds use App Attest, which needs that capability on your Apple developer account.

## Editing the content

The terms are built from source files, not edited in the generated output:

- `data_source/yaml/*.yml` holds the base terms (name and definition) for roles, genders, orientations and categories.
- `data_source/extras.json` holds additional terms and optional `details`, `related`, `safetyNote` and `draft` fields for any term id.
- `assets/data/terms.json` is generated by `python3 tools/build_terms.py`. Do not edit it by hand.
- `assets/data/paths.json` defines guided paths. Every id in `termIds` must be a real term, and the build script checks this.
- `assets/data/consent.json` holds the safety and consent topics.

Terms marked `"draft": true` show a "Draft definition" badge until the flag is removed. Definitions are written for education and are reviewed over time. Corrections are welcome.

## Tests and tooling

```sh
flutter analyze
flutter test
python3 tools/build_terms.py   # rebuild assets/data/terms.json (needs PyYAML)
python3 tools/make_icons.py    # rebuild launcher icons (needs Pillow)
```

The tests cover the glossary and saved search, the feed and composer (tags, topics), sign-in gating, path progress and navigation, appearance persistence and the safety shortcut.

## Known limitations
- Tags are limited to five per post by the rules, but the length of each tag is only enforced by the client.
- The phone number is stored but not verified, and is not used for sign-in.
- The 18+ gate is a self-confirmation, not identity verification.
- There is no automated content moderation. Members can block others, and moderation otherwise depends on the maintainers.
- Data deletion and recovery are manual processes.
- There are no push notifications.

## Contributing
Issues and pull requests are welcome, especially for corrections to definitions, safety wording, accessibility and security. Please keep changes consent-first and respectful, run `flutter analyze` and `flutter test` before submitting, and avoid adding analytics or tracking.

## Reporting a security problem
Please use GitHub's private vulnerability reporting for this repository rather than a public issue.

## License
MIT. See `LICENSE`.
