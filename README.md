# LifeGrapher (mobil)

This project is set up so you can track **what changed, where it changed, and when it changed** on GitHub.

## How to See Changes Over Time on GitHub

1. Open the repository on GitHub.
2. Go to **Commits** to see timeline of edits.
3. Open any file and click **History** to see file-by-file changes.
4. Use **Blame** view in a file to see who edited each line and when.
5. Use **Insights -> Code frequency** to view activity over time.

## Good Commit Style (for clear timeline)

- Make small commits for each change.
- Use clear commit messages like:
  - `feat: add daily note input`
  - `fix: correct date format`
  - `docs: update setup guide`

## Useful Local Commands

```bash
git log --oneline --decorate --graph --all
git log --stat
git blame README.md
```
