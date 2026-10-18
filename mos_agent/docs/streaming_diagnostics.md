# Stream delivery check — 18 October 2026

Normal CHAT mode was tested against `http://127.0.0.1:8000` using fresh chats
and synthetic multi-paragraph prompts. Normal chat creation now succeeds; the
previous enum path-validation blocker is resolved in the running service.

## Observations

The response headers are `Content-Type: text/plain; charset=utf-8` and
`Transfer-Encoding: chunked`. These headers permit streaming but do not prove
that model output is delivered incrementally during generation.

| Measurement | Direct Python HTTP probe | Dart adapter/controller probe |
| --- | ---: | ---: |
| Response headers arrived | 3 ms | 3.038 ms |
| First body data arrived | 3,878 ms | 2,964.890 ms |
| Last body data arrived | 3,879 ms | 2,971.054 ms |
| Observed body events | 77 | 73 |
| First-to-last body delivery span | approximately 1 ms | 6.164 ms |
| Incremental controller text updates | not measured | 72 |
| First controller text update | not measured | 2,965.894 ms |
| Client delay from first body data to first text update | not measured | 1.004 ms |
| Request completed | 3,879 ms | 2,972.718 ms |

These are separate requests, so output lengths differ. Body events are transport
chunks, not a model token count. Only sizes and elapsed times are reported by
the Dart probe; it does not print prompts, generated content, or message URLs.

## Conclusion

Both clients observed a wait followed by a very short burst of output. The
Dart decoder and controller began forwarding text about 1 ms after receiving
bytes; they did not wait for response completion. The whole burst arrived
within less than a typical display frame, so Flutter can paint only the final
answer even though the controller emits incremental updates.

The evidence points to batching at or before the API's HTTP delivery boundary.
Without backend source, the precise cause is not established: the model may
return completed text before a generator yields it, or blocking generation/server
buffering may delay flushing. Inspect the generation/yield loop and ensure
text is yielded as generation progresses, with the server event loop able to
flush it. A streaming response wrapper around an already completed result does
not provide incremental generation to the app.

The client needs no production buffering change based on these measurements.
The observed ChatML prompt envelope is intentionally suppressed; answer text
is forwarded as it arrives. Classification mode is expected to produce only a
single label and was not used to assess multi-part delivery.

## Repeatable checks

```sh
flutter test test/stream_delivery_live_test.dart --dart-define=LIVE_INFERENCE=true
flutter test test/stream_delivery_test.dart test/backend_chat_controller_test.dart
```

The live timing test uses the actual HTTP adapter and controller. It reports
arrival timing instead of asserting a token cadence the server may not provide.
It creates a fresh backend chat and sends synthetic text; it is skipped in normal
test runs.

The deterministic regression holds an HTTP response open, emits an envelope and
two answer parts separately, and checks controller updates before EOF. Existing
widget tests independently verify that partial answers appear on screen before
the final part. Formatting, analysis, and all 40 deterministic tests passed;
both live checks remain opt-in. This investigation changed tests and documentation
only; no production client code or backend source was changed.
