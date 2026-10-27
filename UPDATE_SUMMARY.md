# Recording Studio kit pin

Current host-kit floor for this gem.

- Gemspec: `add_dependency "recording_studio", ">= 6.1.0"`
- GitHub tag: Recording Studio `v6.1.0`
- Dummy GitHub tags: Accessible `v0.18.0`, Trashable `v0.11.0` (`require: false`), Root Switchable `v0.9.0`, Cache `v0.5.0`, Metrics `v0.2.0`
- Flatpack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`)
- Sibling gems on those tags still require `recording_studio` below 5. The dummy bundle loads `test/support/widen_recording_studio_requirement.rb` so Bundler can resolve 6.1.0.
- Authenticated dummy screens call `recording_studio_layout`. The shell keeps the sidebar and reads `flat_pack_page_nav` plus `content_for :title`.
- Hooks and BaseService come from core. Do not copy them into this gem.
- Recordable declarations remain required.
