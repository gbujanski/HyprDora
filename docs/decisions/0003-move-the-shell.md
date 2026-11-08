# 3. Move the shell instead of rewriting it

**Context.** The installer is written from scratch. The shell already exists as a separate prototype and carries fixes found by testing on real hardware.

**Decision.** The shell is moved in logical commits, with cleanup: new name, English, settings outside the code.

**Rejected.** Rewriting the shell: it would lose those fixes and rediscover the same problems.
