---
description: Investigate PostgreSQL connection errors in Rails apps
---

# Investigate PostgreSQL Connection Issues

You are investigating why Rails cannot connect to PostgreSQL. Follow these steps systematically to diagnose and fix the issue.

## Step 1: Check Rails Logs First

Read the Rails development log to understand the specific error:

```bash
tail -100 log/development.log
```

Look for:
- `ActiveRecord::ConnectionNotEstablished`
- `PG::ConnectionBad`
- `connection to server ... failed: Connection refused`
- Host and port information in error messages

Note the specific error message - it will guide your investigation.

## Step 2: Detect PostgreSQL Installation Method

Run these commands to determine how PostgreSQL is installed:

```bash
# Check Homebrew (most common on macOS)
brew services list 2>/dev/null | grep -i postgres

# Check Postgres.app
ls -la /Applications/Postgres.app 2>/dev/null && echo "Postgres.app detected"

# Check Docker
docker ps 2>/dev/null | grep -i postgres

# Check system postgres
which postgres pg_config 2>/dev/null

# Check if postgres is running at all
pgrep -l postgres
```

Based on output, proceed to the relevant section below.

## Step 3: Diagnose Based on Installation Type

### If Homebrew (most common)

```bash
# Check service status
brew services list | grep postgres

# Check which version
ls /opt/homebrew/var/ 2>/dev/null | grep postgres
ls /usr/local/var/ 2>/dev/null | grep postgres

# Check logs (adjust version number as needed)
tail -50 /opt/homebrew/var/log/postgresql@15.log 2>/dev/null || \
tail -50 /opt/homebrew/var/log/postgresql@14.log 2>/dev/null || \
tail -50 /usr/local/var/log/postgresql@15.log 2>/dev/null || \
tail -50 /usr/local/var/log/postgresql@14.log 2>/dev/null
```

**Common Homebrew issues:**

1. **Stale PID file** (look for "lock file postmaster.pid already exists"):
   ```bash
   # Find data directory
   PGDATA=$(brew info postgresql@15 2>/dev/null | grep -o '/opt/homebrew/var/postgresql@[0-9]*' | head -1)
   # Or for Intel Macs
   PGDATA=$(brew info postgresql@15 2>/dev/null | grep -o '/usr/local/var/postgresql@[0-9]*' | head -1)

   # Check if PID in lock file is actually postgres
   cat "$PGDATA/postmaster.pid" 2>/dev/null

   # If PID is stale (not postgres), remove and restart:
   rm "$PGDATA/postmaster.pid"
   brew services restart postgresql@15  # adjust version
   ```

2. **Service not started**:
   ```bash
   brew services start postgresql@15  # adjust version
   ```

3. **Wrong version running**:
   ```bash
   brew services stop postgresql@14
   brew services start postgresql@15
   ```

### If Postgres.app

1. Check if the app is running (elephant icon in menu bar)
2. Open Postgres.app and check the server status
3. Click "Start" if server is stopped
4. Check the app's logs via the app interface

### If Docker

```bash
# Check if container is running
docker ps | grep postgres

# If not running, check stopped containers
docker ps -a | grep postgres

# Start if stopped
docker start <container_name>

# Check logs
docker logs <container_name> --tail 50
```

### If System PostgreSQL (Linux)

```bash
# Check status
systemctl status postgresql
# or
service postgresql status

# Check logs
journalctl -u postgresql --tail 50
# or
tail -50 /var/log/postgresql/postgresql-*-main.log

# Start if not running
sudo systemctl start postgresql
```

## Step 4: Check Common Issues

### Port Conflict (5432 already in use)

```bash
# Check what's using port 5432
lsof -i :5432
```

If another process is using the port, either stop it or configure Rails to use a different port.

### Socket File Issues

```bash
# Check for socket file
ls -la /tmp/.s.PGSQL.5432 2>/dev/null
ls -la /var/run/postgresql/.s.PGSQL.5432 2>/dev/null
```

### Permission Issues

```bash
# Check data directory permissions
ls -la /opt/homebrew/var/postgresql@15/ 2>/dev/null
```

### Database Configuration Mismatch

```bash
# Check Rails database config
cat config/database.yml | head -30

# Verify the host/port/socket matches what postgres is listening on
```

## Step 5: Verify the Fix

After applying a fix, verify Rails can connect:

```bash
bin/rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"
```

If successful, you should see output like `{"?column?"=>1}`.

## Quick Reference: Common Fixes

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| "lock file postmaster.pid already exists" | Stale PID from crash | Remove postmaster.pid, restart |
| "Connection refused" | PostgreSQL not running | Start the service |
| "could not connect to server: No such file or directory" | Socket file missing | Start PostgreSQL or check socket path |
| Service shows "error" status | Check logs | Read PostgreSQL logs for details |
| Wrong version | Multiple PG versions | Stop old, start correct version |

## Summary Format

After investigation, report:
1. **Error found**: (from Rails logs)
2. **Installation type**: (Homebrew/Postgres.app/Docker/System)
3. **Root cause**: (what you found in PG logs)
4. **Fix applied**: (what you did)
5. **Verification**: (Rails runner output)
