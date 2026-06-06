#!/usr/bin/env python3
"""Render reusable Lume unattended YAMLs for macOS setup recovery."""

from __future__ import annotations

import argparse
from pathlib import Path


def yaml_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(commands: list[str], boot_wait: int = 20) -> str:
    lines = [f"boot_wait: {boot_wait}", "boot_commands:"]
    lines.extend(f"  - {yaml_quote(command)}" for command in commands)
    return "\n".join(lines) + "\n"


def login_commands(password: str, login_wait: int) -> list[str]:
    return [
        "<wait 'Enter Password', timeout=180>",
        "<click 'Enter Password'>",
        "<delay 1>",
        f"<type '{password}'>",
        "<enter>",
        f"<delay {login_wait}>",
    ]


def apple_account_skip_commands() -> list[str]:
    return [
        "<wait 'Sign In to Your Apple Account', timeout=300>",
        "<click 'Other Sign-In Options', xoffset=70>",
        "<delay 1>",
        "<click 'Sign in Later in Settings'>",
        "<delay 2>",
        "<click 'Skip'>",
    ]


def age_range_commands() -> list[str]:
    return [
        "<wait 'Age Range', timeout=300>",
        "<click 'Adult'>",
    ]


def analytics_commands() -> list[str]:
    return [
        "<wait 'Analytics', timeout=300>",
        "<click 'Continue'>",
        "<delay 60>",
    ]


def terminal_open_commands(method: str) -> list[str]:
    if method == "dock":
        return [
            "<click_at 866,728>",
            "<delay 10>",
        ]
    if method == "spotlight-row":
        return [
            "<cmd+space>",
            "<delay 2>",
            "<type 'Terminal'>",
            "<delay 3>",
            "<click_at 330,232>",
            "<delay 10>",
        ]
    if method == "spotlight-open-button":
        return [
            "<cmd+space>",
            "<delay 2>",
            "<type 'Terminal'>",
            "<delay 3>",
            "<click_at 397,128>",
            "<delay 10>",
        ]
    raise ValueError(f"unknown terminal method: {method}")


def write_yaml(path: Path, commands: list[str]) -> None:
    path.write_text(render(commands), encoding="utf-8")


def build_files(out_dir: Path, password: str, login_wait: int, terminal_method: str) -> dict[str, list[str]]:
    login = login_commands(password, login_wait)
    finish_from_apple = login + apple_account_skip_commands() + age_range_commands() + analytics_commands()
    finish_from_age = login + age_range_commands() + analytics_commands()
    finish_from_analytics = login + analytics_commands()

    return {
        "current-screen-probe.yml": login
        + [
            "<delay 150>",
            "<click 'definitely-not-on-screen'>",
        ],
        "finish-from-update.yml": login
        + [
            "<wait 'Update Mac Automatically', timeout=300>",
            "<click 'Only Download Automatically'>",
        ]
        + apple_account_skip_commands()
        + age_range_commands()
        + analytics_commands(),
        "finish-from-apple-account.yml": finish_from_apple,
        "finish-from-age-range.yml": finish_from_age,
        "finish-from-analytics.yml": finish_from_analytics,
        "enable-ssh-launchctl.yml": login
        + terminal_open_commands(terminal_method)
        + [
            "<type 'sudo launchctl enable system/com.openssh.sshd; sudo launchctl kickstart -k system/com.openssh.sshd'>",
            "<enter>",
            "<delay 5>",
            f"<type '{password}'>",
            "<enter>",
            "<delay 15>",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path, help="Directory to write YAML files into")
    parser.add_argument("--name", default="default", help="VM name, printed for convenience only")
    parser.add_argument("--password", default="lume", help="macOS account password")
    parser.add_argument("--login-wait", default=90, type=int, help="Seconds to wait after login")
    parser.add_argument(
        "--terminal-method",
        choices=["dock", "spotlight-row", "spotlight-open-button"],
        default="dock",
        help="How enable-ssh-launchctl.yml should open Terminal",
    )
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    files = build_files(args.out, args.password, args.login_wait, args.terminal_method)
    for filename, commands in files.items():
        write_yaml(args.out / filename, commands)

    print(f"Rendered {len(files)} YAML files for VM '{args.name}' in {args.out}")
    for filename in sorted(files):
        print(args.out / filename)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
