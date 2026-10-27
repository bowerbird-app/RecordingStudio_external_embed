# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 6.1.0 or newer (`>= 6.1.0` in the gemspec; GitHub tag `v6.1.0`)
- Accessible dummy tag `v0.18.0`, Trashable dummy tag `v0.11.0` (`require: false`), Root Switchable dummy tag `v0.9.0`, Cache dummy tag `v0.5.0`, and Metrics dummy tag `v0.2.0`
- Flatpack `0.1.319` (commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56`, gem requirement `>= 0.1.315` via Recording Studio)
- Public RubyGems and GitHub access for dependency installation

Those sibling tags still declare `recording_studio` below 5. `test/support/widen_recording_studio_requirement.rb` rewrites that dependency when Bundler loads their gemspecs. The dummy Gemfile and `test/dummy/config/boot.rb` load it before `Bundler.setup`. A host that has already bumped those gems should not copy the hook.

`RecordingStudio::ExternalEmbed.configuration.layout` defaults to nil. Nil uses the host's `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. Set a layout name, `false`, or a `controller:` callable when this engine should use a different shell. Do not hard-code `layout "recording_studio/default_layout"`.

Page screens set `content_for :title` and `content_for :subtitle`. The layout renders one page heading. Back and close use `flat_pack_page_nav`. Right-side actions use `register_page_nav` or `recording_studio_page_nav_right`.

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.
