# F: native HTML5 compatibility checkpoint — 2026-10-25

This records the first native replacement **before** the owner required complete image/resource blocking. The final implementation and current acceptance are in [active-content isolation](f-active-content-2026-10-25.md); its 320-execution full plan and new live fingerprints supersede this checkpoint. The historical five-image Wikipedia result below is not the current image policy.

The owner selected WebKit plus Mozilla Readability after the [live XML-parser failures](f-live-html-2026-10-25.md). The shipping ArticleContentService now uses that architecture. The existing bounded native transport remains before parsing. This accepts named Mac code/live observations, not complete product or platform scope.

## Implementation and boundaries

At this preceding checkpoint WebKit parsed downloaded HTML as a local document with page scripting disabled; the final path instead keeps source HTML in a native inert DOMParser document and never loads it as a page. The trusted prefix supplies CSP `default-src 'none'; form-action 'none'` and the first base URL, taken from the final downloaded response. Page JavaScript is disabled independently of CSP; an ephemeral website-data store is used. The navigation policy permits only local about navigation. Readability runs as trusted bundled code in WebKit's isolated default client world against a cloned document. Source scripts are not evaluated; extracted links use the trusted source base.

Native page orchestration belongs to MainActor; WebKit performs document/JavaScript work in its content process. The actor admits at most two complete extraction operations at once. Queued cancellation releases its waiter without starting HTTP, disturbing either current owner or losing the next available slot. The 4,000,000-byte payload/input boundaries and 50,000-element Readability limit remain. These are not total process-memory or CPU/energy guarantees.

Cancellation checks surround loading and JavaScript delivery. A weak page hop stops owned loading on cancellation; completion also stops it. The service does not invalidate caller-owned URLSession state. Current/stale article/request publication remains guarded by ReaderSession. No private WebKit API or new HTML-parser package is used.

The source no longer imports JavaScriptCore or calls JSDOMParser. Its unused resource is retained only until this replacement's hosted confirmation; the pinned Readability source and attribution remain unchanged.

## Code evidence

Five initial HTML5 executions fail with the old parser: ordinary void tags, omitted closing tags, named entities, unquoted attributes and malformed formatting. [Raw red summary](f-html5-red-2026-10-25.json). All five pass with native parsing. The old expectation that an unfinished paragraph must be unavailable is obsolete: WebKit correctly recovers it. The no-article test now checks empty, script/style-only and image-only documents; the hosted-view failure fixture uses empty content. Malformed recovery remains positive coverage.

The final focused run passes **65 Swift Testing executions**. [Raw focused result](f-native-html-focused-2026-10-25.json). It includes extraction generations, after-parsing delivery, transport failures/cancellation/limits, actual hosted SwiftUI lifetimes and the new parser/policy cases.

Security/lifetime checks use actual native frameworks through Swift Testing:

- A configuration requesting page JavaScript is passed to the factory, then raw HTML without CSP is loaded. Its script cannot set the DOM marker.
- The actual custom resource handler first receives a control-image load without CSP. The protected document then produces zero handler calls for script, image, stylesheet/import/background, video, frame, object and refresh URLs. Its source scripts do not run and its malicious base cannot replace the trusted link base.
- The navigation check observes the actual native decision for an otherwise loadable custom URL, verifies cancellation, zero resource calls and the original document body. The first version wrongly expected a thrown error; WebKit left that iteration awaiting events. [Preserved one-minute assumption failure](f-native-html-navigation-assumption-2026-10-25.json). The deadline was not increased.
- A controlled change to allow all navigation makes the revised case fail at all three checks: allow decision, resource call and replaced body. [Raw mutation failure](f-native-html-navigation-mutation-red-2026-10-25.json). The protected policy was restored before final runs.
- Four native page graph outcomes cover success, empty content, pre-cancelled loading and cancellation while the actual navigation decision is held. The caller ends before that gate opens; after external references and fixture policy work are released, page/resource-handler/gate weak references disappear.
- An observed third queued extraction cancels while two HTTP owners remain held, sends no request and leaves both owners running. After one owner completes, the next request starts while the other is still held. Existing exact-limit and payload-cancellation graphs remain passing.

The complete native My Mac plan at 18-38-35 passes **160 Swift Testing functions / 283 executions plus seven unchanged UI methods / 290 total executions**, 167 distinct tests and 47 parameterized functions / 170 cases, no failures/skips/runtime warnings. [Full raw result](f-native-html-full-2026-10-25.json). The resource positive control was then added without changing production source; final isolation/lifetime suites pass all seven executions at 18-45-25. Strict SwiftLint, native build-for-testing and diff checks pass. Exact-source hosted confirmation is pending.

## Shipping live observation

[Exact native snippet](f-native-html-live-probe-2026-10-25.txt) · [Live report with source fingerprint](f-native-html-live-2026-10-25.json). This calls the shipping service, not the earlier prototype. Each original public input now returns extracted text with its expected marker:

| Input | Text characters | HTML bytes | Links / images |
|---|---:|---:|---:|
| Apple Newsroom article | 18,820 | 27,191 | 24 / 0 |
| Wikipedia Swift article | 56,249 | 428,866 | 659 / 5 |
| German help article | 524 | 661 | 0 / 0 |
| Preisjaeger index | 1,628 | 18,058 | 5 / 0 |

All returned HTML has zero script elements. That output count alone does not prove nonexecution; the separate negative runtime checks above provide it. No complete external article text or personal account data is committed. Counts and timings are point observations, not a benchmark. The index is not a deal-quality or feed-acceptance sample, and lazy media/editorial fidelity still needs broader review.

## Criteria

| Criterion | Status | Evidence or remaining work |
|---|---|---|
| Native HTML5 compatibility for the reproduced failures | Fulfilled on exercised Mac | Five red/green fixtures and four shipping live inputs. |
| Script/resource/navigation isolation and trusted base | Fulfilled on exercised Mac | Independent no-CSP script check, positive resource control, actual decision/body assertions and failing allow-all mutation. |
| Bounded transport, admission and cancellation/release | Fulfilled on exercised Mac | Exact byte limit, early aborts, observed queue, current/stale request matrix, native page graphs and SwiftUI component release. |
| Full current local Mac plan | Fulfilled | All 290 executions pass; final strengthened policy suites pass seven; build/lint pass. |
| Hosted confirmation and parser-resource retirement | Open | Confirm this source in Reader CI before removing the unused JSDOMParser resource. |
| Final product/platform and resource scope | Open | Owner-deferred actual network-off/restart, final iPhone/iPad and physical signing, accessibility, hosted WebKit pixel capture, broader media/editorial quality, memory/energy, PCC and separate-device FreshRSS remain independent. |

F/#51 and #33/#34 remain open. A successful parser replacement does not accept those deferred requirements. Keep separate Swift CodeQL/tracer failures visible under K.
