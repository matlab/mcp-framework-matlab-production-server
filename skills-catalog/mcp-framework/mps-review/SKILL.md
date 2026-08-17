---
name: mps-review
description: Run a code review and publish it to the reviews branch for the review-gate CI check
argument-hint: <PR number>
allowed-tools: Read Write Bash(git *) Bash(grep *) Bash(mkdir *) Bash(rm *) Bash(cat *)
---

# Code Review and Publish to Reviews Branch

You are helping the user run a code review on the current branch and publish the results to the `reviews` branch so the review-gate CI check can pass.

## Step 1: Determine the PR Number

If the user provided a PR number as an argument, use that.

Otherwise, derive it from the current branch:

```bash
git branch --show-current
```

The PR number may be embedded in the branch name (e.g., `feature/PR-21-description`) or you may need to ask the user. If you cannot determine the PR number, ask the user to provide it.

## Step 2: Run the Code Review

Review the current branch's changes against `main` directly. Do NOT use `gh` or the `/review` skill — they are unavailable in this environment.

First, determine the review scope:

```bash
git log --oneline main..HEAD
```

**Scope rules:**
- If there are **10 or fewer commits**, review the full diff: `git diff main..HEAD`
- If there are **more than 10 commits**, ask the user which commits to review, or default to the most recent 5: `git diff HEAD~5..HEAD`
- If the user specified a commit range, use that

Then perform a thorough code review of the diff, covering:
- Code correctness and potential bugs
- Following project conventions
- Performance implications
- Test coverage
- Security considerations

**Test coverage expectation:** If the diff introduces new public functions (new `.m` files outside of `Test/` and `+test/` directories), check whether corresponding tests are also included. If new public functions are added without new or modified test files, flag this in the review as a finding:
- List each new public function that lacks test coverage in the diff
- State clearly that the author must explain in their Review Response why tests are not included (acceptable reasons: covered by existing tests, test PR planned separately, internal helper not directly testable)
- This is NOT an automatic rejection — it is a required explanation. The review-gate will pass once the author provides their response.

**Automatic rejection rule:** If any new MATLAB code (`.m` files) contains Java calls (e.g., `java.util.*`, `java.lang.*`, `javaObject`, `javaMethod`, or any `java.` reference), the verdict MUST be **Reject**. Java must never appear in new MATLAB code. Flag every occurrence and state clearly in the verdict that the PR cannot be approved until all Java usage is removed.

Format the review with clear sections and bullet points.

## Step 3: Write the Review File

Create the review file locally:

```bash
mkdir -p reviews
```

The file is `reviews/PR-<N>.md`. It may already exist from a previous review run. Check the remote reviews branch for an existing file:

```bash
git show origin/reviews:reviews/PR-<N>.md 2>/dev/null
```

If this command outputs content, the file exists — use the re-review flow below. If it errors (file not found), this is the first review.

### If the file does NOT exist (first review)

Write it with this structure:

```markdown
## Claude Code Review — <YYYY-MM-DDTHH:MM>

<full review content from Step 2>

## Review Response

<!-- Add your response to the review findings here -->
```

### If the file ALREADY exists (re-review)

The file contains one or more prior review runs. Restructure it as follows:

1. Insert the new review at the **top** of the file with a dated header: `## Claude Code Review — <YYYY-MM-DDTHH:MM>`
2. Below the new review, add a fresh `## Review Response` placeholder
3. Below that, add a `---` separator
4. Below the separator, keep ALL prior content (previous reviews and their responses) intact

The resulting structure looks like:

```markdown
## Claude Code Review — 2026-08-17T15:00

<latest review content>

## Review Response

<!-- Add your response to the review findings here -->

---

## Claude Code Review — 2026-08-17T14:00

<previous review content>

## Review Response

<user's previous response, if filled in>
```

The CI review-gate checks only the **topmost** `## Review Response` section. Prior reviews serve as history.

## Step 4: Push to the Reviews Branch

This repo may be on a CIFS/SMB network share where git's atomic ref-file renames fail. Do NOT use `git worktree` or `git commit` to update the reviews branch — they will fail with `couldn't set 'refs/branches/reviews'`. Instead, use git plumbing commands to build a commit and push it directly:

```bash
# Fetch the latest reviews branch state
git fetch origin reviews

# Get the current reviews branch HEAD
REVIEWS_HEAD=$(git rev-parse origin/reviews)

# Hash the review file as a git blob
BLOB=$(git hash-object -w reviews/PR-<N>.md)

# Build the reviews/ subtree: existing entries + new/updated file
SUBTREE=$( (git ls-tree "$REVIEWS_HEAD:reviews" | grep -v "PR-<N>.md"; echo "100644 blob $BLOB	PR-<N>.md") | git mktree )

# Build the root tree: existing root entries with updated reviews subtree
ROOT_TREE=$( (git ls-tree "$REVIEWS_HEAD" | grep -v "^.*	reviews$"; echo "040000 tree $SUBTREE	reviews") | git mktree )

# Create a commit object
COMMIT=$(git commit-tree "$ROOT_TREE" -p "$REVIEWS_HEAD" -m "Review for PR #<N>")

# Push to remote (ignore harmless local tracking ref update error)
git push origin "$COMMIT:refs/heads/reviews" 2>&1 | grep -v "update_ref failed" || true
```

**Important:** The `grep -v` at the end suppresses the CIFS error `update_ref failed for ref 'refs/remotes/origin/reviews'`. This error means the local tracking ref could not be updated, but the push itself succeeded — the remote has the correct commit.

## Step 5: Inform the User

Tell the user:
1. The review has been published to the `reviews` branch as `reviews/PR-<N>.md`
2. If this is a re-review, mention that the previous review(s) are preserved below a `---` separator
3. They need to add their response under the topmost `## Review Response` section
4. The response must contain substantive text — the placeholder comment alone (`<!-- Add your response ... -->`) or a blank section will NOT pass the gate
5. They can edit the file locally in `reviews/PR-<N>.md` and push again using the same plumbing technique, or you can help them do it
6. Once the topmost review has a substantive response, the review-gate CI check will pass

## Error Handling

- If the `reviews` branch does not exist on the remote, tell the user they need to create it first (one-time setup)
- If `git push` reports `update_ref failed for ref 'refs/remotes/origin/reviews'` but the push line shows the remote accepted it (e.g., `3b02741..3d01904 ... -> reviews`), the push succeeded. This is a harmless CIFS/SMB artifact.
- If the push is rejected (non-fast-forward), re-fetch `origin/reviews` and rebuild the commit on top of the new HEAD.
- If git push fails due to permissions, tell the user to push manually
- If the diff is empty, tell the user there are no changes to review

--- Copyright 2026 The MathWorks, Inc. ---
