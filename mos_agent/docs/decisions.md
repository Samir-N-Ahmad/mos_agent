# Implementation decisions

## Desktop workspace shell — 17 October 2026

- Toolchain: Flutter 3.47.7 stable with Dart 3.13.5, matching the existing SDK constraint and lockfile.
- UI: dark Material 3, a full-height sidebar fixed at 60 logical pixels, icon-only Profile, Settings, Chats, and Media navigation, with Logout at the bottom. Chats opens initially. The active section title appears above its content.
- State: local widget state for presentation-only navigation. Introduce a workflow controller when shared application workflows exist.
- Content: labeled preview empty states. Ticket system, authentication, model provider, local-model requirements, and retention policy remain undecided. No remote requests or ticket processing occur in this shell.
- Logout remains disabled with an explanatory tooltip until authentication is implemented.
- Target: desktop. macOS is the local build-validation target; shipping operating systems remain undecided. Other platform folders do not establish support.
- Layout validation: 1280 × 800 desktop and 480 × 320 compact window with doubled text. The sidebar keeps its requested width and scrolls vertically if necessary.
- UAE guidance: AGENTS.md section 12 governs later agent workflows. This shell exposes disconnected integrations honestly; agent approvals, retrieval, handoff, and fairness evaluations remain outside this UI-only change.
- Verification: formatting, `flutter analyze`, both widget tests, and `flutter build macos --debug` passed. The macOS launch reported a failure to foreground the window, and native UI inspection timed out; interactive visual verification remains unconfirmed.

## Chats workspace — 17 October 2026

- Desktop layout: the secondary sidebar starts at 20% of the remaining workspace width, fills its available height, and can be dragged between 16% and 45%. The remaining space contains the active conversation. Below 760 logical pixels of workspace width, the secondary sidebar becomes a chat picker; the primary sidebar remains 60 pixels wide.
- Composer: full conversation width with standard padding; its text input starts at 100 logical pixels tall and is resizable up to 260 pixels. Resize handles accept pointer dragging, keyboard arrows, and accessibility increase/decrease actions. Short windows provide vertical scrolling so controls stay reachable.
- Input: Enter sends; Shift+Enter inserts a newline at the selection. Active IME composition bypasses sending. Empty messages are blocked unless files are attached. Pending submissions block duplicates. The draft clears only after successful local submission; failure preserves text and attachments.
- State: an injected `ChatController` using Flutter `ChangeNotifier` owns typed immutable chat threads, messages, drafts, attachment references, and per-chat configuration. Widget state owns selection presentation, resizing, focus, and text editing. The workspace remains mounted across navigation tabs. No state-management package is needed.
- Demo boundary: deterministic `ChatResponder` provides visibly labeled sample replies. Role and style settings affect only that sample reply. No inference, knowledge retrieval, ticket actions, or network transmission occurs. Demo threads use synthetic text. A real model adapter remains undecided.
- Persistence: in-memory session state only. Do not use real customer data in this preview. Durable history, encrypted drafts, retention, and deletion remain future decisions before customer-data handling or production use.
- Attachments: replaceable `AttachmentPicker` uses Flutter's [file_selector 1.1.0](https://pub.dev/packages/file_selector), published by flutter.dev under BSD-3-Clause. It supports desktop native file selection; macOS debug and release entitlements grant read-only access to user-selected files. Only file names and local references are retained, not file bytes. No upload endpoint or attachment processing exists. Plugin registrants and lockfile were updated by Flutter.
- Source scope: the UAE guidance in AGENTS.md section 12 informs visible processing status and honest execution outcomes. Applying the full government-service workflow, approvals, handoff, and fairness evaluations requires future runtime-agent implementation.
- Validation: formatting and analysis passed; 13 tests passed, including narrow windows with doubled text, draft/file isolation, selection, resizing, IME behavior, configuration, failure recovery, and duplicate prevention. A readable Flutter-rendered desktop preview was inspected. The macOS debug build succeeded; the native picker has not been interactively exercised because Computer Use permissions are not granted. Other platforms remain unvalidated.


## Inference backend integration — 17 October 2026

