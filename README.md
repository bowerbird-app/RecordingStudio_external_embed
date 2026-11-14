# Recording Studio External Embed

`RecordingStudio::ExternalEmbed` turns an external URL into one embed value and one iframe. A Recording Studio page can render that iframe without knowing which provider recognized the URL.

`RecordingStudioEmbeddable` makes Recording Studio content embeddable on other sites. This gem does the other direction. It resolves and renders externally hosted content inside Recording Studio applications.

The gem does not store embeds or download media. It does not call the YouTube Data API or a paid Vimeo API. Title, author, and thumbnail come from a provider's free oEmbed endpoint when that provider declares one.

## Install the gem

Add the gem to the host application and install the mount.

```ruby
gem "recording_studio_external_embed", github: "bowerbird-app/RecordingStudio_external_embed"
```

```bash
bundle install
bin/rails generate recording_studio_external_embed:install
```

The generator mounts `RecordingStudio::ExternalEmbed::Engine` at `/recording_studio_external_embed` and writes `config/initializers/recording_studio_external_embed.rb`. Pass `--mount-path /embeds` to choose another prefix.

The gem requires Ruby 3.3 or newer, Rails 8.1, and `recording_studio` 6.1 or newer.

## Resolve a URL

```ruby
embed = RecordingStudio::ExternalEmbed.resolve(
  "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
)

embed.supported?     # true
embed.provider       # :youtube
embed.content_type   # :video
embed.external_id    # "dQw4w9WgXcQ"
embed.embed_url      # "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"
embed.aspect_ratio   # (16/9)
```

`resolve` returns `RecordingStudio::ExternalEmbed::Embed` when a provider recognizes the URL. The embed carries `source_url`, `canonical_url`, `provider`, `provider_label`, `content_type`, `external_id`, `title`, `description`, `author_name`, `author_url`, `thumbnail_url`, `embed_url`, `width`, `height`, and `aspect_ratio`. A provider leaves a field nil when it has no value for that field. YouTube leaves `title`, `description`, `author_name`, `author_url`, and `thumbnail_url` nil because playback does not need a network call. Vimeo fills title, author, and thumbnail from oEmbed when that call succeeds.

## Render an embed

In a view, pass the embed or the original URL.

```erb
<%= recording_studio_external_embed(embed) %>
<%= recording_studio_external_embed("https://youtu.be/dQw4w9WgXcQ") %>
```

The helper emits one responsive wrapper and one iframe. The iframe `src` is `embed_url`. The wrapper uses the embed aspect ratio. The iframe loads lazily, allows fullscreen, and does not set a sandbox. An unsupported value renders an empty string, so the parent page still renders.

## Recognize a YouTube URL

YouTube and Vimeo are the built-in providers. These YouTube URL shapes resolve to the same video id and the same embed URL.

- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtube.com/watch?v=VIDEO_ID`
- `https://m.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- `https://www.youtu.be/VIDEO_ID`
- `https://www.youtube.com/shorts/VIDEO_ID`
- `https://www.youtube.com/embed/VIDEO_ID`

`http` and `https` both work. A trailing dot on the host is ignored. Extra query parameters such as `t` and `list` are ignored. A video id is 11 characters from `A-Z`, `a-z`, `0-9`, `_`, and `-`.

Watch, youtu.be, and embed URLs use a 16 by 9 frame. Shorts use a 9 by 16 frame. Both content types are `:video`.

The embed URL is always `https://www.youtube-nocookie.com/embed/VIDEO_ID`. The canonical URL is always `https://www.youtube.com/watch?v=VIDEO_ID`.

## Recognize a Vimeo URL

These Vimeo URL shapes resolve to a player iframe. Hosts are matched exactly, the same way YouTube hosts are matched.

- `https://vimeo.com/VIDEO_ID`
- `https://www.vimeo.com/VIDEO_ID`
- `https://vimeo.com/VIDEO_ID/HASH` (unlisted)
- `https://player.vimeo.com/video/VIDEO_ID`
- `https://player.vimeo.com/video/VIDEO_ID?h=HASH` (unlisted)

`http` and `https` both work. A trailing dot on the host is ignored. Extra query parameters are ignored, except `h` on a player URL, which is the unlisted hash. A video id is 1 to 64 digits. A hash is 1 to 64 letters or digits. `vimeo.com.evil.example` is not Vimeo. `vimeo.com/video/VIDEO_ID` is not a recognized shape.

The content type is `:video`. The frame starts at 16 by 9. When oEmbed returns both `width` and `height`, the aspect ratio is taken from those integers. The iframe is still sized from a long edge of 560. The oEmbed pixel size is not copied onto the iframe.

The embed URL is `https://player.vimeo.com/video/VIDEO_ID`, plus `?h=HASH` when the pasted URL included a hash. The canonical URL is `https://vimeo.com/VIDEO_ID`, or `https://vimeo.com/VIDEO_ID/HASH` for an unlisted video. oEmbed is requested with that canonical URL, which is what Vimeo needs for unlisted videos. The iframe `src` is always the embed URL. oEmbed `html` is discarded.

Metadata comes from `https://vimeo.com/api/oembed.json`. No API key is required. A thumbnail is kept only when its host is `i.vimeocdn.com`.

## See how a URL is resolved

`RecordingStudio::ExternalEmbed.resolve` parses the URL, looks up the host, and asks that provider to build an embed.

