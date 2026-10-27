# Changelog

## 0.2.0

- Require `recording_studio` 6.1.0 or newer.
- Add `configuration.layout`. Nil uses the host layout, then `recording_studio/default_layout`.
- Dummy screens set the page heading with `content_for` and the back link with `flat_pack_page_nav`.

## 0.1.1

- Allow per-clause `embeds_as` overrides on `Provider` path and query matchers.

## 0.1.0

- Resolve an external URL to `RecordingStudio::ExternalEmbed::Embed` or `RecordingStudio::ExternalEmbed::Unresolved`.
- Recognize YouTube watch, youtu.be, Shorts, and embed URLs, and build a `youtube-nocookie` iframe URL from the video id.
- Register another provider with `Provider.define` and `register` without editing the resolver.
- Fetch allowlisted oEmbed metadata and drop provider HTML.
- Render a responsive iframe with `recording_studio_external_embed`.
