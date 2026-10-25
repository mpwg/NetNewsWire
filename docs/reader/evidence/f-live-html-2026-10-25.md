# F: live HTML5 parser gap and architecture decision — 2026-10-25

Source checkpoint 9d5fee9b9 passes the complete native and hosted Mac plans. A separate Xcode MCP native ReaderContent snippet then exercises public HTML using the shipping bounded download and parser. It uses an ephemeral cookie-free transport, writes no ReaderStore state and uses no account credentials. These observations are not additional unit/UI tests or a quality benchmark.

[Exact snippet](f-live-pages-probe-2026-10-25.txt) · [Initial live report](f-live-pages-2026-10-25.json) · [Response/parser diagnostics](f-live-parser-diagnostic-2026-10-25.json).

| Input | HTTP/input evidence | Current extraction |
|---|---|---|
| Apple Newsroom article | 200, 284,004 bytes, expected marker present | Unavailable; parser loses document/body. |
| Wikipedia Swift article | 200, 682,847 bytes, expected marker present | Unavailable; parser loses document/body. |
| German help article | 200, approximately 84.7 KB, expected marker present | 426 text characters, 1,903 HTML bytes, two image elements, five links, no script element; marker present. |
| Preisjaeger index | 200, approximately 282 KB, expected marker present | Unavailable; parser loses document/body. This is an index, not a deal-quality or feed acceptance sample. |

The diagnostic reports JSDOMParser expecting XML-style closing tags for ordinary HTML void elements such as input, link, meta and img. The pinned parser itself documents its well-formed HTML/XML requirement. The current adapter's missing-document wrapper cannot recover a discarded HTML subtree. Successful synthetic complete fragments therefore do not prove ordinary HTML5 page compatibility. No remote blocking cause is inferred for these observed 200 responses.

The owner explicitly selected **native WebKit HTML parsing plus Mozilla Readability** on 2026-10-25. The bounded transport remains ahead of parsing. Implement and verify disabled page JavaScript, blocked external resources/navigation, cancellation and native graph release before accepting the replacement. Preserve Readability source attribution; retire the old parser only after replacement evidence. Additional Swift HTML-parser dependencies were not selected.

This is a known functional gap requiring implementation. Do not close F/#51 or mapped #33/#34 from the green fixture CI. Actual network-off/restart remains owner-deferred, with final platforms, accessibility, PCC, separate-device FreshRSS and broader memory/energy acceptance still open.
