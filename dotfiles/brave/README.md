# brave

## `brave-flags.conf`

Mirrors `chromium-flags.conf` — enforces Wayland (`--ozone-platform=wayland`),
the system title bar, and overlay scrollbars. Brave reads this from
`~/.config/brave-flags.conf` automatically; `sync-dotfiles.sh` mirrors
it from the repo on `restore`.

## `policies.json`

Managed-policy file that disables features Brave bundles by default but
that this setup doesn't use:

- **Wallet** (`BraveWalletDisabled`) — crypto wallet integration
- **VPN** (`BraveVPNDisabled`) — paid VPN button + subscription UI
- **Leo AI chat** (`BraveAIChatEnabled: false`) — sidebar + URL-bar AI
- **Rewards** (`BraveRewardsDisabled`) — BAT / ads opt-in system

Brave on Linux reads JSON policies from `/etc/brave/policies/managed/`.
This is the same mechanism enterprise admins use; user-facing toggles
in `brave://settings` cannot re-enable a policy-disabled feature, and
shortcuts/icons are removed from the UI.

## Install

```sh
./install-policies.sh
```

Copies `policies.json` to `/etc/brave/policies/managed/policies.json`
(requires sudo). Idempotent. Restart Brave afterwards and verify at
`brave://policy` — all four entries should show status **OK**.

## Tor

`TorDisabled` is intentionally **not** set — Brave's private-window-with-Tor
mode stays available. Add `"TorDisabled": true` to `policies.json` if
that's not wanted either.

## Keeping in sync

`policies.json` is the source of truth in this repo (the live file at
`/etc/...` is just a copy). Edit `policies.json` here, then re-run
`install-policies.sh` to push to the system.
