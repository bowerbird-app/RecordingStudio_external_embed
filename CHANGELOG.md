# Changelog

## Unreleased

## 0.3.0

- Recognize Vimeo watch, player, and unlisted URLs. The player iframe is built from the video id and, for unlisted videos, the hash. Metadata comes from Vimeo's free oEmbed endpoint.
- Cache successful oEmbed lookups in `Rails.cache` for 12 hours, keyed by provider and canonical URL. Failed lookups are not cached.
- Allow one `{hash}` placeholder, a clause `canonical:` template, and `hash_param:` on a path match.
- When oEmbed returns positive integer `width` and `height`, use them as the frame aspect ratio.
- Pin the dummy kit to Recording Studio `v6.10.0`, Flatpack `v0.1.366`, Accessible `v0.37.0`, Trashable `v0.14.1`, Cache `v0.6.3`, Root Switchable `v0.15.0`, and Metrics `v0.8.0`.
- Copy Recording Studio 6.10's `root_recording_id` events migration into the dummy so event rows keep a root.

## 0.2.2

- Pin the dummy kit to Recording Studio `v6.3.0`, Flatpack `v0.1.341`, Accessible `v0.24.1`, Trashable `v0.12.2`, Cache `v0.6.2`, Root Switchable `v0.11.4`, and Metrics `v0.7.2`.
- Bump Rack to 3.2.8 or newer in both lockfiles (GHSA-2j8w-xcrc-x985, GHSA-5v64-555j-wjxm, GHSA-p8x9-v4hv-2w4g, GHSA-wvg4-6p58-3gh3).
- Drop leftover `UPDATE_SUMMARY.md` and `MIGRATION_NOTES.md`. Hosts keep `UPGRADING.md`.
- Stop asserting a leftover credentials key in the gem credentials test.
- Drop the dummy Bundler widen helper now that sibling tags accept Recording Studio 6.
- Point dummy Root Switchable `config.layout` at the core Default Layout instead of the old `:application_layout` symbol.

## 0.2.1

- Ignore generated SimpleCov output under `coverage/` and `test/dummy/coverage/`.
- Replace leftover gem_template wording in Copilot and agent instructions.
- Record the missing 0.1.2–0.1.7 changelog entries and add `UPGRADING.md` for the Recording Studio 6.1 floor.

## 0.2.0

- Require `recording_studio` 6.1.0 or newer.
- Add `configuration.layout`. Nil uses the host layout, then `recording_studio/default_layout`.
- Dummy screens set the page heading with `content_for` and the back link with `flat_pack_page_nav`.

## 0.1.7

- Pin `recording_studio` to git tag v4.6.0.
- Pin dummy `recording_studio_root_switchable` to v0.9.0 and `recording_studio_accessible` to v0.17.0.

## 0.1.6

- Pin dummy `recording_studio_accessible` to git tag v0.15.0 and install the 0.14.0 host migrations for access constraints and rules.
- Pin `recording_studio` to git tag v4.5.0.
- Pin dummy `recording_studio_root_switchable` to v0.8.0.
- Bump dummy i18n releases of `recording_studio_accessible` and `recording_studio_root_switchable`.

## 0.1.5

- Pin `recording_studio` to git tag v4.4.0.

## 0.1.4

- Pin `recording_studio` to git tag v4.3.0.

## 0.1.3

- Re-key dummy Rails credentials with the shared development master key.
- Write `test/dummy/config/master.key` from `RAILS_MASTER_KEY` in `install.sh`.

## 0.1.2

- Pin `recording_studio` to git tag v4.2.2.

## 0.1.1

- Allow per-clause `embeds_as` overrides on `Provider` path and query matchers.

## 0.1.0

- Resolve an external URL to `RecordingStudio::ExternalEmbed::Embed` or `RecordingStudio::ExternalEmbed::Unresolved`.
- Recognize YouTube watch, youtu.be, Shorts, and embed URLs, and build a `youtube-nocookie` iframe URL from the video id.
- Register another provider with `Provider.define` and `register` without editing the resolver.
- Fetch allowlisted oEmbed metadata and drop provider HTML.
- Render a responsive iframe with `recording_studio_external_embed`.