- Default processing destination: `http://127.0.0.1:8000`, provided by the user; configurable with `INFERENCE_BASE_URL`. `DEMO_MODE=true` preserves the fixture UI. Backend mode contains no synthetic conversation history.
- Verified contract from the live FastAPI OpenAPI schema and synthetic requests: GET startup returns `{"code":200,"inference":"Started"}`; GET chat creation returns an integer under `inference` (including zero); GET send accepts the latest message and streams plain text. Full details, failure semantics, and commands are in [backend_api.md](backend_api.md).
- Architecture: a typed `InferenceBackend` isolates the controller from HTTP and protocol parsing. The existing controller owns backend connection state, remote chat IDs, in-flight requests, incremental answer updates, and failures. No widget performs networking. `http` 1.6.0 was already installed transitively and is now a direct dependency; no unrelated dependency upgrades were made.
- UI: show destination and startup control before enabling sends; create new chats through the service; distinguish real replies from demo replies. The backend has no upload, configuration, or generation-cancellation endpoint. Attachments/configuration changes are unavailable in backend mode; stopping reception does not claim to stop server work.
- Stream handling: decode UTF-8 incrementally and filter the specific prompt-echo/ChatML envelope observed from the service. The submitted user turn anchors extraction so markers in user content cannot impersonate the generated answer. Plain-text output is also supported. Preserve interrupted answers and drafts and never automatically retry or replay ambiguous operations.
- Platform: add outbound network access to macOS debug and release entitlements. macOS debug builds are validated; other native targets remain unvalidated.
- Known live-server issue: percent-encoded slashes in the path message return 404. Report that input limitation locally without altering the message; a future JSON-body endpoint is the recommended backend change. Message paths may appear in server access logs.
- Deployment gaps remain: authentication, provider/model identity, processing beyond the loopback service, data retention, encryption for durable history, and shipping OS scope are not specified. This change keeps history in session memory and tests only synthetic text.
- Validation: formatting and static analysis passed; 31 deterministic tests passed, with the live test skipped by default. A separate opt-in live controller test passed against the running service. Native interactive inspection remains unavailable because Computer Use permissions are not granted.


## Chat and classification modes — 17 October 2026

- The user's updated creation contract supersedes the original `/chat/new` route: `GET /chat/new/false` creates normal chat, and `GET /chat/new/true` creates classification chat. Startup creates a normal chat by default; later conversations use the mode chosen above New chat.
- Store an immutable `ChatMode` with each thread. Pass its boolean flag on all creation paths, including initial connection and lazy server-chat creation. Mode survives draft/message updates and selecting another conversation; changing the new-chat selector never changes an existing backend conversation.
- Show the mode in the conversation header and chat list. The selector also works in the compact chat picker. Classification uses the existing streaming pipeline; the backend owns classification behavior and the client does not truncate responses. Demo classification uses the fixed `request` fixture and remains labeled demo.
- Validation: formatting, analysis, and 34 deterministic tests pass, including both flag URLs, classification token streaming, mode persistence, desktop mode selection, and the compact picker at enlarged text. The live test now covers both modes, but is skipped by default. The service checked during this update still exposes only the legacy route in its OpenAPI schema, so the updated endpoint has not been live-validated.


## Discovered inference modes — 18 October 2026

- Supersede the boolean creation flag and fixed two-mode client enum. Fetch `GET /inference/modes` after startup, validate `code` and the nonempty list of `{name, value}` records, preserve names, and pass the selected value to `GET /chat/new/{mode}`.
- The live response is CLASSIFICATION = 0 and CHAT = 1. Store mode values as canonical URI strings; accept integer or string scalar values, reject malformed entries and duplicate values, and never derive a value from list order. Keep the catalogue immutable and bounded to 64 entries.
- Initial creation prefers the returned mode named CHAT, otherwise the first returned mode. The UI lists only discovered backend modes; failures preserve drafts and do not fall back to demo values. Every conversation retains its returned name/value snapshot. Fixture constants remain restricted to demo mode and unbound placeholder state.
- Validation: formatting and static analysis passed, and 39 deterministic tests passed. Tests include custom values and additional modes, default selection independent of order, invalid/empty/duplicate catalogue rejection, discovery failures, and server-provided selector labels. The live catalogue and schema were verified; the live end-to-end attempt failed during initial creation with HTTP 422. The server reports expected numeric enum values 0 or 1 while rejecting path string "1". A backend-side `mode: int` parameter followed by `Mode(mode)` is suggested in backend_api.md; no backend source was changed here.


## Stream delivery investigation — 18 October 2026

- Verified normal CHAT mode with two fresh synthetic requests using direct Python HTTP reads and the real Dart adapter/controller. Mode path validation is now fixed on the running service; no backend changes were made in this repository.
- The endpoint returns chunked plain text but delivers body data in a burst: the Python probe saw 77 body events within about 1 ms after 3.878 seconds; Dart saw 73 body events over 6.164 ms after 2.965 seconds. The controller emitted 72 incremental text updates and began about 1.004 ms after the first wire data.
- No production client change is justified: the response is arriving faster than a display frame after a generation-length wait. The exact upstream buffering cause requires backend source inspection. Recommendations and reproducible commands are in streaming_diagnostics.md.
- Added an opt-in timing test that logs only counts/timestamps, and a deterministic HTTP-to-controller regression checking two partial answers before EOF. Existing widget tests check incremental rendering. Formatting, analysis, and all 40 deterministic tests passed; the live timing probe also passed. This change is limited to tests and documentation, so a new native build was not necessary.
