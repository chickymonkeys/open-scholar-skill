# MODE 5 — R&R Cover Letter

Also load the companion reference(s) this mode uses:
```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
cat "$SKILL_DIR/.claude/skills/scholar-respond/references/response-templates.md"
```

## MODE 5: R&R COVER LETTER

Use to write a standalone cover letter for an R&R resubmission (separate from the point-by-point response letter).

### Step 1: Gather Information

Identify:
- Journal name and manuscript number
- Editor name (if known)
- R&R round (R1, R2, R3)
- Key changes made (from Mode 3 revision summary, or user input)
- Decision received (Major Revision / Minor Revision)

### Step 2: Draft the Cover Letter

**R1 Cover Letter (Major Revision)**:

```
Dear [Dr. LastName / Editor],

Please find enclosed our revised manuscript, "[Title]" (Manuscript #:
[xxx]), submitted in response to the [Major/Minor] Revision decision of
[date].

We are grateful to the Editor and [N] reviewers for their constructive
and detailed feedback. We have carefully revised the manuscript to
address all concerns raised. The major changes include:

1. [Major change 1 — briefly, 1 sentence]
2. [Major change 2]
3. [Major change 3]

[Optional: 1–2 sentences addressing the editor's specific priority if
one was identified in the decision letter.]

A detailed, point-by-point response to each reviewer comment is enclosed
separately. All changes in the manuscript are marked in [blue text /
tracked changes].

The revised manuscript is [N] words, within the journal's word limit.
We believe the revisions significantly strengthen the paper and address
all reviewer concerns.

Thank you for the opportunity to revise. We look forward to your
decision.

Sincerely,
[Name, Title, Affiliation, Email]
```

**R2 Cover Letter (second revision)**:

```
Dear [Dr. LastName / Editor],

Please find enclosed our second revision of "[Title]" (Manuscript #:
[xxx]).

We thank the Editor and reviewers for their continued engagement with
our work. In this revision, we have addressed all [N] remaining points:

1. [Change 1]
2. [Change 2]

The changes in this round are limited to the specific concerns raised.
A point-by-point response is enclosed.

The manuscript is [N] words. We hope the revised version is now suitable
for publication in [Journal].

Sincerely,
[Name, Title, Affiliation, Email]
```

**R1 Cover Letter (Minor Revision)**:

```
Dear [Dr. LastName / Editor],

Please find enclosed our revised manuscript, "[Title]" (Manuscript #:
[xxx]), addressing the Minor Revision points from [date].

We have made all requested changes, which are detailed in the enclosed
response letter. The key revisions are:

1. [Change 1]
2. [Change 2]

We believe the manuscript is now ready for publication in [Journal].

Sincerely,
[Name, Title, Affiliation, Email]
```

---

## MODE Verification Checklist

After completing the mode, run a verification check via the Task tool; pass this checklist to the verifier:

> "You are verifying a scholar-respond output. Check the following:
>
> 1. Tone matches the R&R round;
> 2. Key changes are listed concisely;
> 3. Manuscript number and editor name included if available;
> 4. Word count stated;
>
> Flag any issues found. Output: [pass/fail] + [list of issues if any]."
