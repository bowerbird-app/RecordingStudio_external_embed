# Upgrading

This gem requires `recording_studio` 6.1.0 or newer (`>= 6.1.0` in the gemspec), Rails `~> 8.1.0`, and Ruby 3.3 or newer.

The dummy host pins Recording Studio `v6.3.0`, Flatpack `v0.1.341`, Accessible `v0.24.1`, Trashable `v0.12.2`, Cache `v0.6.2`, Root Switchable `v0.11.4`, and Metrics `v0.7.2`. Those tags declare `recording_studio` 6.1 or newer, so the dummy does not rewrite gemspec requirements.

Hosts on an older Recording Studio core need to:

1. Upgrade `recording_studio` to 6.1.0 or newer (6.3.0 matches this dummy).
2. Run `bundle update recording_studio recording_studio_external_embed`.
3. Follow Recording Studio upgrade notes in that gem before expecting this addon to boot.

`RecordingStudio::ExternalEmbed.configuration.layout` defaults to nil. Nil uses the host's `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. Set a layout name, `false`, or a `controller:` callable when this engine should use a different shell.
