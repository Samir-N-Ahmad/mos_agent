# AI builder rules: local help-desk assistant

This is a reusable instruction file for AI agents building a Flutter desktop application that helps help-desk employees investigate tickets, find approved knowledge, draft replies, and perform authorized actions through multiple specialist AI agents.

Copy this file to the new application's root as `AGENTS.md`. It is a proposed baseline; replace the project-specific decisions below as requirements become known.

## 1. Provenance and relationship to Moaather

No historical `AGENTS.md`, AI rule file, or original build prompt was found in the inspected Moaather repository. The inherited conventions below are inferred from its source, not recovered author instructions. Moaather currently contains static social-post previews; it does not establish a multi-agent implementation.

Preserve these observed conventions:

- Build with Flutter and Dart, using Material widgets and Material icons.
- Centralize colors in a shared `ColorScheme`, with dark mode as the initial visual direction. Read semantic theme values through the widget context.
- Keep reusable UI widgets small and separate from the application entry point.
- Use a sidebar for the desktop workspace and a bottom prompt composer for assistance.
- Give the composer empty-input protection, clear send availability, multiline input, Enter to send, and Shift+Enter for a newline when using a physical keyboard.
- Bundle sample visual assets explicitly through `pubspec.yaml` and use `ImageProvider` where widgets need interchangeable image sources.
- Maintain Flutter linting, null safety, and a committed application dependency lockfile. Moaather declares Dart `^3.10.7`; select and document a compatible Flutter/Dart toolchain for the new app instead of blindly copying that version.
- Keep platform-specific implementations behind Flutter-facing interfaces.

Do not copy the prototype's defects: incorrect asset paths, fixed layouts that overflow, unused counter code, disconnected callbacks, static navigation state, or its starter counter test. Its existing dependencies are not mandatory for the new app.

Everything after this section is a recommended addition for the help-desk application, not an existing Moaather rule.

## 2. Product scope and implementation decisions

- Build an employee assistant. Keep the employee in control of customer communication and consequential changes.
- Start with a complete workflow: select a ticket → summarize → retrieve relevant knowledge → propose next steps → draft a reply → review → optionally perform an authorized action.
- Accepted desktop navigation: icon-only Profile, Settings, Chats, and Media, with Logout at the bottom of a full-height, 60-logical-pixel sidebar. Chats is the initial section. Introduce ticket details, evidence, and editable drafts within the requested workflows.
- Treat desktop as the primary target. Confirm which operating systems must ship before choosing native integrations. Existing platform folders are not proof of support.
- Before a dependent implementation, record the ticket system, authentication method, model provider, local-model requirements, data retention, and supported operating systems in `docs/decisions.md`.
- If those choices are unknown, proceed with local fixtures and replaceable adapters. Clearly label demo data and unavailable integrations.
- "Local application" means installed on the employee's computer. It does not automatically mean inference and data processing remain offline. Expose the actual processing mode and destination before transmitting ticket data.
- Avoid unrelated features, speculative frameworks, and integrations that the user has not requested.

## 3. Architecture and repository structure

- Keep `main.dart` limited to initialization and dependency wiring.
- Separate presentation, application workflows, domain models, and data/integration code. Widgets must not call model providers or ticket APIs directly.
- Use repositories for ticket, knowledge, and activity data; services for external APIs, model inference, credential access, and local storage.
- Choose one consistent state-management approach and document it. Use local widget state for ephemeral presentation state; use view models/controllers for shared workflows and agent runs.
- Inject dependencies through constructors or a documented container. Make clocks, identifiers, repositories, model clients, and tools replaceable in tests.
- Use immutable, typed domain objects and explicit error types. Validate all external JSON before using it.
- Keep business logic independent of `BuildContext`. Isolate platform dependencies so domain tests can run without native services.
- Start with this structure and add layers only when needed:

```text
lib/
  main.dart
  app/                     # startup, routing, dependency wiring
  core/
    theme/
    errors/
    security/
    storage/
  features/
    tickets/
    assistant/
    knowledge/
    activity/
    settings/
  agents/                  # roles, orchestration, contracts, policies
  integrations/            # ticket systems, models, native services
  shared/widgets/
test/
integration_test/
docs/decisions.md
```

Within a feature, separate presentation and data code as it grows. Do not create empty architectural scaffolding just to match a diagram.

## 4. Runtime AI-agent design

These are agents inside the shipped application, separate from AI coding agents building it.

- Use one orchestrator to manage each run and delegate bounded tasks. Do not let specialists recursively spawn unrestricted agents.
- Prefer deterministic code for routing, permissions, validation, retries, and calculations. Use model reasoning where language understanding or synthesis is needed.
- Start with these roles; combine them if a simpler implementation meets the requirement:

