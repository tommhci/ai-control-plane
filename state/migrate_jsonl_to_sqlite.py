import argparse
import json
import sqlite3
from pathlib import Path


def load_schema(schema_path: Path) -> str:
    return schema_path.read_text(encoding="utf-8")


def migrate(input_path: Path, db_path: Path, schema_path: Path) -> tuple[int, int]:
    if not input_path.exists():
        raise FileNotFoundError(f"missing input JSONL: {input_path}")

    db_path.parent.mkdir(parents=True, exist_ok=True)
    schema = load_schema(schema_path)

    imported = 0
    skipped = 0

    with sqlite3.connect(db_path) as conn:
        conn.executescript(schema)

        for line_number, line in enumerate(input_path.read_text(encoding="utf-8-sig").splitlines(), start=1):
            stripped = line.strip()
            if not stripped:
                continue

            try:
                event = json.loads(stripped)
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid JSON at line {line_number}: {exc}") from exc

            event_type = event.get("event_type")
            timestamp = event.get("timestamp")
            session_id = event.get("session_id")
            if not event_type or not timestamp or not session_id:
                skipped += 1
                continue

            payload = json.dumps(event, ensure_ascii=False, sort_keys=True)
            conn.execute(
                "INSERT INTO events(session_id, event_type, timestamp, payload_json) VALUES (?, ?, ?, ?)",
                (session_id, event_type, timestamp, payload),
            )
            conn.execute(
                """
                INSERT INTO sessions(session_id, first_seen, last_seen, event_count)
                VALUES (?, ?, ?, 1)
                ON CONFLICT(session_id) DO UPDATE SET
                  first_seen = CASE
                    WHEN excluded.first_seen < sessions.first_seen THEN excluded.first_seen
                    ELSE sessions.first_seen
                  END,
                  last_seen = CASE
                    WHEN excluded.last_seen > sessions.last_seen THEN excluded.last_seen
                    ELSE sessions.last_seen
                  END,
                  event_count = sessions.event_count + 1
                """,
                (session_id, timestamp, timestamp),
            )
            imported += 1

    return imported, skipped


def main() -> int:
    parser = argparse.ArgumentParser(description="Dry-run migrate session JSONL into SQLite.")
    parser.add_argument("--input", required=True, help="Path to session_log.jsonl")
    parser.add_argument("--db", required=True, help="Output SQLite DB path")
    parser.add_argument("--schema", default=str(Path(__file__).with_name("schema.sql")), help="Schema SQL path")
    args = parser.parse_args()

    imported, skipped = migrate(Path(args.input), Path(args.db), Path(args.schema))

    with sqlite3.connect(args.db) as conn:
        sessions = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        events = conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]

    print("state_store_migration: PASS")
    print(f"db={args.db}")
    print(f"imported_events={imported}")
    print(f"skipped_events={skipped}")
    print(f"sessions={sessions}")
    print(f"events={events}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
