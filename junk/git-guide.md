# Git Guide — dev-1 & dev-2

---

## Step 1 — Create folders and GitHub repos

Create two folders locally:
```bash
mkdir dev-1
mkdir dev-2
```

On GitHub, create two repositories named `dev-1` and `dev-2`.

---

## Step 2 — Set up dev-1

### Navigate into dev-1
```bash
cd dev-1
```

### Add a file
```bash
echo "I have added a file inside dev-1" > dev-1.txt
```

### Initialize git
```bash
git init
```

### Add remote repo
```bash
git remote add origin <repo-url>
```
Replace `<repo-url>` with your GitHub repo URL, e.g.
`https://github.com/your-username/dev-1.git`

### Verify remote
```bash
git remote -v
```
Expected output:
```
origin  https://github.com/your-username/dev-1.git (fetch)
origin  https://github.com/your-username/dev-1.git (push)
```

### Add to staging area
```bash
git add .
```

### Commit
```bash
git commit -m "my 1st commit"
```

### Check commit history
```bash
git log
```

### Push to remote repo
```bash
git push -u origin main
```
> If your default branch is `master`, use `master` instead of `main`.

---

## Step 3 — Create a new branch in dev-1

### Create and switch to new branch
```bash
git checkout -b new-fetcher
```

### Make changes
```bash
echo "I have created new branch named new-fetcher" >> dev-1.txt
```

### Stage, commit and push
```bash
git add .
git commit -m "changes in new-fetcher branch"
git push -u origin new-fetcher
```

---

## Step 4 — Repeat for dev-2

```bash
cd ../dev-2

echo "I have added a file inside dev-2" > dev-2.txt

git init
git remote add origin <dev-2-repo-url>
git remote -v

git add .
git commit -m "my 1st commit"
git log
git push -u origin main

git checkout -b new-fetcher
echo "I have created new branch named new-fetcher" >> dev-2.txt
git add .
git commit -m "changes in new-fetcher branch"
git push -u origin new-fetcher
```

---

## Step 5 — Raise a Pull Request (PR)

### On GitHub (UI)

1. Go to your repo on GitHub (e.g. `github.com/your-username/dev-1`)
2. Click the **"Compare & pull request"** button that appears after pushing a branch
3. Set:
   - **base**: `main` (the branch you want to merge INTO)
   - **compare**: `new-fetcher` (the branch with your changes)
4. Add a title and description explaining what changed and why
5. Click **"Create pull request"**
6. Reviewers can comment, request changes, or approve
7. Once approved, click **"Merge pull request"**

---

## Step 6 — Merge branch via CLI and push to main

```bash
# Switch to main branch
git checkout main

# Pull latest changes from remote main
git pull origin main

# Merge new-fetcher into main
git merge new-fetcher

# Push merged main to remote
git push origin main
```

---

## Step 7 — Rolling back commits

### If you have NOT pushed yet

Go back to previous commit but KEEP the changes (changes stay in working directory):
```bash
git reset --soft HEAD~1
```

Go back to previous commit and DELETE the changes (careful — changes are gone):
```bash
git reset --hard HEAD~1
```

---

### If you HAVE already pushed

Since the changes are already on the remote, you need to force the rollback:
```bash
git reset --hard HEAD~1
git push --force
```
> Warning: this rewrites history. Don't use on shared/main branches if others have pulled.

---

### If you want to keep history of the rollback (safest for shared branches)

This creates a new commit that undoes the previous one — history is preserved:
```bash
git revert HEAD
git push
```

---

## Step 8 — Un-staging files (after git add)

Un-stage everything:
```bash
git reset HEAD
```

Un-stage only Python files:
```bash
git reset HEAD -- *.py
```

Un-stage a specific file:
```bash
git reset HEAD -- filename.txt
```

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `git init` | Initialize a new local repo |
| `git remote add origin <url>` | Link local repo to GitHub |
| `git remote -v` | Verify remote URL |
| `git add .` | Stage all changes |
| `git commit -m "msg"` | Commit staged changes |
| `git log` | View commit history |
| `git push -u origin <branch>` | Push branch to remote |
| `git checkout -b <branch>` | Create and switch to new branch |
| `git merge <branch>` | Merge branch into current branch |
| `git reset --soft HEAD~1` | Undo last commit, keep changes |
| `git reset --hard HEAD~1` | Undo last commit, delete changes |
| `git revert HEAD` | Create new commit that undoes last commit |
| `git reset HEAD` | Un-stage all staged files |
