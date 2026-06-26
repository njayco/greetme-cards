# GreetMe Cards

GreetMe Cards is an iOS iMessage app extension that lets you browse, customize, and send digital greeting cards directly inside Apple Messages.

Production web app: [greetme.me](https://greetme.me)

## Features

- **Browse catalog** — Categories, popular cards, search, and pricing from the live GreetMe API
- **Customize cards** — To / From, personal note, voice notes, YouTube clips, and Cash App gifts
- **Preview before send** — Review the full card in the extension before attaching it to a message
- **Rich message bubbles** — Sent cards appear as tappable previews with cover art, title, and sender
- **In-extension card viewer** — Recipients with GreetMe Cards installed view cards inside Messages
- **Web fallback** — Card links open on [greetme.me](https://greetme.me) for users without the extension

## Project structure

| Target | Description |
|--------|-------------|
| `GreetMe` | Container iOS app (installs the extension; handles `greetme://` and web card deep links) |
| `MessagesExtension` | iMessage extension shown as **GreetMe Cards** in the Messages app drawer |

### Key extension files

- `MessagesViewController.swift` — Extension entry point, message insertion, card deep links
- `CardBuilderView.swift` — Browse home and navigation
- `CustomizeCardView.swift` — Card customization and Preview / Send flow
- `CardViewerView.swift` — View received cards inside Messages
- `GreetMeAPIClient.swift` — Networking against GreetMe iMessage endpoints
- `GreetMeConfig.swift` — API base URL (`https://greetme.me`)

## Requirements

- Xcode 16+ (iOS 26 SDK recommended)
- iOS 16.0+
- Apple Developer account for device testing
- Network access to `https://greetme.me`

## Getting started

1. Clone the repository:

   ```bash
   git clone https://github.com/njayco/greetme-cards.git
   cd greetme-cards
   ```

2. Open `GreetMe.xcodeproj` in Xcode.

3. Select the **GreetMe** scheme and an iPhone simulator or device.

4. Build and run (⌘R).

5. Open **Messages** on the simulator or device.

6. In a conversation, tap the **App Store** icon next to the text field.

7. Choose **GreetMe Cards** (enable it via **Edit** if it is not listed).

## Usage

### Send a card

1. Open **GreetMe Cards** in Messages.
2. Pick a card from the catalog.
3. Fill in To, From, and any add-ons.
4. Tap **Preview** to review, or **Send** to attach the card to the message field.
5. Tap the blue **Send** button in Messages to deliver the card.

### View a received card

- **With the extension:** Tap the card bubble → opens the in-app card viewer.
- **Without the extension:** Tap the bubble → opens the card on [greetme.me](https://greetme.me).

## API configuration

The extension talks to the GreetMe backend configured in `MessagesExtension/GreetMeConfig.swift`:

```swift
static let baseURL = "https://greetme.me"
```

Endpoints used:

- `GET /api/imessage/catalog`
- `POST /api/imessage/create-card`
- `GET /api/imessage/card/{id}`
- `POST /api/voice-note/upload`

## Bundle identifiers

- App: `org.najee.greetme`
- Extension: `org.najee.greetme.MessagesExtension`

Update the **Development Team** in Xcode signing settings for your own Apple Developer account.

## License

Proprietary — The Najee Corporation / GreetMe.
