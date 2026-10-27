# UI-test Keychain namespace — 2026-10-27

## Current candidate: ephemeral credentials

Candidate `e82e72153` supersedes the persistent test-service approach below. `--ui-testing` now uses a separate in-memory credential store; normal app launches continue using `KeychainCredentialStore` with the existing bundle-ID service. Test credentials last for the process/store lifetime and are not written by this store to Keychain. This is not a claim of secure memory erasure. The remote server is not isolated, and real app-bootstrap wiring, real login and real-feed navigation are not yet verified.

Xcode MCP build-for-testing passes. The full credential suite passes 20 controlled Swift Testing executions, including separate stores/accounts and pre-cancelled read, save and removal preserving existing data. [Original Xcode MCP summary](j-ui-ephemeral-xcode-2026-10-27.txt). [Candidate CI 40505848255](https://github.com/mpwg/NetNewsWire/actions/runs/40505848255) is running on this exact code. No personal account or credential was touched.

## Earlier candidate: separate persistent service

The normal app and an in-memory `--ui-testing` launch previously used the same bundle-ID Keychain service. Candidate `1d53e3414` gives the latter the service `<bundle ID>.ui-testing`; normal launches retain their existing service. Test accounts and passwords are still persisted by Keychain under the separate test service: a real test must remove its own account/credential afterward. The in-memory store does not make the remote FreshRSS server ephemeral, and this change does not copy an existing password or perform a real login.

Xcode MCP build-for-testing passes. The complete `KeychainCredentialStoreTests` suite passes 16 controlled Swift Testing executions with no failures or skips; it covers service query construction, cancellation, error propagation and protection, but does not exercise app-bootstrap wiring or real account login. The initial selective method invocation ran only six cases; the suite invocation supplied the full 16. [Original Xcode MCP summary](j-ui-test-keychain-xcode-2026-10-27.txt).

A separate native Xcode MCP code diagnostic used a fresh random synthetic service pair and one synthetic account ID. It wrote distinct artificial values under the two services, verified that the test service initially saw no normal-service value and that removing its value left the normal-service value intact, then removed both and verified their absence. Output was `Isolation: true` and `Cleanup: true`. The first snippet did not compile because a second actor call occurred in a synchronous boolean expression; no code ran in that attempt. This diagnostic verifies Keychain service separation and cleanup for the synthetic services, not the app bootstrap's chosen service, test-mode lifecycle cleanup or a real FreshRSS flow.

[Reader CI 40505561916](https://github.com/mpwg/NetNewsWire/actions/runs/40505561916) runs the full Mac plan and strict SwiftLint on the exact candidate. SwiftLint is passing; the native test job is pending. No personal Keychain entries or server subscriptions were modified. The owner-deferred local window comparison remains deferred; actual real-feed UI, final devices, accessibility and full J acceptance remain open.
