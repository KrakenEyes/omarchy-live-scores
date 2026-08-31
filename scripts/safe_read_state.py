#!/usr/bin/env python3
"""Read this plugin's data/state.json the hard way.

Invoked by Service.qml as: python3 safe_read_state.py <path> <max-bytes>

data/state.json lives at a predictable, plugin-writable path. Anything else
running as this user can replace it with a FIFO, an oversized regular file,
or a symlink before this runs. A plain open()+read() (what Qt's FileView
does when it preloads a file) follows symlinks, has no size cap, and can
block indefinitely trying to open a FIFO for reading. So this does the
three things a plain open() can't:

  1. O_NOFOLLOW: refuse to open if the final path component is a symlink,
     instead of silently following it to whatever it points at.
  2. O_NONBLOCK: never block trying to open a FIFO with no writer.
  3. fstat the *already-open descriptor* to require a regular file under
     the byte cap before reading a single byte, and re-check the running
     total while reading in case the file grows mid-read. Checking the fd
     (not the path) means nothing can be swapped in between the open and
     the read/checks below — there is no second path lookup to race.

Exit codes: 0 = content written to stdout. 2 = no file at that path (a
normal, non-hostile "nothing followed yet" state — the caller treats this
the same as an empty file). 1 = rejected (not a regular file, too large,
symlink, or any other OSError) — the caller treats this as "unreadable",
never as "empty and therefore safe to overwrite in-memory state with".
"""
import os
import stat
import sys


def main():
    path, cap = sys.argv[1], int(sys.argv[2])

    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError:
        return 2
    except OSError:
        return 1  # symlink (ELOOP), permission denied, etc.

    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_size > cap:
            return 1

        chunks = []
        total = 0
        while True:
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            total += len(chunk)
            if total > cap:
                return 1
            chunks.append(chunk)

        sys.stdout.buffer.write(b"".join(chunks))
        return 0
    finally:
        os.close(fd)


if __name__ == "__main__":
    sys.exit(main())