1. The parser accepts only `http` and `https`. It rejects blanks, userinfo, an explicit port, and any other scheme.
2. The host is matched exactly. `youtube.com.evil.example` is not YouTube.
3. The matching provider extracts an id with its own path or query rule.
4. The provider fills `embed_url` and `canonical_url` from templates that contain that id.
5. If the provider declared an oEmbed endpoint, the gateway asks that endpoint for title, author, thumbnail, width, and height. YouTube does not declare one. Vimeo does.

A host with no provider returns an unsupported result. A known host with a missing or illegal id returns a malformed result. The result has no `embed_url` method, so a caller cannot render a half-built iframe.

## Use oEmbed for metadata

oEmbed is a provider option, not a second public API. Declare it when you define a provider.

```ruby
oembed endpoint: "https://oembed.example.test/oembed", thumbnail_hosts: ["img.example.test"]
```

The endpoint must be `https` on a public DNS name, with no userinfo and no explicit port. The gateway resolves that name and refuses the request when any answer is loopback, private, link-local, or otherwise non-public. It connects to the checked address, follows no redirects, and stops at the configured byte limit. `open_timeout` defaults to 1 second. `read_timeout` defaults to 2 seconds. `max_bytes` defaults to 65536.

The request sends the canonical URL, not the pasted URL, and asks for JSON. The gateway copies `title`, `author_name`, `author_url`, `thumbnail_url`, `width`, and `height`. It deletes `html`. A thumbnail is kept only when its host is in `thumbnail_hosts`. When both `width` and `height` are positive integers, they replace the clause's aspect ratio. The iframe is still built from `embed_url` and sized from that ratio. A failed response still returns the embed, with the metadata fields nil and the clause aspect ratio unchanged.

Successful lookups are cached. The cache key is the provider and the canonical URL. The store is `config.cache` when set, otherwise `Rails.cache`. `config.cache_ttl` defaults to 12 hours. Failed lookups are not cached, so the next resolve tries again. `open_timeout` stays 1 second. `read_timeout` stays 2 seconds. `max_bytes` stays 65536.

YouTube does not use this path. Its iframe URL is built from the video id alone. Vimeo does use it.

## Add a provider

Define a provider and register it from a host initializer. Do this before Rails finishes booting. The engine freezes the catalog in `after_initialize`.

```ruby
provider = RecordingStudio::ExternalEmbed::Provider.define(:clip) do
  host "clips.test"
  label "Clip"
  embed_host "play.clips.test"
  embeds_as "https://play.clips.test/e/{id}"
  canonical "https://clips.test/v/{id}"
  match content_type: :video, aspect: Rational(16, 9) do
    path %r{\A/v/(?<id>[a-z0-9]{8})\z}
  end
end

RecordingStudio::ExternalEmbed.register(provider)
```

`embeds_as` and `canonical` must be `https` URLs with exactly one `{id}` placeholder. Each template host must be one of the `host` or `embed_host` names. A path pattern must be anchored and must capture `id`. Query rules take an anchored path and an anchored value pattern.

A template may also contain one `{hash}` when that clause captures a hash. A path pattern may capture `hash`. A path may require a query hash with `hash_param:` and an anchored `hash_pattern:`. A clause may override `canonical:` the same way it overrides `embeds_as:`. The hash is substituted only when it matches the id charset (`A-Z`, `a-z`, `0-9`, `_`, `-`, 1 to 64 characters), so it cannot change the host or add another query. A template that contains `{hash}` is rejected unless that clause captures a hash, and a clause that captures a hash must use templates that contain one `{hash}`. An invalid hash on a URL that presented one is malformed. It is not treated as the same video without the hash.

`register` raises `RecordingStudio::ExternalEmbed::Conflict` when the key or a host is already taken, and when the catalog is already frozen. Tests can pass a temporary catalog to `with_providers` without editing the built-in YouTube provider. `replace: true` drops the built-in catalog for the duration of the block.

Timeouts can be set in the same initializer. `http` and `resolver` are test seams and are ignored when configuration is loaded from YAML.

```ruby
RecordingStudio::ExternalEmbed.configure do |config|
  config.open_timeout = 1
  config.read_timeout = 2
  config.max_bytes = 65_536
  config.cache_ttl = 12.hours
end
```

`config.cache` sets the oEmbed cache store. Leave it nil to use `Rails.cache`. `cache` is ignored when configuration is loaded from YAML, same as `http` and `resolver`. `cache_ttl` is loaded from YAML.

`config.layout` accepts a layout name, `false`, or a callable invoked as `call(controller:)`. `nil` uses `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. Engine controllers read that setting through `recording_studio_layout`.

## Treat every URL as untrusted

The parser rejects `javascript:`, `data:`, and `file:` URLs. It also rejects userinfo and an explicit port, including port 443.

A provider cannot point `embed_url` at a host it did not declare. The iframe `src` is that constructed URL, escaped, and never a string of HTML from the visitor or from oEmbed. Titles are escaped. Remote HTML is not marked safe.

A lookalike host such as `youtube.com.evil.example` or `vimeo.com.evil.example` does not match a built-in provider. A malformed video id or hash does not produce an embed URL.

## Handle an unsupported URL

`supported?` and `valid?` are false for every failure. `errors` contains one static message. `reason` is `:invalid`, `:unsupported`, or `:malformed`.

| Reason | When |
| --- | --- |
| `:invalid` | The input is blank, too long, not a URL, or not `http` or `https`. |
| `:unsupported` | The host is not in the catalog. |
| `:malformed` | The host is known and the id is missing or illegal. |

```ruby
result = RecordingStudio::ExternalEmbed.resolve("https://example.com/watch?v=abc")
result.supported?  # false
result.reason      # :unsupported
result.errors      # ["That URL is not from a supported provider."]
```

`recording_studio_external_embed` renders nothing for that result.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.