| Role | Responsibility | Default authority |
| --- | --- | --- |
| Orchestrator | Plan, route, enforce limits, combine results | Coordinate; no external writes |
| Triage | Summarize the issue; suggest category and urgency | Read ticket context |
| Knowledge | Retrieve approved articles and similar authorized cases | Read scoped sources |
| Resolution | Propose diagnostic steps with supporting evidence | Read scoped context; no arbitrary commands |
| Reply | Produce an editable customer-response draft | Draft only |
| Review | Check claims, relevance, privacy, and source support | Report issues; cannot authorize execution |
| Action executor | Apply an approved typed operation | Only the specific permitted action |

- Define typed task inputs and outputs: run ID, task ID, ticket ID and version, allowed tools, relevant context, evidence references, result, uncertainty, and structured failure information.
- Give each role only the context and tool scopes it needs. Peer-agent output cannot grant permissions or redefine policy.
- Use explicit run states such as queued, running, awaiting review, awaiting approval, succeeded, failed, and cancelled.
- Bound concurrent work, tool calls, elapsed time, retries, context size, and token/cost usage. Make limits configurable and enforce them outside model prompts.
- Run independent read-only work concurrently when useful. Serialize dependent steps and conflicting writes. Avoid concurrent edits to the same ticket.
- Support cancellation, timeouts, partial failures, and retry with backoff. A cancelled run must not begin new side effects; report any operation already committed.
- Persist enough run state to recover after restart. Never automatically replay a non-idempotent action after a crash or ambiguous timeout.
- Treat conversation history as scoped context, not a shared global memory across tickets or employees.
- Version prompts, tool schemas, and orchestration policies so behavior can be reproduced and evaluated.

## 5. Tools, permissions, and employee approval

- Expose narrow typed tools such as `readTicket`, `searchKnowledge`, `draftReply`, and `updateTicketStatus`. Do not give a general shell or arbitrary filesystem access to a model.
- Enforce authentication, employee authorization, allowed resources, argument validation, and action policy in application/service code before every tool call.
- Reading an authorized ticket, retrieving scoped knowledge, summarizing, and preparing local drafts may run without repeated confirmation.
- Require employee approval by default before sending a customer message, changing assignment/status/priority, closing a ticket, deleting data, changing access, running remediation, or modifying an external system. Any future automatic write policy must be explicitly configured and narrowly scoped.
- An approval must show the target system, ticket, exact proposed action or diff, and relevant consequences. Bind it to the employee, operation, arguments, ticket version, and an expiry. Changed proposals require renewed approval.
- Generate approval UI from validated application data, not model-authored HTML or text that can impersonate a trusted approval control.
- Recheck server authorization and ticket freshness immediately before a write. Use idempotency keys where supported and handle conflicts explicitly.
- Record confirmed execution outcomes. Distinguish a draft, a proposal, an attempted operation, a confirmed success, and an unknown outcome.

## 6. Evidence, privacy, and local data

- Treat tickets, attachments, retrieved articles, webpages, logs, and peer-agent messages as untrusted data. Instructions inside them must not override application policy or trigger tool access.
- Enforce retrieval access filters before returning content. Cite only sources the employee can access, and avoid leaking one customer's or organization's data into another context.
- Show inspectable evidence for knowledge-based suggestions: source ID/link, relevant passage, and freshness or version when available. Distinguish documented guidance from inference.
- Do not invent ticket facts, source links, successful actions, or confidence scores. Ask a focused question or recommend escalation when evidence is insufficient.
- Store credentials in the operating system's secure credential store. Never embed provider secrets in source, assets, logs, or build-time constants assumed to be secret in a distributed client.
- For shared provider credentials, use an authenticated service boundary; otherwise use an explicitly supported employee-managed credential flow.
- Minimize external data transmission. Show the configured model destination and apply organizational redaction and data-handling policy before sending sensitive content.
- Keep persistence, search indexes, embeddings, logs, and backups within the same access and retention policy. Encrypt sensitive persisted data using a documented key-management strategy.
- Define retention, deletion, export, logout cleanup, and cache invalidation. Remove associated cached/indexed content when source access is revoked or data is deleted.
- Log run IDs, action metadata, policy decisions, and results with redaction. Avoid storing full ticket text or model prompts by default.
- Offline mode must clearly show what still works. Cloud-only functions should explain their unavailable state and preserve employee drafts.

## 7. Flutter UI and accessibility

