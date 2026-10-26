# Article redirect policy checkpoint

The bounded article downloader now normalizes both URL schemes before rejecting an HTTPS-to-HTTP redirect. It also rejects redirects when the source URL is unavailable or either URL is not an allowed HTTP(S) URL. The five-hop limit remains in the downloader.

On macOS, Xcode MCP ran 237 Swift Testing functions with 512 passing executions, no failures or skips. A focused run passed four executions: the policy test covers mixed-case downgrade schemes, allowed upgrades and same-scheme redirects, missing sources, credentials and unsupported targets; the real loopback HTTP server confirms the document-only request path and the five-hop loop limit. Strict SwiftLint and `git diff --check` passed.

The mixed-case checks exercise the policy directly. They do not establish whether URLSession preserves those spellings in an actual HTTPS redirect, and no real TLS downgrade was exercised. Existing HTTP isolation evidence remains separate from physical-device, accessibility, offline/restart and performance acceptance.
