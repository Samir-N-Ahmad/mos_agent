# Local inference API

The client targets `http://127.0.0.1:8000`. The mode catalogue and updated
OpenAPI schema were inspected on 18 October 2026. Modes are discovered from
the service; they are not a fixed client enum. The application starts
disconnected with an empty local conversation and sends no fixture history.

The live mode catalogue and normal chat creation now work. Streaming delivery
was measured on 18 October 2026: the service sends a chunked HTTP response, but
all body data arrived in a short burst after generation latency. The client
forwards partial answers immediately. See [streaming diagnostics](streaming_diagnostics.md)
for timings, regression coverage, and the repeatable probe.

## Connection and chat flow

1. Click **Start inference**. The destination is shown before sending is enabled.
2. The app calls `GET /inference/start`, then `GET /inference/modes`.
3. The returned catalogue is validated. The app selects the mode named `CHAT`
   (case-insensitive), or the first returned mode if CHAT is absent. It creates
   the initial chat using that mode's returned value.
4. After successful creation, choose a returned name above **New chat** to create
   another conversation. The selected value is sent as one URI path segment.
   Existing conversations retain their mode name/value snapshot.
5. Send text; the reply updates incrementally in the originating conversation,
   even when a different chat is selected.

| Operation | Request | Response format |
| --- | --- | --- |
| Start inference | `GET /inference/start` | `{"code":200,"inference":"Started"}` |
| Discover modes | `GET /inference/modes` | `{"code":200,"modes":[{"name":"CLASSIFICATION","value":0},{"name":"CHAT","value":1}]}` |
| Create chat | `GET /chat/new/{mode}` | `{"code":200,"inference":0}`; zero is a valid chat ID |
| Send latest message | `GET /send/{chat_id}/{messages}` | Chunked `text/plain; charset=utf-8` |

The current catalogue maps CLASSIFICATION to `/chat/new/0` and CHAT to
`/chat/new/1`. The adapter does not derive values from list order or send boolean
flags. It preserves server names and canonicalizes integer values to strings
only for URI serialization. String enum values are also supported. Empty,
malformed, duplicate-value, or unsuccessful catalogues fail explicitly without
creating chats with fixture values.

The backend owns each mode's output behavior. Classification output is displayed
as returned without local guessing or truncation. Additional returned modes are
available in the selector without a client code change. Offline demo mode alone
uses fixed fixtures, including the classification response `request`.

## Backend path validation

The earlier numeric enum validation problem has been fixed in the running
service. Its schema now declares `mode` as an integer, and `/chat/new/1`
succeeded during the streaming probes. The client continues to pass the value
returned by `/inference/modes`.

`messages` is the latest user text, encoded as one URI path segment. The client
does not resend local conversation history or serialize role/style settings
into the text. Inference history and model configuration are owned by the
backend; the API exposes no history retrieval or configuration endpoint.

The observed stream includes a ChatML prompt followed by the answer. The adapter
buffers that envelope, anchors extraction to the actual submitted user turn,
and shows only the assistant text. Partial UTF-8 characters and control tokens
can cross network chunk boundaries. Bare plain-text streams are also supported.
This is compatibility with the observed service format, not a general ChatML or
SSE implementation. Prefer returning only generated assistant text from the
backend to remove this compatibility step.

## Configuration

```sh
flutter run -d macos --dart-define=INFERENCE_BASE_URL=http://127.0.0.1:8000
```

The URL defaults to that loopback address. A different service can be selected
with the same compile-time setting. The app displays the actual destination;
a desktop app connecting to another address does not imply local inference.

For the original isolated UI demo:

```sh
flutter run -d macos --dart-define=DEMO_MODE=true
```

Demo mode uses fixture chats and deterministic replies without network calls.

## Failure and lifecycle behavior

- Startup, chat creation, HTTP status, malformed responses, empty streams,
  interrupted streams, and timeouts produce visible errors. No operation is
  automatically retried, and raw backend errors/request URLs are not shown.
- Sending is disabled until startup and initial chat creation succeed. Duplicate
  sends and duplicate startup/new-chat operations are blocked while pending.
- Failed sends retain the draft; partial answers remain labeled incomplete.
  An interrupted request may have reached the server. A manual resend is a new
  request and could repeat work; there is no idempotency contract in this API.
- **Stop receiving** closes the client response connection and ignores late
  chunks. It cannot claim to cancel server generation: no cancellation endpoint
  was provided. Disposing the controller closes its clients.
- Defaults: 60-second header/status wait, 60-second stream idle timeout,
  3-minute generation limit, 1 MiB streamed-response limit, and 64 KiB JSON
  status-response limit. Constructor parameters make these limits testable.
- History and drafts remain in app memory for this session. The client does not
  restore server IDs or replay requests after restart.

## Current API limitations

- A slash in a message produces HTTP 404 on the live FastAPI route even when
  encoded as `%2F`. The client preserves the draft and reports this limitation
  before issuing that request. A future `POST /send/{chat_id}` endpoint with a
  JSON message body would support arbitrary text without putting message content
  in the URL. That alternative endpoint is not implemented or called by this app.
- Long message URLs may receive HTTP 414; the client reports that error without
  truncating the draft. GET message paths can appear in backend access logs.
- Uploads and role/style configuration are disabled in backend mode because no
  corresponding endpoints exist. Attachments are never silently dropped or sent
  as local paths. Demo mode retains the local attachment and configuration UI.
- Authentication, backend retention, model identity, and whether the service
  forwards data to other systems remain unspecified. Use synthetic data until
  those deployment policies are settled. The client adds no provider secrets.

## Validation

The HTTP adapter uses `package:http` streaming requests and separate clients per
request; see the [Client.send API](https://pub.dev/documentation/http/latest/http/Client/send.html).
macOS debug and release builds include the outbound network client entitlement.

Normal tests use deterministic fake clients/backends; the live test is opt-in:

```sh
flutter test
flutter test test/inference_live_test.dart --dart-define=LIVE_INFERENCE=true
```

The opt-in live test discovers modes, starts inference, and creates normal and classification chats,
and sends synthetic messages through the same controller used by the UI.
It checks that classification returns a
single whitespace-delimited label. It checks success and
exclusion of prompt/control tokens. Running it creates test chats on the
backend; this API provides no cleanup endpoint.


For transport timing through the real adapter and controller:

```sh
flutter test test/stream_delivery_live_test.dart --dart-define=LIVE_INFERENCE=true
```

This separate opt-in probe prints chunk counts and arrival times without message
content. A chunked response can still arrive entirely at completion; see the
[measured delivery report](streaming_diagnostics.md).
