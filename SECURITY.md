# Security Policy

## Supported Versions

Security fixes target the latest version on the default branch.

## Reporting a Vulnerability

Use GitHub private vulnerability reporting if it is enabled for the repository.
Otherwise, open a public issue with a minimal description and avoid posting secrets,
tokens, private hostnames or sensitive hardware identifiers.

This plasmoid is designed to read local kernel sensor files only. It should not
write to `hwmon`, change fan speeds, require root privileges or access the network.
