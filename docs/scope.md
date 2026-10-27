# Scope and ground rules

This repo is about **how the ad systems of these apps work on the client**, and modifying your
own copy of the app to change that behaviour - the same thing ReVanced does for YouTube.

In scope:

- Reading and documenting the apps' ad code.
- Patches that change client-side decisions: whether an ad UI is shown, whether ad breaks are
  scheduled, whether a seek is forced back to an ad.
- Tooling to reproduce the analysis on new app versions.

Out of scope, and patches doing these won't be accepted:

- **DRM** (Widevine, PlayReady), content keys, or downloading/ripping streams.
- **Account or entitlement tricks**: unlocking a plan you don't pay for (e.g. 4K, more streams,
  offline downloads on an ad tier), sharing accounts, spoofing regions.
- **Redistributing APKs**, patched or not. Share patches and notes; everyone builds their own APK
  from an APK they obtained themselves. `.gitignore` keeps binaries out of git for this reason.
- Anything that attacks the services' servers (fake beacons, request flooding).

Things to know before you use a patched app:

- Modifying these apps is against each service's terms of use. Consequences are on you.
- Re-signed apps can't receive store updates; you re-patch each new version.
- Some ads are **stitched into the video stream on the server** (SSAI). A client patch can skip
  over them or stop the app from tracking them, but cannot remove frames that are part of the
  stream itself. Each analysis notes which kind of ads the app uses and what's actually
  achievable.
