# Publishing a new smusic version

Everything is automatic. You change one number, push, and GitHub builds and
publishes the APK.

## Every release, step by step

1. **Raise the version** in `pubspec.yaml`:

   ```yaml
   version: 1.3.0+4
   ```

   - `1.3.0` is the version people see (also tag `v1.3.0` and the release name).
   - `+4` is Android's build number. It **must be higher than the last one**, or
     Android refuses to install the new APK over the old one.

2. **(Optional) Update the version text** in *Settings > About*
   (`lib/ui/settings_page.dart`, the line `smusic 1.2.0`) and add a note to
   `CHANGELOG.md`.

3. **Commit and push to `main`.**

   ```bash
   git add .
   git commit -m "Release 1.3.0"
   git push
   ```

4. Open the **Actions** tab. The run called *Build smusic APK* takes 5 to 10
   minutes. When it is green, the **Releases** page has the new version.

5. Share this link. It always gives the newest APK and never changes:

   `https://github.com/Snehal-Modi/smusic/releases/latest/download/smusic.apk`

## What you never have to touch

- The README download button and links. They point at *latest*.
- The signing key. It is created on the first build and reused, so every update
  installs over the previous one and keeps playlists, likes and downloads.
  **Never delete `android/app/smusic.jks`**: with a new key Android treats the app
  as a different one and people must uninstall first.

## Troubleshooting

| What you see | Cause and fix |
| --- | --- |
| Red X on the run | Open it, open the red step, read the error. The analyzer step fails only on real errors, not warnings. |
| "App not installed" on the phone | The build number (`+N`) was not raised, or an APK signed with another key is installed. Raise `+N`; uninstall the old app once if the key changed. |
| Release shows the old APK | The version name is unchanged. Pushing again updates that release's APK; raise the version to get a new release. |
| No release created, only the build | The run was started by hand (*Run workflow*). Releases are only created for pushes. |
| Push rejected after a build | The first build commits the keystore back. Run `git pull`, then push again. |
| Download link gives 404 | The repo is private or there is no release yet. Make the repo public (Settings > General > Danger Zone > Change visibility). |

## Where things come from

- Release name, tag and APK name come from the `version:` line.
- `smusic.apk` is the same file under a fixed name, made for the README link.
- Release notes are generated from the commits since the previous release.
- The whole recipe is `.github/workflows/build.yml`.
