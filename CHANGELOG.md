# Changelog

## 0.2.1

- Ignore generated SimpleCov output under `coverage/` and `test/dummy/coverage/`.
- Replace leftover gem_template wording in Copilot and agent instructions, and look up dummy credentials under `recording_studio_external_embed`.
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
