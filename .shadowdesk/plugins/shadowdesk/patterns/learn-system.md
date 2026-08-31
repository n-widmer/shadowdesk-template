---
id: learn-system
title: A learn folder, the plain-English basics of your own setup
applies-to: folder-structure
since: 0.14.12
---

## What this is

Eight short pages that explain what your setup is actually made of: what a skill is, what a workflow
is, what an API and an MCP server are, what an agent is, how Claude remembers you, and how to ask for
things so you get better work back. Written for someone with no technical background, about a page
each. It's there for the moment something stops making sense and you'd rather not have to ask.

## Canonical content

A `learn/` folder at the root of your setup, next to `references/`.

- **`learn/` answers "what is this."** `references/` answers "how do I do this." A concept is
  explained in one place, not both. Where they touch, the learn page gives the idea in plain words
  and links to the reference for the detail.
- **One page per idea, no numbers in the filenames.** The reading order lives in `learn/README.md`,
  so a page can be added or re-ordered without renaming anything or breaking a link.
- **Every page has the same six parts:** in one line, the picture (an everyday analogy), why you care
  (in business terms), what this looks like in your setup (pointing at your real files), try this
  (one action, two minutes), and next.
- **Every page ends with something to do.** This folder gets read by someone who feels behind. They
  should close it having done something, not just having read something.
- **A rule in CLAUDE.md does the real work.** When you sound lost or say a version of "I don't get
  it," Claude names the one page that covers it and offers to walk you through it out loud, using
  your own business as the example. Most people never go looking for a folder like this on their own.

## Merge guidance

If the client has no `learn/` folder, create it and copy the pages in from
`${CLAUDE_PLUGIN_ROOT}/learn/` (the shipped copy that came with the toolkit), then add the two
CLAUDE.md pieces: a `/learn/` line in their Pointers section, and the "when I sound lost" rule at the
end of their behavioral rules. If they already have a `learn/` folder, do NOT restructure it and do
NOT overwrite a page they may have edited: add only the pages they're missing, and tell them which
ones you added. Additive only.

Maintainer note, not client-facing: the pages exist twice on purpose. `learn/` at the template root is
what a new client gets when they clone. `${CLAUDE_PLUGIN_ROOT}/learn/` is the only way the pages can
reach a client who is already running, because Day One severs their clone from the template. Re-copy
the plugin folder whenever a page changes.
