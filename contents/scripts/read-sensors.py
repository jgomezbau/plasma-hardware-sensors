#!/usr/bin/env python3

import json
import os
import re
import socket
from pathlib import Path


def path_from_environment(variable: str, default: str) -> Path:
    return Path(os.environ.get(variable, default))


HWMON_ROOT = path_from_environment(
    "PLASMA_HARDWARE_SENSORS_HWMON_ROOT",
    "/sys/class/hwmon"
)
DMI_ROOT = path_from_environment(
    "PLASMA_HARDWARE_SENSORS_DMI_ROOT",
    "/sys/class/dmi/id"
)
CPU_ROOT = path_from_environment(
    "PLASMA_HARDWARE_SENSORS_CPU_ROOT",
    "/sys/devices/system/cpu"
)


def read_text(path: Path, default: str = "") -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return default


def read_integer(path: Path):
    value = read_text(path)

    if not re.fullmatch(r"-?\d+", value):
        return None

    try:
        return int(value)
    except ValueError:
        return None


def valid_temperature(value) -> bool:
    """
    Las temperaturas de hwmon se expresan normalmente
    en milésimas de grado Celsius.
    """
    return (
        isinstance(value, int)
        and 1_000 <= value <= 150_000
    )


def normalize_identifier(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")


def numbered_paths(root: Path, glob_pattern: str, name_pattern: str):
    paths = []

    try:
        for path in root.glob(glob_pattern):
            match = re.fullmatch(name_pattern, path.name)

            if match:
                paths.append((int(match.group(1)), path))
    except OSError:
        return []

    return sorted(paths, key=lambda item: item[0])


def core_number(label: str):
    match = re.search(r"\bcore\s+(\d+)\b", label.lower())

    if match:
        return int(match.group(1))

    return None


def read_cpu_frequency_maps(cpu_root: Path = CPU_ROOT):
    frequencies_by_cpu = {}
    frequencies_by_core = {}

    for cpu_index, cpu in numbered_paths(cpu_root, "cpu[0-9]*", r"cpu(\d+)"):
        frequency = read_integer(cpu / "cpufreq" / "scaling_cur_freq")

        if frequency is None or frequency <= 0:
            frequency = read_integer(cpu / "cpufreq" / "cpuinfo_cur_freq")

        if frequency is None or frequency <= 0:
            continue

        # cpufreq publica la frecuencia en kHz.
        frequency_mhz = round(frequency / 1000)
        frequencies_by_cpu[cpu_index] = frequency_mhz

        core_id = read_integer(cpu / "topology" / "core_id")

        if core_id is not None:
            frequencies_by_core[core_id] = max(
                frequency_mhz,
                frequencies_by_core.get(core_id, 0)
            )

    return frequencies_by_cpu, frequencies_by_core


def read_cpu_frequencies(cpu_root: Path = CPU_ROOT):
    frequencies_by_cpu, _ = read_cpu_frequency_maps(cpu_root)
    return frequencies_by_cpu


def frequency_for_core(
    label: str,
    ordinal: int,
    frequencies_by_cpu,
    frequencies_by_core
):
    number = core_number(label)

    if number is not None:
        if number in frequencies_by_core:
            return frequencies_by_core[number]

        if number in frequencies_by_cpu:
            return frequencies_by_cpu[number]

    return frequencies_by_cpu.get(ordinal)


def classify_temperature(device_name: str, label: str):
    device = device_name.lower()
    sensor_label = label.lower()

    if device == "coretemp":
        if "package" in sensor_label:
            return "cpu", "CPU"
        if "core" in sensor_label:
            return "cpu_core", label

    if device in {"k10temp", "zenpower"}:
        if sensor_label in {"tctl", "tdie", "tccd1", "tccd2"}:
            return "cpu", label

        return "cpu", label or "CPU"

    if device.startswith("cpu_thermal"):
        return "cpu", label or "CPU"

    if device == "thinkpad":
        if sensor_label == "cpu":
            return "system", "ThinkPad"
        if sensor_label == "gpu":
            return "gpu", "GPU"

        return "system_detail", label

    if device == "acpitz":
        return "system", "Sistema"

    if device.startswith("pch"):
        return "chipset", "Chipset"

    if device.startswith("nvme"):
        if sensor_label.lower() == "composite":
            return "storage", "NVMe"

        return "storage_detail", label

    if device.startswith("iwlwifi"):
        return "wifi", "Wi-Fi"

    if device.startswith("amdgpu"):
        if sensor_label in {"edge", "junction", "mem"}:
            return "gpu", "GPU AMD"

        return "gpu", label or "GPU AMD"

    if device.startswith("nouveau"):
        return "gpu", "GPU NVIDIA"

    if "gpu" in device:
        return "gpu", label or "GPU"

    return "temperature", label or device_name


def fan_label(device_name: str, index: int, label: str) -> str:
    device = device_name.lower()

    if label:
        return label

    if device == "thinkpad":
        return "Ventilador CPU"

    if device.startswith(("amdgpu", "nouveau")) or "gpu" in device:
        return "Ventilador GPU"

    return f"Ventilador {index}"


def discover_hwmon(
    hwmon_root: Path = HWMON_ROOT,
    cpu_root: Path = CPU_ROOT
):
    temperatures = []
    fans = []
    cpu_frequencies, cpu_core_frequencies = read_cpu_frequency_maps(cpu_root)
    cpu_core_count = 0

    for _, hwmon in numbered_paths(hwmon_root, "hwmon*", r"hwmon(\d+)"):
        device_name = read_text(hwmon / "name")

        if not device_name:
            continue

        device_identifier = (
            normalize_identifier(device_name)
            or normalize_identifier(hwmon.name)
            or "hwmon"
        )

        # Temperaturas
        for index, input_file in numbered_paths(
            hwmon,
            "temp*_input",
            r"temp(\d+)_input"
        ):
            value = read_integer(input_file)

            if not valid_temperature(value):
                continue

            label = read_text(
                hwmon / f"temp{index}_label",
                f"Sensor {index}"
            )

            category, display_label = classify_temperature(
                device_name,
                label
            )

            critical = read_integer(
                hwmon / f"temp{index}_crit"
            )

            if not valid_temperature(critical):
                critical = None

            sensor = {
                "id": (
                    f"{device_identifier}-temp-{index}"
                ),
                "device": device_name,
                "index": index,
                "category": category,
                "label": display_label,
                "originalLabel": label,
                "value": value,
                "critical": critical
            }

            if category == "cpu_core":
                frequency = frequency_for_core(
                    display_label,
                    cpu_core_count,
                    cpu_frequencies,
                    cpu_core_frequencies
                )

                if frequency is not None:
                    sensor["frequencyMHz"] = frequency

                cpu_core_count += 1

            temperatures.append(sensor)

        # Ventiladores
        for index, input_file in numbered_paths(
            hwmon,
            "fan*_input",
            r"fan(\d+)_input"
        ):
            rpm = read_integer(input_file)

            if rpm is None or rpm < 0:
                continue

            label = read_text(hwmon / f"fan{index}_label")

            fans.append({
                "id": (
                    f"{device_identifier}-fan-{index}"
                ),
                "device": device_name,
                "index": index,
                "label": fan_label(
                    device_name,
                    index,
                    label
                ),
                "rpm": rpm
            })

    return temperatures, fans


def first_temperature(temperatures, category):
    for sensor in temperatures:
        if sensor["category"] == category:
            return sensor["value"]

    return None


def temperature_from_device(
    temperatures,
    device_name,
    original_label=None
):
    for sensor in temperatures:
        if sensor["device"] != device_name:
            continue

        if (
            original_label is not None
            and sensor["originalLabel"] != original_label
        ):
            continue

        return sensor["value"]

    return None


def cpu_cores(temperatures):
    cores = []

    for sensor in temperatures:
        if sensor["category"] != "cpu_core":
            continue

        cores.append(sensor["value"])

    return cores


def get_model(dmi_root: Path = DMI_ROOT):
    candidates = [
        dmi_root / "product_version",
        dmi_root / "product_name"
    ]

    invalid_values = {
        "",
        "none",
        "default string",
        "system product name"
    }

    for candidate in candidates:
        value = read_text(candidate)

        if value.lower() not in invalid_values:
            return value

    return socket.gethostname() or "Equipo"


def collect_sensor_data(
    hwmon_root: Path = HWMON_ROOT,
    dmi_root: Path = DMI_ROOT,
    cpu_root: Path = CPU_ROOT
):
    temperatures, fans = discover_hwmon(hwmon_root, cpu_root)
    cores = cpu_cores(temperatures)

    hostname = socket.gethostname() or "Equipo"
    model = get_model(dmi_root)

    cpu = first_temperature(temperatures, "cpu")
    chipset = first_temperature(temperatures, "chipset")
    nvme = first_temperature(temperatures, "storage")
    wifi = first_temperature(temperatures, "wifi")
    acpi = temperature_from_device(
        temperatures,
        "acpitz"
    )
    thinkpad = temperature_from_device(
        temperatures,
        "thinkpad",
        "CPU"
    )

    fan_rpm = (
        fans[0]["rpm"]
        if fans
        else None
    )

    # Los campos planos mantienen compatibilidad con main.qml.
    # temperatures y fans permitirán construir la interfaz universal.
    return {
        "hostname": hostname,
        "model": model,

        "cpu": cpu,
        "core0": cores[0] if len(cores) > 0 else None,
        "core1": cores[1] if len(cores) > 1 else None,
        "core2": cores[2] if len(cores) > 2 else None,
        "core3": cores[3] if len(cores) > 3 else None,

        "thinkpad": thinkpad,
        "acpi": acpi,
        "chipset": chipset,
        "nvme": nvme,
        "wifi": wifi,
        "fan": fan_rpm,

        "temperatures": temperatures,
        "fans": fans
    }


def main():
    result = collect_sensor_data()

    print(
        json.dumps(
            result,
            ensure_ascii=False,
            separators=(",", ":")
        )
    )


if __name__ == "__main__":
    main()
