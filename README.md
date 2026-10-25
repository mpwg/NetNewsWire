## Reader fork for OS 27 and later

The shared SwiftUI/SwiftData app uses FreshRSS and on-device daily digests. Open **`Reader/Reader.xcodeproj`**, created with Apple's native template through Xcode MCP. The [Reader guide](ReaderKit/README.md), [test review](docs/reader/test-review-2026-10-24.md) and [acceptance matrix](docs/reader/acceptance.md) describe setup, current evidence and outstanding checks. All Reader targets enable Approachable Concurrency and compiler warnings as errors. Most coverage uses Swift Testing code tests, with a small native UI suite. The existing implementation was adopted through PR #57; [umbrella #45](https://github.com/mpwg/NetNewsWire/issues/45) tracks the remaining work. [SwiftData recovery with 10,000 synthetic articles and real process restarts](docs/reader/evidence/b-2026-10-24.md) is documented separately from app, device and service acceptance.

Accepted foundation checkpoint [2be912aef](https://github.com/mpwg/NetNewsWire/commit/2be912aef): [Mac, iPhone and iPad CI pass](https://github.com/mpwg/NetNewsWire/actions/runs/40172667411/attempts/2), including 86 Swift Testing contracts in 12 suites, two Mac / one iOS native UI tests, and the Mac process-recovery probe. The shared Debug launch default is saved through Xcode. The initial hosted iPad XCTest startup failure and successful selective rerun remain documented in [A evidence](docs/reader/evidence/a-2026-10-25.md). Superseded infrastructure remains preserved for K; full device, service, accessibility and quality acceptance is separate.

The Reader persistence core (B/#47) is accepted after A: 25 code contracts and current 10,000-article SIGKILL/reopen evidence prove durable state, complete canonical versions and deletion/star retention. [B evidence and remaining app/device/service limits](docs/reader/evidence/b-2026-10-25.md).

G/#52 now connects bounded ImageIO thumbnails to normal feed rows, with three new code contracts. [Current implementation, tests and open acceptance](docs/reader/evidence/g-2026-10-25.md) distinguish this step from real image-load, credential and energy checks.

C/#48's current core contracts pass **111 Swift Testing functions plus three native UI tests / 176 Mac executions**; [Reader Mac CI 40189552390](https://github.com/mpwg/NetNewsWire/actions/runs/40189552390) passes at 449d59abc. The queue repair fixes eight reproduced cancellation failures. Real-store/HTTP contracts verify exact revisions, failure preservation/retry, empty folders, mutation errors, own-commit completion, FIFO responses, middle-waiter recovery and independent accounts. All five mapped C audits are accepted for the Reader replacement. [C evidence](docs/reader/evidence/c-2026-10-25.md) and [queue evidence](docs/reader/evidence/c-queue-2026-10-25.md) preserve red/green artifacts and scope. Separate GitHub-managed Swift CodeQL fails in its tracer before analysis; repository-wide CI is not accepted.

A [journaled real FreshRSS round trip](docs/reader/evidence/c-live-roundtrip-2026-10-25.txt) confirms read-state propagation between two separate native Mac stores/sessions and restoration of the original status with empty outboxes. It uses the isolated Test account without printing credentials. Separate devices and actual network-off/restart acceptance remain open; the owner deferred the Mac offline run on 2026-10-25. C stays open for this tail while Mac work continues on its proved core. Final iPhone/iPad revalidation remains deferred.

The added native Mac load scenario proves scrolling/form input during controlled image/HTTP-fallback work and cancellation after the real feed rows disappear. Most coverage remains code tests: 101 Swift Testing functions and three Mac UI tests / 143 local executions; [Mac CI 40186614810](https://github.com/mpwg/NetNewsWire/actions/runs/40186614810) passes at 10b5777d7. Metadata scanning stops at the head/body boundary; controlled tests cover interleaving, OS errors, cancellation between credential recovery calls, chunk bounds and service/transport release. After owner permission, real native Keychain retrieval and a 32×32 thumbnail also pass. [G evidence](docs/reader/evidence/g-2026-10-25.md) and [lifetime evidence](docs/reader/evidence/g-lifetimes-2026-10-25.md) preserve exact scope, results and remaining platform/service limits.

Development verification now focuses on macOS at the owner's request. Automatic Reader CI runs Mac; manual `coverage: all` preserves the complete matrix for final acceptance. iPhone/iPad revalidation and physical-device prerequisites remain open.

Current D/#49 implements owner-approved Mac multi-selection, shared status actions and a confirmed feed-wide read command. Menus use cached identities; only confirmation resolves and atomically changes the current unread set. The full native Mac plan passes **123 Swift Testing functions plus five UI tests / 200 executions**. Native checks prove keyboard range selection, input/scrolling during a held feed query, query-free menu/cancel paths and exactly 300 confirmed changes beyond a 200-row page. [Reader Mac CI 40199383420](https://github.com/mpwg/NetNewsWire/actions/runs/40199383420) passes at 350e32eea, including all code/UI tests, recovery and runner contracts. #12 is accepted for the Reader replacement; #41 retains deferred iOS scope. [D evidence](docs/reader/evidence/d-2026-10-25.md) and [feed-action evidence](docs/reader/evidence/d-feed-read-2026-10-25.md) preserve initial failures and remaining state/error/counter/final-platform limits.

The following guide describes the original NetNewsWire targets, retained during replacement acceptance.

<img src=Technotes/Images/icon_1024.png height=128 width=128 style="display: block; margin: auto;"> 

# NetNewsWire

NetNewsWire is a free and open-source feed reader for macOS and iOS.

It supports [RSS](https://cyber.harvard.edu/rss/rss.html), [Atom](https://datatracker.ietf.org/doc/html/rfc4287), [JSON Feed](https://jsonfeed.org/), and [RSS-in-JSON](https://github.com/scripting/Scripting-News/blob/master/rss-in-json/README.md) formats.

More info: [https://netnewswire.com/](https://netnewswire.com/)

You can [report bugs and make feature requests](https://github.com/Ranchero-Software/NetNewsWire/issues) here on GitHub. You can also [read change notes](https://github.com/Ranchero-Software/NetNewsWire/releases/) for current and previous releases.

Here’s [How to Support NetNewsWire](Technotes/HowToSupportNetNewsWire.markdown). Spoiler: don’t send money. :)

(NetNewsWire’s Help menu has these links, so you don’t have to remember to come back to this page.)

#### Community

[Join the forum](https://discourse.netnewswire.com/) to talk with other NetNewsWire users — and to help out, if you’d like to, by testing, coding, writing, providing feedback, or just helping us think things through. Everybody is welcome and encouraged to join.

Every community member is expected to abide by the [code of conduct](CONTRIBUTING.md#code-of-conduct) which is included in the [Contributing](CONTRIBUTING.md) page.

#### Pull Requests

See the [Contributing](CONTRIBUTING.md) page for our process. They key thing is to ask before doing a PR (before even starting work). The Contributing page goes into more detail as to why it’s important to ask first.

#### Building

You can build and test NetNewsWire without a paid developer account.

```bash
git clone https://github.com/Ranchero-Software/NetNewsWire.git
```

You can locally override the Xcode settings for code signing
by creating a `DeveloperSettings.xcconfig` file locally at the appropriate path.
This allows for a pristine project with code signing set up with the appropriate
developer ID and certificates, and for developer to be able to have local settings
without needing to check in anything into source control.

You can do this in one of two ways: using the included `setup.sh` script or by creating the folder structure and file manually.

##### Using `setup.sh`

- Open Terminal and `cd` into the NetNewsWire directory. 
- Run this command to ensure you have execution rights for the script: `chmod +x setup.sh`
- Execute the script with the following command: `./setup.sh` and complete the answers.

##### Manually 

Make a directory `SharedXcodeSettings` next to where you have this repository.

The directory structure is:

```
directory/
  SharedXcodeSettings/
    DeveloperSettings.xcconfig
  NetNewsWire/
    NetNewsWire.xcodeproj
```
Example:

If your NetNewsWire Xcode project file is at:
`/Users/name/projects/NetNewsWire/NetNewsWire.xcodeproj`

Create your `DeveloperSettings.xcconfig` file at
`/Users/name/projects/SharedXcodeSettings/DeveloperSettings.xcconfig`

Then create a plain text file in it: `SharedXcodeSettings/DeveloperSettings.xcconfig` and
give it the contents:

```
CODE_SIGN_IDENTITY = Mac Developer
DEVELOPMENT_TEAM = <Your Team ID>
CODE_SIGN_STYLE = Automatic
ORGANIZATION_IDENTIFIER = <Your Domain Name Reversed>
DEVELOPER_ENTITLEMENTS = -dev
PROVISIONING_PROFILE_SPECIFIER =
```

Set `DEVELOPMENT_TEAM` to your Apple supplied development team.  You can use Keychain
Access to [find your development team ID](/Technotes/FindingYourDevelopmentTeamID.md).
Set `ORGANIZATION_IDENTIFIER` to a reversed domain name that you control or have made up.
Note that `PROVISIONING_PROFILE_SPECIFIER` should not have a value associated with it.

You can now open the `NetNewsWire.xcodeproj` in Xcode.

Now you should be able to build without code signing errors and without modifying
the NetNewsWire Xcode project.  This is a special build of NetNewsWire with some
functionality disabled.  This is because we have API keys that can't be stored in the
repository or shared between developers.  Certain account types, like iCloud and Feedly, aren't
enabled and the Reader View isn't enabled because of this.

If you have any problems, we will help you out in the forum ([see above](README.md#Community)).
