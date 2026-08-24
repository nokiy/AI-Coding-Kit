# Repair Ladder

Two counters govern how a bug escalates. Read both before touching code — `tdd` and
`diagnosing-bugs` each check them at the repair bench. Triage never does: triage decides which
ticket owns an item and whether it's worth doing, not how many times it has been fixed.

## The two counters

| Counter | What it counts | Where to read it |
| ------- | -------------- | ---------------- |
| **Rounds** | how many times *this one bug* has been fixed | the ticket's `Rounds:` field |
| **Breaker** | how many *distinct* bugs *this one feature* has produced | the number of repair tickets under that feature |

Everything below is a prompt, never a gate — nothing here blocks you. Five rounds doesn't mean
you're bad at this; some bugs are just hard.

## The Rounds field

- **GitHub**: a `**Rounds:** N` line in the issue body
- **Local**: a `Rounds: N` line near the top of the ticket file
- **Inheritance**: the number carries over when a bug changes container — opening a child
  ticket, promoting to a standalone one. It never resets; a bug doesn't start over at 1 because
  it moved house.

A fix ships, the user comes back with "still broken" → `Rounds` +1, then read the ladder.

## Rounds ladder

| Rounds | Container | Prompt |
| ------ | --------- | ------ |
| **1** | a line in the host ticket's comments | none |
| **2** | open a **child ticket** under the host (`Found in #<host>`) | "second attempt — open a child ticket and run `diagnosing-bugs` first to get a command that goes red; without one the third attempt is another guess" |
| **3** | promote the child to a **standalone ticket** | "third attempt — promote it and re-run `triage`; this is no longer something you fix in passing" |
| **4+** | stays on that ticket | 🛑 "your call: ① change the implementation approach ② change the dependency ③ accept it and mark it a known issue" |

The stop at 4 hands the wheel to the user — it is not a block. "Keep going" means keep going.

**Bar for opening a child ticket = observable.** A difference you can see at runtime earns a
ticket; comments, formatting and renames stay in the host ticket's comments however many times
they come back.

## Breaker — the third repair ticket on one feature

A feature accumulating its third repair ticket → "third distinct bug here — worth a look at the
design?" → `codebase-design` (one spot) or `improve-codebase-architecture` (whole repo).

**Two separate axes**: the breaker counts *distinct bugs*, Rounds counts *attempts at one bug*.
Three bugs in one feature isn't bad luck — that shape isn't holding correctness.

## Closing note — the ticket is the ledger

Closing a repair ticket **requires a one-line closing note**: root cause + fix. That line is the
only input the next round has; without it `Rounds: 3` is a number with no history behind it.

The feature spec's Change Log records **behaviour changes only** (an acceptance criterion moved,
a design flaw surfaced), linked by ticket number — it is not a per-repair log and carries no
count of its own.

Edit the thresholds above to match how you actually work.
