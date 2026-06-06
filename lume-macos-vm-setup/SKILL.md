---
name: lume-macos-vm-setup
description: Create, finish, repair, and verify Apple Silicon macOS VMs managed by Lume. Use when Codex needs to download a macOS IPSW into $HOME/.lume, create a Lume macOS VM such as default, recover from fragile unattended Setup Assistant screens, complete post-login Tahoe/macOS 26 setup, enable SSH/Remote Login headlessly, or debug Lume VNC/OCR automation failures.
---

# Lume macOS VM Setup

Use this skill to create a Lume-managed macOS VM and finish the parts that Lume's built-in unattended presets can miss. Prefer reproducible headless `lume setup --no-display --debug` runs, with screenshots used to identify the current Setup Assistant screen.

## Ground Rules

- Use `lume` directly and request host-level approval when the sandbox blocks VM, network, GUI, or `$HOME/.lume` operations.
- Store downloaded IPSWs under `$HOME/.lume`.
- Prefer the instance name `default` when the user will only keep one VM.
- Do not assume `systemsetup -setremotelogin on` will work on recent macOS. It can fail with: `Turning Remote Login on or off requires Full Disk Access privileges.`
- Enable SSH with `launchctl` instead:

```sh
sudo launchctl enable system/com.openssh.sshd
sudo launchctl kickstart -k system/com.openssh.sshd
```

## Initial Checks

Run these before changing state:

```sh
uname -m
sw_vers
lume --version
lume ls --format json
```

If the user suspects an old Lume CLI, check the installed version and package manager version. For Homebrew installs, `brew info lume` is enough. If `lume setup --help` shows built-in presets such as `sequoia` and `tahoe`, the remaining issue is often a changed macOS setup screen, not necessarily an old CLI.

## IPSW Download

Get the current IPSW URL with:

```sh
lume ipsw
```

Download it into `$HOME/.lume`, preserving the URL basename:

```sh
mkdir -p "$HOME/.lume"
curl -L "$(lume ipsw)" -o "$HOME/.lume/<basename-from-url>.ipsw"
```

Use the exact downloaded path in `lume create`.

## Create The VM

Use conservative defaults unless the user specified otherwise:

```sh
lume create default --os macos --ipsw "$HOME/.lume/<downloaded>.ipsw" --cpu 4 --memory 8GB --disk-size 80GB
```

Then try the built-in preset once:

```sh
lume setup default --unattended tahoe --debug --no-display
```

If the built-in preset fails during Apple Account or post-login setup, switch to the recovery workflow below.

## Probe Current Screen

Generate reusable YAMLs with:

```sh
python3 <skill-dir>/scripts/render_lume_yamls.py --out /private/tmp/lume-yamls --name default
```

Use the probe YAML to see the current screen after login:

```sh
lume setup default --unattended /private/tmp/lume-yamls/current-screen-probe.yml --debug --no-display
```

The probe intentionally fails on a nonexistent click so Lume saves a screenshot. Open the final `*-FAILED-*.png` from the debug directory in the command output. Lume usually stops the VM after setup failure; that is expected.

## Finish Post-Login Setup

For macOS 26/Tahoe post-login screens, use the YAML that matches the screenshot:

- `finish-from-update.yml`: screenshot shows `Update Mac Automatically`.
- `finish-from-apple-account.yml`: screenshot shows `Sign In to Your Apple Account`.
- `finish-from-age-range.yml`: screenshot shows `Age Range`.
- `finish-from-analytics.yml`: screenshot shows `Analytics`.

Run the chosen YAML:

```sh
lume setup default --unattended /private/tmp/lume-yamls/finish-from-update.yml --debug --no-display
```

Known screen details:

- On `Update Mac Automatically`, choose `Only Download Automatically` to continue.
- On Apple Account, click `Other Sign-In Options` with a positive x-offset, then `Sign in Later in Settings`, then `Skip`.
- On `Age Range`, choose `Adult`.
- On `Analytics`, click `Continue`; the default unchecked state is acceptable.

When uncertain, rerun `current-screen-probe.yml` rather than guessing.

## Enable SSH Headlessly

After the desktop is reachable, enable SSH with `enable-ssh-launchctl.yml`:

```sh
lume setup default --unattended /private/tmp/lume-yamls/enable-ssh-launchctl.yml --debug --no-display
```

The YAML logs in, opens Terminal, runs `launchctl enable` and `launchctl kickstart` for `com.openssh.sshd`, enters the default password, and exits normally.

If Terminal does not open, inspect a debug screenshot and rerender with a different method:

```sh
python3 <skill-dir>/scripts/render_lume_yamls.py --out /private/tmp/lume-yamls --terminal-method spotlight-row
```

Available methods:

- `dock`: click a Terminal icon in the Dock at a 1024x768 default display; fastest when Terminal is already in the Dock or already running.
- `spotlight-row`: use Spotlight and click the first Terminal result row; preferred fallback for fresh desktops.
- `spotlight-open-button`: use Spotlight and click the Open button; can mis-target on some Lume OCR captures, so verify with screenshots.

## Verify

Start the VM, then confirm both Lume metadata and real SSH:

```sh
lume run default --no-display
lume ls --format json
lume ssh default --timeout 30 -- echo ok
```

Success criteria:

- `lume ls --format json` reports `status: running` and `sshAvailable: true`.
- `lume ssh default --timeout 30 -- echo ok` prints `ok`.

Stop the VM if it was only started for verification:

```sh
lume stop default
```