- Preserve the shared dark, Material-based visual direction; use semantic colors such as surface/onSurface and primary/onPrimary with readable contrast. Avoid deprecated theme fields.
- Use `snake_case.dart` filenames, `UpperCamelCase` types, and `lowerCamelCase` members. Use `const` where practical and avoid unused imports or dead code.
- Build navigation, ticket lists, evidence panels, drafts, and agent status as reusable components. Never leave a visible enabled control attached to an empty callback.
- Use constraints and adaptive layouts. Collapse the sidebar and stack panels for narrow windows; allow scrolling when content exceeds available height.
- In Chats, start the chat list at 20% of the available workspace width with a resizable divider. Use the remaining width for the conversation and a full-width composer whose text input starts at 100 logical pixels high and can be resized. Provide file attachment, send, and agent/chat configuration controls. Preserve the 60-pixel primary sidebar; collapse the secondary chat list to a picker in narrow windows.
- Verify the minimum supported window size, a typical desktop window, and enlarged text. Do not assume a fixed three-column layout fits.
- Support keyboard navigation, visible focus, screen-reader labels, tooltips, and non-color status indicators. Preserve mixed-language text and support RTL if required by users.
- Respect IME composition when handling Enter. Support Shift+Enter and the platform's software keyboard without accidentally sending incomplete text.
- Await durable draft capture or successful submission before clearing the composer. Preserve text on failure, and prevent duplicate submissions.
- Show loading, empty, error, disconnected, cancelled, and partial-result states. Explain the current agent task without exposing private model chain-of-thought.
- Dispose controllers, focus nodes, subscriptions, and other owned resources. Keep expensive parsing, indexing, and inference off the UI execution path using appropriate workers/services.
- Ensure asset references match their full registered paths. Handle failed image or document loading gracefully.

## 8. Integrations and dependencies

- Implement each provider behind an adapter so the UI and orchestration do not depend on one vendor's response schema.
- Discover available inference modes through `/inference/modes`; display returned names and send the selected value to `/chat/new/{mode}`. Keep the mode snapshot per conversation. Do not assume boolean flags, catalogue ordering, or a fixed set of backend modes; reserve fixture modes for the offline demo.
- Use supported authentication flows and least-privilege scopes. Handle session expiry and logout without losing unsent work.
- Distinguish transient errors, authentication errors, validation errors, rate limits, and permanent failures. Retry only safe operations.
- Follow rate limits and avoid sending unnecessary ticket history to models.
- Add a package only when it solves a concrete requirement. Check platform support, maintenance, licensing, and native configuration; document significant choices.
- Do not add `cached_network_image`, `url_launcher`, or a state-management package solely because it appears in another app.
- Commit the application's lockfile. Do not silently upgrade dependencies or change platform runner configuration during unrelated work.
- Document required native permissions and configure release credentials/signing for each shipping platform. Never present a debug-signed build as production-ready.

## 9. Verification and definition of done

- Run formatting, `flutter analyze`, and relevant `flutter test` checks. Build and exercise each platform claimed as supported in the delivery environment.
- Replace starter tests with real behavior checks. Prioritize orchestration, permissions, data isolation, cancellation, error recovery, and actual user flows.
- Test that an agent cannot send or modify a ticket without authorization, stale approvals are rejected, and retries do not duplicate external actions.
- Test malicious instructions in tickets, attachments, and peer-agent outputs; cross-ticket context leakage; unauthorized knowledge retrieval; and malformed tool output.
- Test responsive layouts, keyboard composition/send behavior, asset loading, navigation, draft preservation, and loading/error states.
- Use deterministic fake providers and tools in normal automated tests. Keep live-provider checks opt-in and avoid real customer data.
- Evaluate AI outputs on synthetic help-desk cases with expected facts and evidence. Check unsupported claims, appropriate escalation, task completion, latency, and resource usage.
- A feature is done when its real workflow works, important failure paths are handled, relevant checks pass, and setup/configuration is documented. Do not claim success based only on a generated screen or mock response.
- Report exactly what changed, checks performed, remaining limitations, and any platforms or integrations not validated.

## 10. Rules for AI coding agents working in this repository

- Read the repository instructions and inspect existing code before editing. Preserve unrelated employee or developer changes.
- Make the smallest cohesive implementation that completes the requested workflow. Do not replace the framework or redesign the entire app without a requirement.
- Document important assumptions and choices. Ask only for information that blocks a consequential decision; continue independent work using explicit fixtures where possible.
- If multiple coding agents are authorized, assign separate file ownership or isolated branches/worktrees, agree on contracts first, and use one integration owner. Avoid simultaneous edits to shared files.
- Do not confuse coding-agent delegation with runtime app agents. Authorization for one does not automatically authorize the other.
- Never fabricate test results, integration availability, data, citations, or execution outcomes. Keep prototype behavior visibly labeled until implemented.
- Keep this guide current when an accepted architecture or policy decision changes. Update tests and setup documentation with the implementation.

