# This fork

`heroic` is a hardened build of [gnzsnz/ib-gateway-docker](https://github.com/gnzsnz/ib-gateway-docker)
for one deployment: the IB Gateway container of the monkeybusiness trading stack. It runs
the Gateway only (no TWS image), and builds from source; nothing is published to a registry.

## What differs from upstream

| Change | Why |
|---|---|
| Runtime stage re-runs `apt-get upgrade`, cache-busted by `ARG APT_REFRESH=<date>` | Upstream's `stable` image was built 2026-10-06 and carried fixable HIGHs in apt and libbrotli1 (CVE-2026-111497, on CISA KEV). A cached builder keeps the old layer until `APT_REFRESH` changes. |
| `build/override-jars.sh` swaps third-party jars IBKR bundles (`build/jar-overrides.txt`) | IB Gateway 10.50/10.51 ship jackson 2.12.3 (11 HIGH), commons-io 2.11.0 (1 HIGH) and log4j 2.25.3 (5 MEDIUM). They move to jackson 2.18.12, commons-io 2.22.0 and log4j 2.25.5, downloaded from Maven Central and checked against pinned sha256. A bundled jar is only replaced when it is older than ours. IBC builds the classpath from `jars/*.jar`, so no launcher changes. |
| No `sudo` (and no passwordless sudoers entry), `ssh`, `sshpass`, `telnet` | Nothing in the start scripts needs them. `SSH_TUNNEL` now stops the container with a message instead of half-working. |
| `HEALTHCHECK` (`scripts/healthcheck.sh`) | Healthy only while the Gateway itself listens on its API port (4001 live / 4002 paper), which it opens after login. socat's 4003/4004 accept connections with nobody logged in behind them, so a lapsed session looked healthy before. Reads `/proc/net/tcp`, does not connect. |
| IBC zip and IB Gateway installer checked against sha256 pinned in this repo (`IBC_SHA256`, `build/installer.sha256`) | Upstream checks the installer against a `.sha256` file from the same release page, and IBC not at all. |
| Upstream workflows replaced by `.github/workflows/build-and-scan.yml` | Build amd64, fail on fixable HIGH/CRITICAL, offline smoke test; weekly on Mondays. No bots, no pushes. |

Known and not fixed here: the JRE IBKR bundles (Java 25.0.2) and the Chromium inside
jxbrowser 8.9.4 are IBKR's; Trivy does not report either.

## Building

```sh
docker build -t ib-gateway:heroic stable/      # what monkeybusiness runs
trivy image --ignore-unfixed --severity HIGH,CRITICAL ib-gateway:heroic
```

Releases are tags `<gateway version>-heroic.<n>`, e.g. `10.50.1f-heroic.1`.

## Following upstream

```sh
git fetch upstream
git merge upstream/master            # conflicts in <channel>/Dockerfile: take ours, then
./update.sh stable <new version>     # regenerates the channel from Dockerfile.template + image-files
```

Then add the new version's two lines to `image-files/build/installer.sha256` (from the
`.sha256` assets on upstream's release page), copy `image-files/build/` into the channel,
and on an IBC bump set `IBC_SHA256` in `Dockerfile.template`. The build fails on a
missing pin; that is on purpose. Check the override list against the new version's
`jars/` (`override-jars.sh` prints what it swaps) and let CI scan it.
