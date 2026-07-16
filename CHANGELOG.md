# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-07-16

### Added

- CPU core frequency output in the backend and MHz display in the expanded CPU view when Linux exposes `cpufreq` data.
- Per-reading information buttons with generic `hwmon` details for CPU, visible temperature sensors and fans.
- Pytest coverage for hwmon discovery, invalid sensor filtering, numeric sysfs ordering and environment-configurable roots.
- `scripts/validate.sh` as the single local validation entrypoint.
- `scripts/package.sh` for reproducible `.plasmoid` package generation with a SHA-256 checksum.
- GitHub Actions CI for validation and packaging.
- Contribution and security documentation.
- GPL-3.0 license text.

### Changed

- Backend discovery now accepts configurable `hwmon`, DMI and CPU sysfs roots for tests and diagnostics.
- Numbered hwmon, temperature, fan and CPU entries are sorted numerically instead of lexicographically.
- README now documents the current repository name, validation workflow, packaging flow and test setup.

### Fixed

- QML status badge transparency now uses color objects consistently.
- The QML executable command now shell-quotes and URL-decodes the backend script path.
- The history graph repaints when its line color changes.
- Fan icons now react to zero or unavailable RPM values.
- System temperature rows now use hardware-oriented Breeze icons instead of a settings icon.

### Security

- The plasmoid script path is now single-quoted before being passed to the executable data engine.
