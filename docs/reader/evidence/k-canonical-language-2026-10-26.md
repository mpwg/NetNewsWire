# K: canonical English issue descriptions — 2026-10-26

The owner requires English code and documentation; German belongs in translations or explicitly captured language fixtures. Reader guides and implementation work packages already use English, but inspection found German canonical descriptions in the earlier GitHub audit inventory. This follow-up covers historical audit/recommendation/report issues #2–#44. The complete language requirement remains open until that inventory is reviewed; this is not product acceptance.

## Verified descriptions

| Issue | Current English title | Language action | Preserved disposition |
|---|---|---|---|
| [#2](https://github.com/mpwg/NetNewsWire/issues/2) | Author migration treats database errors as completion and deletes legacy data | Title and full body translated | Closed, not planned |
| [#3](https://github.com/mpwg/NetNewsWire/issues/3) | Cooperative author migration overwrites authors from intervening feed updates | Title and full body translated | Closed, not planned |
| [#4](https://github.com/mpwg/NetNewsWire/issues/4) | CloudKit acknowledges real partial failures and drops pending status changes | Title and full body translated | Closed, not planned |
| [#5](https://github.com/mpwg/NetNewsWire/issues/5) | Status queues need serialization and revision-bound acknowledgements | Already English; reviewed | Closed, completed for the previously accepted Reader replacement contract |
| [#6](https://github.com/mpwg/NetNewsWire/issues/6) | Feed settings migration cannot resume after interruption | Title and full body translated | Closed, not planned |
| [#7](https://github.com/mpwg/NetNewsWire/issues/7) | Widget refresh misses changes to total counts | Title and full body translated | Closed, not planned |
| [#8](https://github.com/mpwg/NetNewsWire/issues/8) | XML format detection bypasses parser encoding and namespace support | Title and full body translated | Closed, not planned |
| [#9](https://github.com/mpwg/NetNewsWire/issues/9) | Atom processing discards valid prefixed article fields | Title and full body translated | Closed, not planned |
| [#10](https://github.com/mpwg/NetNewsWire/issues/10) | Metadata parsing and image scaling execute synchronously on the UI actor | Already English; reviewed | Open; remaining requirements unchanged |
| [#11](https://github.com/mpwg/NetNewsWire/issues/11) | A global serial parser queue couples independent feed refreshes | Title and full body translated | Closed, not planned |

All ten receive a dated clarification linking owner-authorized source retirement at e61b2fa26. The stale retained-legacy statement in #10 is corrected; its replacement evidence and remaining platform requirements are unchanged. The original audit/reassessment remains historical: exclusion is not repair, earlier static evidence is not a runtime reproduction, and later deletion is not acceptance of unfinished Reader requirements.

Before each update the live issue title/body was compared with the reviewed snapshot. Every original URL, inline code identifier and fenced runtime-output block was verified present in the replacement body. Fenced output is checked separately from inline code so that translated surrounding prose cannot be mistaken for a code identifier. The update response was checked for the exact intended title/body and unchanged state/state reason. No labels, assignees, milestone or state fields were submitted. Historical source references remain pinned to 7e17aec6406263378f788812d452859016fcd1ed; no current source repair, migration, service call or new test result is asserted by a translation.

## Remaining work

- Issues #12–#44 still need individual language review and translation where necessary. Some accepted replacement issues may already be English; do not rewrite their evidence unnecessarily.
- Preserve dated findings, original code links, acceptance limits and later disposition. Do not reopen or close an issue as a side effect of language work.
- Ten of the 43 historical descriptions are reviewed, with eight translated. It does not claim that every GitHub document is now English.

README and the acceptance/handoff documents link this partial result. No app, test, build configuration or CI source changes in this language-only step. The active native VoiceOver diagnostic run remains independent; all accessibility, platform, model-quality and service requirements keep their existing status.
