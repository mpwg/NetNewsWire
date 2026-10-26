# B / mapped audit #40: independent star retention with another subscription — 2026-10-26

The original audit's nonempty remaining subscription set is essential. The previous store test unsubscribed every feed; the previous process probe's starred article also had pending read/star changes. Such a pending change independently prevents deletion, so that probe did not isolate star-only protection.

The shipping store implementation is unchanged. The existing store test now has two Swift Testing cases: with/without a different remaining subscription, an independently starred article without pending writes survives, an ordinary unsubscribed article is removed, another feed's article remains where applicable, and no outbox changes are invented. This expanded function compiles; its new parameter cases still need fresh execution.

The standalone probe retains its 10,000-article seed, actual SIGKILL and two fresh processes. It now starts with another subscribed feed and an independent remote star on article 3. That article has neither pending revisions nor a digest reference; explicit assertions check those preconditions. Article 0 separately retains its exact two pending revisions and star; article 1 separately retains its digest reference. Unsubscription removes 9,997 unprotected articles and the original feed while leaving the other feed. Both fresh processes verify the exact three retained IDs and both stars. The final process writes selected actual store values to retention.json; the orchestrator derives report counts from that payload instead of hardcoding a retained count.

| Criterion | Status | Evidence |
|---|---|---|
| A star without pending/digest protection survives with another subscription | Fulfilled on exercised Mac core | Current standalone process run passes exact IDs 0/1/3, stars 0/3, remaining subscription feed/remaining and no pending change for article 3. |
| Independent durable recovery and cleanup | Fulfilled on exercised Mac core | Seed PID 27535 exits -9; recover PID 27540 and verify PID 27542 exit 0. WAL before kill: 271,952 bytes. Three retained articles, two exact pending revisions; 3.455 seconds excluding build. |
| Zero/nonzero subscription store-test matrix | Fulfilled on exercised Mac core | Both parameter cases pass in Reader CI 40266414089 at 80f906df8; exact original case nodes are retained below. |
| Retained unread status when FreshRSS omits an orphan | Open | Owner decision requested: preserve the last status or retain globally authoritative missing-ID semantics. This probe's independent star is already read before unsubscription and does not establish the unread case. Production status logic is unchanged pending that decision. |
| Global Starred presentation and complete persistent-app restart | Open | Both real ReaderSession/store cases pass for zero/nonzero remaining subscriptions, removed selection/detail, exact retained rows and global Starred model/detail. Model/core proof is not visible Starred-view or full Reader app restart acceptance. The owner deferred the latter. |
| Hosted confirmation of the changed probe | Fulfilled | Source 80f906df8 passes the revised independent-star/nonempty-subscription process probe and complete 415-execution Mac plan. |
| README | Fulfilled | ReaderPersistence records the independent protection case, actual payload and remaining boundaries. |

[Unaltered orchestrator report](b-star-retention-local-2026-10-26.json) · [actual final-process store payload](b-star-retention-payload-2026-10-26.json).

The probe was built through Xcode MCP using the existing ReaderStoreRecoveryProbe scheme at 04:46:28 local time, then the existing Reader scheme/My Mac destination was restored. The existing orchestrator ran only that built executable with --executable in a new isolated temporary directory. It did not invoke a compiler, access app containers or credentials, or terminate Reader. Normal Reader PID 24529 remained present after build and all probe phases. Native app/test build-for-testing, strict lint and orchestrator syntax checks pass. No UI method or project/scheme generation is introduced.

The presentation cases compare the actual retained store snapshot with selected/detail state after the shipping reload path. They require exactly one global Starred row and no pending writes, without freezing the unresolved orphan read-state policy. Native build-for-testing at 04:50:09 local time and strict lint pass; the fresh hosted result now confirms all four cases.

Source SHA-256: Probe.swift 243c85f9028d02e54fc5daa475f232eba1f644d0c718e3d86dbad8d0990677a2; verify-reader-store.py 0b5b409cbfedf2baf6b50f9acea6130f6529270753ea617e3bd3b11af60c3de8; ReaderStoreTests.swift 71cc77288e52d51f4b7f8c0ce49e48875d777d845818344a5a90a1eaaf81112b. Existing earlier recovery results remain tied to their named source and two-protected-article fixture. No legacy Local/CloudKit implementation is claimed repaired; Reader is FreshRSS-only. Keep #40 open for its remaining status, presentation and app-restart requirements.

## Fresh hosted confirmation at 80f906df8

[Reader CI 40266414089](https://github.com/mpwg/NetNewsWire/actions/runs/40266414089), job 121390037271, source **80f906df84a5370448696cb4b78f689ea43574dc**, passes **415 executions (405 code, ten native UI)**, 210 distinct tests, zero failures/skips and one deliberate model-guardrail warning. All 200 Swift Testing functions in 33 suites pass; 73 parameterized functions account for 278 executions. Lint, direct runner contracts, revised process recovery and report collection/upload pass.

[Unaltered summary](b-star-retention-ci-summary-2026-10-26.json) · [original four case nodes](b-star-retention-ci-cases-2026-10-26.json) · [unaltered recovery report](b-star-retention-ci-recovery-2026-10-26.json). Artifact ID: 12626911480. Seed PID 13226 exits -9; recover/verify PIDs 13342/13579 exit 0. The final actual payload contains three retained articles, stars 0/3, feed/remaining, two pending revisions and independentStarHasPendingChange=false. No matching native crash report is archived; that absence is not a repair claim for the earlier daemon fault. The native VoiceOver case also passes in 33.283 seconds without expanding its accepted scenario.

The later complete-count query at 69961eead is separate source and requires fresh hosted confirmation. It does not change orphan status policy. This 415-execution result does not prove the later count-query tests or make #40 complete.
