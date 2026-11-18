# Upgrading

## 0.6.1

This gem still requires `recording_studio` `>= 7.0`, `< 8.0`. Rails stays `~> 8.1.0`. Ruby stays 3.3 or newer.

The dummy host pins Recording Studio `v7.7.1`, Flatpack `v0.1.378`, Accessible `v0.54.0`, Trashable `v1.2.0`, Cache `v0.7.0`, Root Switchable `v0.16.0`, and Metrics `v0.9.1`. Accessible `0.54.0` requires Recording Studio `>= 7.7.0`, `< 8.0`.

Hosts already on Recording Studio 7.0 or newer, below 8, do not need a new migration from this gem. The dummy still omits Recording Studio 7.4's root-type creation index, 7.5's root invariant, and 7.7's root index replacement.

## 0.6.0

This gem requires `recording_studio` `>= 7.0`, `< 8.0`. Rails stays `~> 8.1.0`. Ruby stays 3.3 or newer.

`RecordingStudio.root_recording_for` only finds a root. It returns nil when that recordable has none. A seed, setup task, or request that created a root by looking it up now calls `RecordingStudio.create_root_recording!(recordable)` with an actor. A later call returns the same root and does not append another event.

The dummy host pins Recording Studio `v7.0.0`, Flatpack `v0.1.366`, Accessible `v0.43.1`, Trashable `v0.16.1`, Cache `v0.6.3`, Root Switchable `v0.15.1`, and Metrics `v0.8.0`. Accessible `0.37.0`, Trashable `0.14.1`, and Root Switchable `0.15.0` refuse Recording Studio 7, so those three pins moved. Cache, Metrics, and Flatpack stay on the same tags. The dummy still mounts the same pages, seeds, and tests.

Dummy seeds look up an existing child with `Recording.kept`. Trashable `0.16` removed `recording_studio_trashable_kept_sql`.

The dummy lockfile moves `msgpack` to 1.8.7 (GHSA-73v3-wf97-vpgj). Bootsnap still depends on `msgpack ~> 1.2`.

Hosts on an older Recording Studio core need to:

1. Upgrade `recording_studio` to 7.0.0 or newer, below 8. Core 7 adds no migration for the root split. `recording_studio_events.root_recording_id` is still required. Copy `20261114090000_add_root_recording_id_to_recording_studio_events` from core if that column is missing, then migrate.
2. Run `bundle update recording_studio recording_studio_external_embed`.
3. Replace root creation that called `root_recording_for` with `create_root_recording!`. Leave real lookups on `root_recording_for` and handle nil.
4. Follow the Recording Studio 7 upgrade notes before expecting this addon to boot.

## 0.5.0

YouTube embeds set `thumbnail_url` to `https://i.ytimg.com/vi/VIDEO_ID/hqdefault.jpg`. The URL is built from the video id. Resolve still does not call YouTube. `metadata_status` stays `:none`.

A provider may declare `thumbnail_host` and `thumbnail`. The thumbnail template is an https URL with one `{id}`. Its host must be a `thumbnail_host`. Paste hosts and embed hosts are not thumbnail hosts, and a thumbnail host cannot be the iframe host.

When oEmbed returns a thumbnail, that URL is used. When it does not, the template is used and `metadata_status` is unchanged. A provider with no thumbnail template still leaves `thumbnail_url` nil on a `:fetched` response that omitted one.

## 0.4.0

`Embed#metadata_status` is `:fetched`, `:none`, `:transient_failure`, or `:failed`. `Embed#metadata_retryable?` is true only for `:transient_failure`. Retry a poster or thumbnail job when that predicate is true.

`resolve` still returns the embed when oEmbed fails, and it does not raise. A missing thumbnail on a successful response is `:fetched`, with `thumbnail_url` nil. `:none` means the provider has no oEmbed endpoint, or the JSON object had no title, author, thumbnail, or dimensions.

`:transient_failure` is a timeout, a DNS or connection failure, HTTP 429, or HTTP 5xx. `:failed` is any other HTTP status, an invalid or oversized body, or a refused non-public address.

Only a `:fetched` lookup is cached. A cache hit reports `:fetched`. `:none` and both failure statuses are not cached. Cached entries from 0.3.0 are ignored and fetched again. Open timeout stays 1 second. Read timeout stays 2 seconds. The byte limit stays 65536.

## 0.3.0

Vimeo is a built-in provider. Remove a host registration for `:vimeo`, or for `vimeo.com`, `www.vimeo.com`, or `player.vimeo.com`, before booting. The gem raises `RecordingStudio::ExternalEmbed::Conflict` when those are registered again.

`vimeo.com/VIDEO_ID`, `www.vimeo.com/VIDEO_ID`, `vimeo.com/VIDEO_ID/HASH`, `player.vimeo.com/video/VIDEO_ID`, and `player.vimeo.com/video/VIDEO_ID?h=HASH` are the recognized shapes. `vimeo.com/video/VIDEO_ID` is not.

oEmbed responses are cached in `Rails.cache` for 12 hours, keyed by provider and canonical URL. Set `config.cache` to use another store. Set `config.cache_ttl` to change the lifetime. Failed lookups are not cached. Open timeout stays 1 second. Read timeout stays 2 seconds.

Provider templates may include one `{hash}` placeholder when a match captures a hash. A clause may set `canonical:`. A path match may set `hash_param:` and an anchored `hash_pattern:`.

## Earlier upgrades

Before 0.6.0 this gem required `recording_studio` 6.1.0 or newer (`>= 6.1.0` in the gemspec), Rails `~> 8.1.0`, and Ruby 3.3 or newer.

The 0.5.0 dummy host pinned Recording Studio `v6.10.0`, Flatpack `v0.1.366`, Accessible `v0.37.0`, Trashable `v0.14.1`, Cache `v0.6.3`, Root Switchable `v0.15.0`, and Metrics `v0.8.0`. Those tags declared `recording_studio` 6.1 or newer, so the dummy did not rewrite gemspec requirements.

Hosts moving onto that 6.x line needed to:

1. Upgrade `recording_studio` to 6.1.0 or newer (6.10.0 matched that dummy). Recording Studio 6.9 and newer also need the `root_recording_id` column on `recording_studio_events`. Copy `20261114090000_add_root_recording_id_to_recording_studio_events` from core and migrate.
2. Run `bundle update recording_studio recording_studio_external_embed`.
3. Follow Recording Studio upgrade notes in that gem before expecting this addon to boot.

`RecordingStudio::ExternalEmbed.configuration.layout` defaults to nil. Nil uses the host's `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. Set a layout name, `false`, or a `controller:` callable when this engine should use a different shell.

Recording Studio 6.5 and newer refuses `RecordingStudio.record!` until the host sets `config.authorize_write` and supplies an actor. The dummy initializer allows a write when `Current.actor` is present.

Root Switchable 0.12 and newer refuses the mounted switch page unless the signed-in actor has Recording Studio Accessible `:view` on the current root. The dummy seeds that grant for the admin user.
