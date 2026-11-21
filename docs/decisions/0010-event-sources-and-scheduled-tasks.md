# 10. One place to watch the system, one to schedule downloads

**Context.** Services watched the system each in their own way: two `nmcli monitor` processes for the network and the VPN, a process every 4 seconds for the camera, timers reading files several times a second, `FileView` watches spread over the code. Processes started by the shell outlived it, because its service keeps child processes across a restart. Downloads on a schedule had their own timers and their own idea of when the network was usable.

**Decision.**

- Every watch of the local system goes through `EventSources` (`shell/base/`): a process that prints events, a watched file, or a poll where nothing reports a change. Each source runs once however many listen, starts with its first listener and stops after its last, ends with the shell and starts again after a failure. Services listen through `EventSubscription`. A change of tool happens in this one file.
- Every download on a schedule goes through `ScheduledTask` (`shell/services/`), which decides when it may run: not while offline unless the task needs no network, on a metered network only when allowed, catching up once the network returns, which also covers waking. The data stays in the service that owns it.
- Files the shell watches are made by their owners when missing, at start or after being deleted, since a watch needs a file.

**Rejected.**

- Reading D-Bus directly, as GNOME and KDE do through their libraries. QML has no general D-Bus access. A Python helper would take about 14 MB of memory against about 1.5 MB for all the current watch processes together; a C++ plugin would save about 1 MB at the cost of compiled code and rebuilds with Qt updates, and could replace only the NetworkManager and UDisks streams.
- Waiting for a missing file by watching its folder: an extra process per missing file, and a deleted folder still ends the watch.
- A central store for downloaded data: each service already knows its data best; only the timing is shared.
