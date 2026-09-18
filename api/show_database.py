"""Safe, read-only viva view of important local SQLite records."""

import sqlite3
from pathlib import Path

DATABASE = Path(__file__).parent / "instance" / "supermart.db"


def print_rows(title, query):
    print(f"\n{'=' * 80}\n{title}\n{'=' * 80}")
    cursor = connection.execute(query)
    columns = [description[0] for description in cursor.description]
    print(" | ".join(columns))
    print("-" * 80)
    for row in cursor.fetchall():
        print(" | ".join("" if value is None else str(value) for value in row))


if not DATABASE.exists():
    raise SystemExit(f"Database not found: {DATABASE}")

uri = f"file:{DATABASE.as_posix()}?mode=ro"
with sqlite3.connect(uri, uri=True) as connection:
    print(f"READ-ONLY DATABASE: {DATABASE}")
    print_rows(
        "REGISTERED USERS (password deliberately excluded)",
        """
        SELECT id, name, email, role, branch, phone, address, created_at
        FROM user ORDER BY id DESC LIMIT 30
        """,
    )
    print_rows(
        "RECENT LOGIN AUDIT",
        """
        SELECT id, user_id, email, role, branch, success, ip_address, created_at
        FROM login_audit ORDER BY created_at DESC LIMIT 30
        """,
    )
    print_rows(
        "RECENT ORDERS",
        """
        SELECT o.id, u.name AS customer, o.branch, o.order_type, o.status,
               o.total_amount, o.delivery_address, o.created_at
        FROM "order" AS o
        JOIN user AS u ON u.id = o.customer_id
        ORDER BY o.created_at DESC LIMIT 30
        """,
    )
