# Digest feed provenance checkpoint

Source commit `5d666812dc5d1506a4c7ec00ea2bfe2a50fff16a` carries feed HTML and text in `ArticleSnapshot` when they differ byte-for-byte from display content. Fresh store snapshots omit values identical to the display. Older decoded snapshots also omit the fields, so absence alone cannot establish provenance. The existing SwiftData feed fields remain the source of the snapshot; no schema migration is introduced.

Guarded content and digest writes compare feed-source bytes as well as the existing display snapshot. The new fingerprint includes both feed fields and invalidates v10 caches. A feed change can therefore invalidate a digest or reject a stale write even when display content is unchanged. This checkpoint does not yet validate offer facts against feed text or implement offer-field attribution.

Xcode MCP ran 242 Swift Testing functions / 518 executions with no failures or skips before the final fingerprint-prefix rename. After that rename, all 12 affected cache cases passed. Tests cover a real disk-store reopen, unchanged display with changed feed, stale content and digest writes, old snapshot decoding, Unicode byte differences, cache regeneration and outbox preservation. Strict SwiftLint passed. The initial complete run exposed four fixture incompatibilities; the candidate was corrected and rerun before the passing checks.

[Reader OS 27 CI 40467488641](https://github.com/mpwg/NetNewsWire/actions/runs/40467488641) passed at the exact source commit: 242 Swift Testing functions, ten native UI methods, SwiftLint, runner verification, probe build and process recovery. Local UI automation previously timed out before executing a separate fallback test; this hosted run does not establish that local prerequisite. Source content remains untrusted and no HTML execution or new network access is introduced.

Still open: meaningful attribution of merchant, price and conditions, visible unknown fields, real-model and feed quality, VoiceOver and final-device acceptance, PCC and the remaining umbrella criteria.
