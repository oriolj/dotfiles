# Browser keyboard layer

For a vim-style keyboard-driven browsing workflow, install Vimium on a
fresh machine:

- Firefox: [Vimium](https://addons.mozilla.org/en-US/firefox/addon/vimium-ff/)
- Chromium / Chrome: [Vimium](https://chromewebstore.google.com/detail/vimium/dbepggeogbaibhgnhhndojpepiihcmeb)

Project home: <https://github.com/philc/vimium>

## Why no config is tracked here

Vimium settings (custom keybindings, exclusion list, search engines,
etc.) live inside each browser's IndexedDB, keyed by a per-install
extension UUID. They aren't a flat file we can mirror with rsync.

The Vimium options page has a **Backup and Restore** section that
exports the full settings as JSON — use that to move bindings between
browsers, profiles, or machines.
