#!/usr/bin/env python3
"""Write this plugin's data/state.json the hard way.

Invoked by Service.qml as: python3 safe_write_state.py <path> <content>

Writing straight to a predictable path (what Qt's FileView.setText() does,
even in its own "atomic" mode) means: if something else running as this
user has replaced that path with a symlink, the write has to go somewhere
without ever opening — and therefore without ever following — that
symlink. The only way to guarantee that is to never open the destination
path for writing at all:

  1. tempfile.mkstemp() in the *same directory* as the destination creates
     a brand-new file with a random name, O_CREAT|O_EXCL (so it can't
     collide with or follow anything already there), mode 0600. This is
     the private, exclusive temporary inode the content actually lands in
     first.
  2. Write the content, flush, and fsync it, so the data is durable on
     disk before it's ever linked to the real name.
  3. os.replace() (rename(2) under the hood) atomically swaps the temp
     file into place at `path`. rename() replaces whatever directory entry
     is at the destination — file or symlink — without dereferencing it;
     it never opens or writes through a symlink there. Same-directory
     placement also guarantees the temp file and destination share a
     filesystem, which is what makes the rename atomic in the first place.

Exit code 0 = written. Non-zero = failed; the caller just skips this save
(the in-memory state this plugin is running with is unaffected either way
— this only persists it to disk for next launch).
"""
import os
import sys
import tempfile


def main():
    path, content = sys.argv[1], sys.argv[2]
    directory = os.path.dirname(path) or "."

    fd, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=directory)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(content.encode("utf-8"))
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, path)
        return 0
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        return 1


if __name__ == "__main__":
    sys.exit(main())
