# What an MCP server is

## In one line

"MCP server" is a bad name for a simple thing. It is an adapter that plugs one of your outside tools into me, so I can use that tool for you.

## The picture

A travel plug adapter. Your hair dryer works. The hotel wall works. They do not fit each other. The adapter sits in between and both sides do their job. Someone else already made it, and you never think about it again. One limit worth knowing: one adapter fits one wall. An adapter for your email will not touch your invoices.

## Why you care

It ends the copy and paste. Ask me to pull the last three emails from a client who went quiet, and I read them and draft the follow up.

## What this looks like in your setup

`CONNECTIONS.md` in your folder is where your connected tools get written down. Section 1 is the table of what is connected. Running `/shadowdesk:end-session` fills it in.

An API is the doorway on the other tool. The MCP server is the adapter that lets me walk through that doorway, without you wiring anything up. Key handling lives in `references/api-keys.md`.

It is not a server in a building. It runs on your laptop or through your Claude account, and nothing about it is yours to maintain.

## Try this

Type this in chat: "Read CONNECTIONS.md and tell me which tools I have connected." I will read the file and tell you what the table holds. If it is empty, I will say so, and that is a true answer.

## Next

Next: [what an agent is](./what-is-an-agent.md).
