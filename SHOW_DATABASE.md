# Showing Users and Login Activity in the Viva

`supermart.db` is a binary SQLite file. Do not open it as text; the red
`NUL` characters are raw binary pages, not corruption.

## Fastest safe demonstration

From a terminal:

```powershell
cd D:\ML\Project\api
python show_database.py
```

The script opens the database in read-only mode and displays:

1. Registered users without the password-hash column.
2. Recent successful and failed authentication attempts.
3. Recent orders joined to customer names.

## Visual demonstration in the app

Sign in as a manager and open **AI Insights → Authentication activity**.
This calls the protected endpoint:

```text
GET /manager/login-activity
Authorization: Bearer <manager JWT>
```

A customer token receives HTTP 403 for that endpoint.

## Visual database browser in VS Code

1. Install a trusted SQLite viewer extension from VS Code Extensions.
2. Close the text tab currently displaying binary data.
3. Right-click `api/instance/supermart.db`.
4. Select the extension's **Open Database** command.
5. Expand `user`, `login_audit`, `order`, and `order_item`.
6. Run:

```sql
SELECT id, name, email, role, branch, created_at
FROM user
ORDER BY id DESC;
```

```sql
SELECT email, role, branch, success, ip_address, created_at
FROM login_audit
ORDER BY created_at DESC;
```

```sql
SELECT o.id, u.name, o.status, o.total_amount, o.created_at
FROM "order" o
JOIN user u ON u.id = o.customer_id
ORDER BY o.created_at DESC;
```

Never display or copy the `password` column during the viva. It contains bcrypt
hashes, not plaintext, but it is still sensitive authentication data.

## What to say

> The user table contains registered accounts. It does not prove who is
> currently online. Login is authenticated using a signed JWT that expires
> after 12 hours. For auditability, every authentication attempt is recorded in
> login_audit with timestamp, result, role, branch and IP address. Passwords and
> JWTs are never written to the audit table.

An audit row means a login attempt occurred. It does not guarantee the browser
is still open. A true real-time “currently online” feature would need
server-managed sessions or short-lived presence heartbeats and logout/revocation
tracking.
