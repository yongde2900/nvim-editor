# Surveyor brief (normative)

You are answering one question about **one repository**, as part of a survey running across several
repos in parallel. A coordinator in another pane pointed you at this file and at a question.

**You are read-only with respect to this repository.** Do not edit, create, delete, stage, commit,
format, or "fix while I'm here" — not one file, however obvious the fix. Someone is deciding
whether to make a change based on what you report; discovering that the survey itself already
changed three repos turns a cheap question into an incident. If you find something that should be
fixed, say so in your answer and leave it alone.

The one thing you write is your answer file, and it lives outside this repo.

## What you were given

The prompt named two absolute paths:

- **the question** — `.../SURVEY-NNN-<slug>/QUESTION.md`
- **this file**

Read the question in full. It says what is being asked, what counts as evidence, and — under
`Why` — what decision the answer feeds. That last part matters: it tells you what a useful answer
looks like, and it is why you should report the awkward near-miss rather than rounding it to yes
or no.

## How to answer

Look at the actual code. Grep, read the files the grep hits, follow the call sites. An answer from
a plausible-sounding guess is worse than no answer, because it is indistinguishable from a real one
once it is aggregated with four others.

Cite `path:line` for everything you claim. The coordinator compares your answer against four other
repos' answers and cannot re-derive your reasoning; a citation is what makes a finding checkable
instead of merely asserted.

**"I don't know" is a real answer.** So is "the question doesn't apply here" — a repo that never had
the thing being asked about is a genuine finding, not a gap to paper over. Say which it is and why.
Being wrong in a way that looks confident is the only outcome that actually costs anyone something.

Read as much as the question needs and no more. A survey is running across several repos to get a
quick, comparable picture; it is not an audit of this one.

## Your answer file

Write to `<Survey Dir>/answers/<your-name>.md`, creating the directory if needed. The coordinator
reads it off disk, never off your terminal — agent panes often run on the alternate screen, where
your output leaves no scrollback and cannot be read back at any size. If it is not in the file, it
did not reach anyone.

```markdown
# Answer — <your-name>
Survey: SURVEY-NNN
Repo: <absolute path>
Answered: <YYYY-MM-DD HH:MM>

## Verdict
<!-- One line, directly answering the question as asked: yes / no / partially / not applicable /
     unknown. The coordinator puts these side by side in a table, so lead with the verdict and
     keep it comparable to what the other repos will have written. -->

## Evidence
- `<path:line>` — <what is there, quoted or described precisely>

## Detail
<!-- The nuance the one-line verdict had to drop: partial adoption, an exception, a wrapper that
     changes the answer, a second implementation somebody forgot about. This is usually the part
     that actually changes the decision. -->

## Caveats
<!-- What you did not look at, what you could not determine, anything that would make your verdict
     wrong. Write "none" if there are none. -->
```

Then stop and go idle. Do not start on anything else.
