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

## Deadline Tracking Program

Use this to record what you wrote, when you wrote it, and deadline dates.

```bash
python3 tracker.py add --text "submit mobile proposal" --deadline "2026-08-21 18:00"
python3 tracker.py list
python3 tracker.py edit 1 --text "submit updated mobile proposal"
python3 tracker.py due --days 7
python3 tracker.py history 1
python3 tracker.py done 1
```

All tracked data is saved in `data/entries.json` with timestamps for create/edit/done events.

## Daily Auto-Commit To GitHub

This creates a daily scheduled commit at 21:00 local time whenever there are changes.

```bash
chmod +x scripts/auto_commit.sh scripts/install_daily_commit.sh
./scripts/install_daily_commit.sh
```

Manual run (any time):

```bash
./scripts/auto_commit.sh
```
