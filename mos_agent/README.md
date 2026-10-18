# MOS Agent

Flutter desktop help-desk workspace with icon-only navigation and streamed inference chat.

## Run locally

Validated toolchain: Flutter 3.47.7 stable and Dart 3.13.5.

```sh
flutter pub get
flutter run -d macos
```

The sidebar is 60 logical pixels wide and fills the window height. Profile,
Settings, Chats, and Media switch the active content and top section title.
Chats opens initially. Hover over an icon to see its label; use Tab and
Enter/Space to navigate with a keyboard.

Chats includes a selectable chat list that starts at 20% of the available width.
Drag its divider to resize it. On narrow windows, use the **Choose chat** button.
Click **Start inference** to connect to `http://127.0.0.1:8000`, then send a message.
The app starts the service, loads mode names and values from `/inference/modes`,
and creates a backend chat. Choose a server-provided name above **New chat**
to create another conversation. Its value is passed to `/chat/new/{mode}`.
The current catalogue is CLASSIFICATION → 0 and CHAT → 1; additional returned
modes also work without a client change. Existing conversations retain their
original mode. Initial chat creation prefers CHAT, then the first returned mode.
The service destination is shown before sending is enabled.

Override the URL or launch the isolated UI demo with:

```sh
flutter run -d macos --dart-define=INFERENCE_BASE_URL=http://127.0.0.1:8000
flutter run -d macos --dart-define=DEMO_MODE=true
```

The backend's numeric mode validation is now fixed. Normal chat creation and
stream delivery were checked against the live service. Its chunked response
currently arrives in a burst after generation; the client forwards partial text
as soon as bytes arrive. See [streaming diagnostics](docs/streaming_diagnostics.md).
See [backend API details and limitations](docs/backend_api.md).

The composer fills the conversation width. Its text area starts at 100 logical
pixels tall; drag the top grip to resize it (100–260 pixels). The divider and
composer grip also support Tab focus and arrow keys. Enter sends, Shift+Enter
adds a newline, and active IME composition does not send. The up arrow sends;
**Stop receiving response** stops reception while generation may continue on the
server. The configuration button shows the service destination and available
capabilities. Attachments and agent role/style changes are unavailable in backend
mode because the API has no endpoints for them. Demo mode retains those local
controls.

Chats and drafts survive switching conversations and navigation tabs for this
app session; they are not saved across restarts. Failed submissions preserve
the draft, and interrupted replies are labeled incomplete. No request is
retried automatically. Other sections use empty states, and Logout remains
disabled until authentication is implemented.

Current backend limitation: messages containing `/` return HTTP 404 even when
encoded. The app keeps the draft and explains the unsupported input. A backend
message-body endpoint is needed to support arbitrary text.

## Verify

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build macos --debug
```

Tests cover navigation, resizing, send/newline/IME behavior, scoped drafts and
attachments, configuration, submission failures, duplicate prevention, compact
layouts, enlarged text, incremental streams, protocol decoding, and connection
errors. The opt-in live test verifies your service using synthetic text:

```sh
flutter test test/inference_live_test.dart --dart-define=LIVE_INFERENCE=true
```

To measure live stream arrival timing:

```sh
flutter test test/stream_delivery_live_test.dart --dart-define=LIVE_INFERENCE=true
```

macOS is the build-validation target. Other shipping platforms remain undecided.
The native file dialog has not been interactively
verified because Computer Use permissions are unavailable. A macOS build requires
macOS and Xcode. Other platforms are not validated.
Coding and design rules live in [AGENTS.md](AGENTS.md).