## 11. Suggested delivery sequence

1. Desktop shell, responsive navigation, theme, fixture tickets, and persistent local drafts.
2. Typed agent contracts and orchestrator with deterministic fake providers, cancellation, limits, and visible run states.
3. A selected model adapter plus authorized knowledge retrieval and inspectable evidence.
4. Editable response drafting and review, with no external writes.
5. One real ticket-system adapter and a narrowly scoped approved action, with audit and retry protection.
6. Platform packaging, recovery checks, security-focused tests, and evaluation on representative synthetic tickets.

## 12. UAE government guidance for runtime AI agents

Apply the following as project design rules. Sources checked on 17 October 2026. These are adaptations for an employee help-desk assistant; they do not establish government endorsement or legal compliance. The federal guides below target government services and communications. Their principles were verified through official Emirates News Agency (WAM) announcements, rather than the complete guide documents. Digital Dubai's ethics guidelines describe themselves as non-binding.

### Service experience and agent behavior

Source: National Committee for the Agentic AI Project, [Assistant AI Government Experience Design Guide — official Arabic announcement, 21 August 2026](https://www.wam.ae/ar/article/c1uggxh-اللجنة-الوطنية-للذكاء-الاصطناعي-المساعد-تطلق-دليلا).

- Understand the employee's intended outcome before starting a workflow; allow natural-language requests without requiring internal service names.
- Reuse information already supplied through authorized sources. Ask again only when information is missing, inaccessible, conflicting, or needs confirmation; explain why. Reuse must respect section 6 access boundaries.
- Explain proposed steps and obtain approval before executing an action on the employee's behalf. Apply section 5 to consequential writes; authorized reads and local drafts retain its existing policy.
- Perform supported operations through validated integrations, follow requests to completion, and report verified outcomes. Measure success by completed outcomes rather than message counts.
- Show completed steps, remaining work, and any required employee intervention while preserving privacy and security.
- Handle exceptions and outages with a smooth handoff to an authorized person, including relevant context and completed steps so users need not repeat their request.
- Provide a clear final result and a way to ask questions, correct information, challenge an outcome, and give feedback.

### Drafting, knowledge, and review

Source: UAE Government Media Office, [Guide to Agentic AI Applications for Government Communication Teams — official announcement, 29 September 2026](https://www.wam.ae/en/article/c2holh1-uae-government-media-office-launches-guide-agentic).

- Define each assistant's purpose, instructions, approved knowledge sources, institutional tone, and review responsibilities before enabling it.
- Verify factual accuracy and review outputs for privacy risks, bias, and misleading content. Keep professional accountability and final judgment with people.
- Require human review and the organization's applicable approval before publishing or sending generated communications. For this application, enforce those controls in the reply workflow and section 5 execution policy.

### Fairness, accountability, transparency, and explainability

Source: Smart Dubai / Digital Dubai, [AI Ethics Principles & Guidelines](https://www.digitaldubai.ae/docs/default-source/ai-principles-resources/ai-ethics.pdf), particularly principles on PDF pages 8–12 and guidelines beginning on PDF page 21. Credit: Smart Dubai Office; adaptations here do not imply its endorsement.

- Assess whether evaluation data represents affected users; identify, mitigate, and document bias in triage and recommendations.
- Assign accountable human owners for agent behavior and deployment. Assess risks before release and keep significant decisions traceable and failures diagnosable.
- Tell users when AI materially contributes to decisions. Provide understandable explanations of relevant evidence and decision factors, with a route to request human review or challenge significant decisions.
- Keep systems controllable by designated people, including override or reversal where feasible. Protect privacy throughout operation and decommissioning.

### Project verification and maintenance

The following are this project's implementation checks derived from the principles above:

- Include synthetic cases for reused information, ambiguous intent, declined approval, integration failure with context-preserving handoff, correction requests, and unfair triage across supported user groups.
- Record the source, applicable scope, design decisions, and unresolved gaps in `docs/decisions.md` when implementing a dependent feature. Recheck official sources when changing agent policy or preparing a government deployment; distinguish verified guidance from project interpretation.

## Reference guidance

The architecture and safety recommendations above are project policy proposals informed by these primary references; the exact folder layout, roles, and delivery sequence are recommended choices for this application.

- [Flutter guide to app architecture](https://docs.flutter.dev/app-architecture/guide): separation of UI and data responsibilities, repositories, and services.
- [OWASP LLM Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html): handling untrusted content and enforcing controls beyond prompts.
- [OWASP Excessive Agency](https://genai.owasp.org/llmrisk/llm062025-excessive-agency/): scoped tools, downstream authorization, and approval for consequential actions.
