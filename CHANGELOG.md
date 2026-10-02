# Changelog

## 0.1.0

- Resolve an external URL to `RecordingStudio::ExternalEmbed::Embed` or `RecordingStudio::ExternalEmbed::Unresolved`.
- Recognize YouTube watch, youtu.be, Shorts, and embed URLs, and build a `youtube-nocookie` iframe URL from the video id.
- Register another provider with `Provider.define` and `register` without editing the resolver.
- Fetch allowlisted oEmbed metadata and drop provider HTML.
- Render a responsive iframe with `recording_studio_external_embed`.
