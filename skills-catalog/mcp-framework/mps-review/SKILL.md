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

Format the review with clear sections and bullet points.

## Step 3: Write the Review File

Create the review file locally:

```bash
mkdir -p reviews
```

Write the file `reviews/PR-<N>.md` with this structure:

```markdown
## Claude Code Review

<full review content from Step 2>

## Review Response

<!-- Add your response to the review findings here -->
```

The `## Review Response` section is left as a placeholder for the user to fill in.

## Step 4: Push to the Reviews Branch

Use a git worktree to push the review file to the `reviews` branch without switching the user's current branch. Use `mktemp -d` for the worktree path — this works on both Windows (Git Bash) and Linux, and avoids UNC path issues with mapped drives:

```bash
# Create a temporary directory for the worktree
WT_PATH=$(mktemp -d)

# Create a worktree for the reviews branch
git worktree add "$WT_PATH" reviews

# Ensure the reviews directory exists in the worktree
mkdir -p "$WT_PATH/reviews"

# Copy the review file into the worktree
cp reviews/PR-<N>.md "$WT_PATH/reviews/"

# Commit and push from the worktree
cd "$WT_PATH"
git add reviews/PR-<N>.md
git commit -m "Review for PR #<N>"
git push origin reviews
cd -

# Clean up the worktree
git worktree remove "$WT_PATH" || rm -rf "$WT_PATH"
git worktree prune
```

## Step 5: Inform the User

Tell the user:
1. The review has been published to the `reviews` branch as `reviews/PR-<N>.md`
2. They need to add their response under the `## Review Response` section
3. They can edit the file locally in `reviews/PR-<N>.md` and push again using the same worktree technique, or you can help them do it
4. Once both sections are present, the review-gate CI check will pass

## Error Handling

- If the `reviews` branch does not exist on the remote, tell the user they need to create it first (one-time setup)
- If git push fails due to permissions, tell the user to push manually
- If the diff is empty, tell the user there are no changes to review

--- Copyright 2026 The MathWorks, Inc. ---
