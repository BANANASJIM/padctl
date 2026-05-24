# Release Process

padctl releases are driven by annotated `v*.*.*` tags. The tag version must match
`build.zig.zon`; the release workflow checks this before building artifacts.

## Checklist

1. Update `build.zig.zon` to the new version and merge that change to `main`.
2. Create an annotated tag on the exact `main` commit to release:

   ```sh
   git fetch origin main --tags
   git tag -a v0.1.9 origin/main -m "v0.1.9"
   git push origin v0.1.9
   ```

3. Watch the **Release** workflow. The successful run should include:

   - musl tarballs for `x86_64-linux-musl` and `aarch64-linux-musl`
   - versioned `.deb` packages and latest aliases
   - `SHA256SUMS.txt`
   - `verify-release-artifact`
   - `update-aur`

   The AUR update job copies `contrib/aur/padctl-bin/PKGBUILD` into the AUR
   checkout before setting the version and hashes, so packaging layout fixes must
   be made in the repository template first.

4. Verify the GitHub release after the workflow completes:

   ```sh
   gh release view v0.1.9 --json isDraft,isPrerelease,assets
   ```

5. If a release upload step runs inside a container, every `gh release` command
   must pass `--repo BANANASJIM/padctl`. The container checkout may not provide
   enough git metadata for `gh` to infer the repository.

6. Do not rerun an old failed tag workflow after merging release workflow fixes.
   Move or recreate the annotated tag so the new workflow run executes at the
   fixed commit.
