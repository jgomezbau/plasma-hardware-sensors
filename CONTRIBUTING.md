# Contributing

Thanks for helping improve Plasma Hardware Sensors.

## Local Setup

Runtime dependencies are intentionally small:

- KDE Plasma 6 with Plasma 5 support for the executable data engine.
- Python 3.
- Bash.
- Linux sensors exposed through `/sys/class/hwmon`.

Development checks additionally use `pytest` and `zip`.

## Workflow

Run the complete local validation before opening a pull request:

```bash
./scripts/validate.sh
```

Build a local plasmoid package with:

```bash
./scripts/package.sh
```

Try the widget without installing it:

```bash
plasmoidviewer -a .
```

## Hardware Reports

Hardware support depends on what the kernel publishes through `hwmon`. Useful reports include:

- Distribution and KDE Plasma version.
- Hardware model.
- Output of `sensors`.
- Output of `./contents/scripts/read-sensors.sh | python3 -m json.tool`.
- Screenshot when the issue is visual.

Review outputs before sharing them because they can include hostname or device model.
