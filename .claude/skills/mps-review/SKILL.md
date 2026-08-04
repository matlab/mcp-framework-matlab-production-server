---
name: mps-review
description: Run a code review and publish it to the reviews branch for the review-gate CI check
argument-hint: <PR number>
allowed-tools: Read Write Bash(git *) Bash(grep *) Bash(mkdir *) Bash(rm *) Bash(cat *) Skill(review)
---

# Code Review and Publish to Reviews Branch

You are helping the user run a code review on the current branch and publish the results to the `reviews` branch so the review-gate CI check can pass.

## Step 1: Determine the PR Number

If the user provided a PR number as an argument, use that.

Otherwise, derive it from the current branch:

```bash
git log --oneline main..HEAD
```

Then find the associated PR by checking if the current branch tracks a remote and looking for its PR number. Use:

```bash
git branch --show-current
```

The PR number may be embedded in the branch name (e.g., `feature/PR-21-description`) or you may need to ask the user. If you cannot determine the PR number, ask the user to provide it.

## Step 2: Run the Code Review

Invoke the built-in `/review` skill to review the current branch against `main`. This will produce a comprehensive code review.

Capture the full review output. It will become the content of the review file.

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

Use a git worktree to push the review file to the `reviews` branch without switching the user's current branch:

```bash
# Create a temporary worktree for the reviews branch
git worktree add /tmp/reviews-wt reviews

# Ensure the reviews directory exists in the worktree
mkdir -p /tmp/reviews-wt/reviews

# Copy the review file into the worktree
cp reviews/PR-<N>.md /tmp/reviews-wt/reviews/

# Commit and push from the worktree
cd /tmp/reviews-wt
git add reviews/PR-<N>.md
git commit -m "Review for PR #<N>"
git push origin reviews
cd -

# Clean up the worktree
git worktree remove /tmp/reviews-wt
```

If the worktree creation fails because `/tmp/reviews-wt` already exists, remove it first:
```bash
git worktree remove /tmp/reviews-wt 2>/dev/null || rm -rf /tmp/reviews-wt
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
- If the review skill produces no output, report the failure and stop
