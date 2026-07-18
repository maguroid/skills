# macOS Tailscale OSS client

Use this procedure when the Mac must be a **Tailscale SSH server**. The Standalone and
Mac App Store variants can be SSH clients but cannot be Tailscale SSH servers.

## Ownership boundary

- Sync only the two mise Go-backend declarations in `~/.config/mise/config.toml`.
- Keep `/Library/Tailscale`, the LaunchDaemon registration, and Tailnet authentication
  machine-local. Never copy them from another Mac.
- Run the daemon from the root-owned copy at `/usr/local/bin/tailscaled`, not directly
  from the user-writable mise install tree.
- Do not keep the mise-managed OSS client alongside `/Applications/Tailscale.app` or a
  second OSS installation from the Homebrew `tailscale` formula.

## First setup on each Mac

After `chezmoi apply` has installed both mise tools:

```sh
sudo "$(mise which tailscaled)" install-system-daemon
sudo "$(mise which tailscale)" up --ssh
```

Complete the browser login for that Mac, then verify:

```sh
tailscale status
tailscale debug prefs | grep 'RunSSH'
launchctl print system/com.tailscale.tailscaled
```

The upstream installer copies `tailscaled` to `/usr/local/bin` and creates
`/Library/LaunchDaemons/com.tailscale.tailscaled.plist`. This keeps the root daemon
separate from mise's user-owned version directory.

## Update

Keep the `tailscale` and `tailscaled` module versions identical. After changing both
mise declarations and running `mise install`, refresh the root-owned copy:

```sh
sudo "$(mise which tailscaled)" install-system-daemon
```

Run doctor and confirm that the system copy matches mise and SSH remains enabled.
`go install` builds can report `ERR-BuildInfo` in `tailscale version`; the module version
in mise remains the version source of truth.

## Repair findings

- **System daemon missing or stale**: rerun `install-system-daemon` from `mise which`.
- **Logged out or SSH disabled**: rerun `sudo "$(mise which tailscale)" up --ssh` and
  authenticate this Mac; do not import `/Library/Tailscale` from another device.
- **Homebrew formula present**: stop its root service before removing it. If
  `sudo brew services start tailscale` previously changed Homebrew paths to root
  ownership, restore only the paths named in Homebrew's warning before uninstalling.
  Resolve the installed version and exact paths at repair time; do not use a broad
  recursive target.
- **Standalone/App Store app present**: decide which mode is required and keep only one.
  For a Tailscale SSH server, retain the OSS client.
- **Aqua backend selected**: remove it. On macOS,
  `aqua:tailscale/tailscale` resolves to the Standalone `.pkg` and does not provide the
  separate `tailscaled` binary. Use the two Go module declarations instead.

## Removal

Remove the native daemon before removing the mise binaries:

```sh
sudo /usr/local/bin/tailscaled uninstall-system-daemon
```

Then remove both Tailscale entries from the mise config. Treat Tailnet device deletion
and local state deletion as separate destructive actions; do not infer them from a tool
uninstall request.
