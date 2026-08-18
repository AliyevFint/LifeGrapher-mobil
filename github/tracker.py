#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List

DATA_DIR = Path("data")
DATA_FILE = DATA_DIR / "entries.json"


def now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")


def load_entries() -> List[Dict[str, Any]]:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not DATA_FILE.exists():
        DATA_FILE.write_text("[]\n", encoding="utf-8")
        return []
    raw = DATA_FILE.read_text(encoding="utf-8").strip()
    if not raw:
        return []
    return json.loads(raw)


def save_entries(entries: List[Dict[str, Any]]) -> None:
    DATA_FILE.write_text(json.dumps(entries, indent=2) + "\n", encoding="utf-8")


def next_id(entries: List[Dict[str, Any]]) -> int:
    return max((entry["id"] for entry in entries), default=0) + 1


def parse_deadline(value: str) -> str:
    # Accepts YYYY-MM-DD or YYYY-MM-DD HH:MM and stores ISO format.
    value = value.strip()
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            dt = datetime.strptime(value, fmt)
            return dt.isoformat(timespec="minutes")
        except ValueError:
            continue
    raise ValueError("Deadline must be YYYY-MM-DD or YYYY-MM-DD HH:MM")


def get_entry(entries: List[Dict[str, Any]], entry_id: int) -> Dict[str, Any]:
    for entry in entries:
        if entry["id"] == entry_id:
            return entry
    raise ValueError(f"Entry with id={entry_id} not found")


def cmd_add(args: argparse.Namespace) -> None:
    entries = load_entries()
    deadline_iso = parse_deadline(args.deadline)
    ts = now_iso()
    entry = {
        "id": next_id(entries),
        "text": args.text,
        "deadline": deadline_iso,
        "status": "open",
        "created_at": ts,
        "updated_at": ts,
        "events": [
            {
                "type": "created",
                "at": ts,
                "note": args.text,
            }
        ],
    }
    entries.append(entry)
    save_entries(entries)
    print(f"Added entry #{entry['id']} with deadline {deadline_iso}")


def cmd_edit(args: argparse.Namespace) -> None:
    entries = load_entries()
    entry = get_entry(entries, args.id)
    changed_fields: List[str] = []

    if args.text:
        entry["text"] = args.text
        changed_fields.append("text")

    if args.deadline:
        entry["deadline"] = parse_deadline(args.deadline)
        changed_fields.append("deadline")

    if not changed_fields:
        print("No changes provided. Use --text and/or --deadline.")
        return

    ts = now_iso()
    entry["updated_at"] = ts
    entry.setdefault("events", []).append(
        {
            "type": "edited",
            "at": ts,
            "fields": changed_fields,
        }
    )
    save_entries(entries)
    print(f"Updated entry #{entry['id']} ({', '.join(changed_fields)})")


def cmd_done(args: argparse.Namespace) -> None:
    entries = load_entries()
    entry = get_entry(entries, args.id)
    if entry.get("status") == "done":
        print(f"Entry #{entry['id']} is already done")
        return

    ts = now_iso()
    entry["status"] = "done"
    entry["updated_at"] = ts
    entry.setdefault("events", []).append({"type": "done", "at": ts})
    save_entries(entries)
    print(f"Marked entry #{entry['id']} as done")


def deadline_dt(entry: Dict[str, Any]) -> datetime:
    return datetime.fromisoformat(entry["deadline"])


def print_entries(entries: List[Dict[str, Any]]) -> None:
    if not entries:
        print("No entries found")
        return

    entries_sorted = sorted(entries, key=deadline_dt)
    for entry in entries_sorted:
        print(
            f"#{entry['id']} [{entry['status']}] deadline={entry['deadline']} created={entry['created_at']}"
        )
        print(f"  text: {entry['text']}")
        print(f"  updated: {entry['updated_at']}")


def cmd_list(args: argparse.Namespace) -> None:
    entries = load_entries()
    if args.all:
        print_entries(entries)
        return

    open_entries = [entry for entry in entries if entry.get("status") != "done"]
    print_entries(open_entries)


def cmd_due(args: argparse.Namespace) -> None:
    entries = load_entries()
    now = datetime.now()
    horizon = now + timedelta(days=args.days)

    due_entries = [
        entry
        for entry in entries
        if entry.get("status") != "done" and now <= deadline_dt(entry) <= horizon
    ]
    print_entries(due_entries)


def cmd_history(args: argparse.Namespace) -> None:
    entries = load_entries()
    entry = get_entry(entries, args.id)
    print(f"History for entry #{entry['id']}: {entry['text']}")
    for event in entry.get("events", []):
        if event["type"] == "edited":
            print(f"- {event['at']}: edited fields={', '.join(event.get('fields', []))}")
        elif event["type"] == "created":
            print(f"- {event['at']}: created")
        elif event["type"] == "done":
            print(f"- {event['at']}: marked done")
        else:
            print(f"- {event.get('at', 'unknown time')}: {event['type']}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Track what you wrote and when, with deadlines."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    add_parser = sub.add_parser("add", help="Add a new tracked note/deadline")
    add_parser.add_argument("--text", required=True, help="What you wrote")
    add_parser.add_argument(
        "--deadline", required=True, help="Deadline (YYYY-MM-DD or YYYY-MM-DD HH:MM)"
    )
    add_parser.set_defaults(func=cmd_add)

    edit_parser = sub.add_parser("edit", help="Edit text and/or deadline")
    edit_parser.add_argument("id", type=int, help="Entry id")
    edit_parser.add_argument("--text", help="Updated text")
    edit_parser.add_argument("--deadline", help="Updated deadline")
    edit_parser.set_defaults(func=cmd_edit)

    done_parser = sub.add_parser("done", help="Mark an entry as done")
    done_parser.add_argument("id", type=int, help="Entry id")
    done_parser.set_defaults(func=cmd_done)

    list_parser = sub.add_parser("list", help="List open entries")
    list_parser.add_argument("--all", action="store_true", help="Include done entries")
    list_parser.set_defaults(func=cmd_list)

    due_parser = sub.add_parser("due", help="Show open entries due in N days")
    due_parser.add_argument("--days", type=int, default=7, help="Horizon in days")
    due_parser.set_defaults(func=cmd_due)

    hist_parser = sub.add_parser("history", help="Show edit timeline for one entry")
    hist_parser.add_argument("id", type=int, help="Entry id")
    hist_parser.set_defaults(func=cmd_history)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
