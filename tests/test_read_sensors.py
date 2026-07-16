import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path


MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "contents"
    / "scripts"
    / "read-sensors.py"
)


def load_module():
    spec = importlib.util.spec_from_file_location("read_sensors", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sensors = load_module()


def write_text(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(str(value), encoding="utf-8")


def test_collect_sensor_data_normalizes_hwmon_cpu_and_fan(tmp_path):
    hwmon_root = tmp_path / "hwmon"
    dmi_root = tmp_path / "dmi"
    cpu_root = tmp_path / "cpu"

    write_text(hwmon_root / "hwmon0" / "name", "coretemp")
    write_text(hwmon_root / "hwmon0" / "temp1_label", "Package id 0")
    write_text(hwmon_root / "hwmon0" / "temp1_input", "65000")
    write_text(hwmon_root / "hwmon0" / "temp1_crit", "100000")
    write_text(hwmon_root / "hwmon0" / "temp2_label", "Core 0")
    write_text(hwmon_root / "hwmon0" / "temp2_input", "61000")
    write_text(hwmon_root / "hwmon0" / "temp2_crit", "100000")
    write_text(hwmon_root / "hwmon0" / "fan1_input", "2400")

    write_text(cpu_root / "cpu0" / "cpufreq" / "scaling_cur_freq", "2800000")
    write_text(cpu_root / "cpu0" / "topology" / "core_id", "0")
    write_text(cpu_root / "cpu1" / "cpufreq" / "scaling_cur_freq", "3200000")
    write_text(cpu_root / "cpu1" / "topology" / "core_id", "0")

    write_text(dmi_root / "product_version", "ThinkPad T490s")

    result = sensors.collect_sensor_data(hwmon_root, dmi_root, cpu_root)

    assert result["model"] == "ThinkPad T490s"
    assert result["cpu"] == 65000
    assert result["core0"] == 61000
    assert result["fan"] == 2400
    assert result["temperatures"][0]["id"] == "coretemp-temp-1"
    assert result["temperatures"][1]["category"] == "cpu_core"
    assert result["temperatures"][1]["frequencyMHz"] == 3200
    assert result["fans"][0]["label"] == "Ventilador 1"


def test_discovers_numbered_sensors_in_numeric_order(tmp_path):
    hwmon_root = tmp_path / "hwmon"

    write_text(hwmon_root / "hwmon10" / "name", "nvme")
    write_text(hwmon_root / "hwmon10" / "temp10_label", "Sensor 10")
    write_text(hwmon_root / "hwmon10" / "temp10_input", "50000")
    write_text(hwmon_root / "hwmon10" / "temp2_label", "Composite")
    write_text(hwmon_root / "hwmon10" / "temp2_input", "45000")

    temperatures, fans = sensors.discover_hwmon(hwmon_root, tmp_path / "cpu")

    assert fans == []
    assert [sensor["index"] for sensor in temperatures] == [2, 10]
    assert temperatures[0]["category"] == "storage"
    assert temperatures[1]["category"] == "storage_detail"


def test_invalid_sensor_values_are_ignored(tmp_path):
    hwmon_root = tmp_path / "hwmon"

    write_text(hwmon_root / "hwmon0" / "name", "acpitz")
    write_text(hwmon_root / "hwmon0" / "temp1_input", "999")
    write_text(hwmon_root / "hwmon0" / "temp2_input", "not-a-number")
    write_text(hwmon_root / "hwmon0" / "fan1_input", "-1")

    temperatures, fans = sensors.discover_hwmon(hwmon_root, tmp_path / "cpu")

    assert temperatures == []
    assert fans == []


def test_cpu_frequency_falls_back_to_cpuinfo_when_scaling_is_invalid(tmp_path):
    cpu_root = tmp_path / "cpu"

    write_text(cpu_root / "cpu2" / "cpufreq" / "scaling_cur_freq", "0")
    write_text(cpu_root / "cpu2" / "cpufreq" / "cpuinfo_cur_freq", "1800000")
    write_text(cpu_root / "cpu2" / "topology" / "core_id", "2")

    by_cpu, by_core = sensors.read_cpu_frequency_maps(cpu_root)

    assert by_cpu[2] == 1800
    assert by_core[2] == 1800


def test_main_honors_environment_roots(tmp_path):
    hwmon_root = tmp_path / "hwmon"
    dmi_root = tmp_path / "dmi"
    cpu_root = tmp_path / "cpu"

    write_text(hwmon_root / "hwmon0" / "name", "k10temp")
    write_text(hwmon_root / "hwmon0" / "temp1_label", "Tctl")
    write_text(hwmon_root / "hwmon0" / "temp1_input", "72000")
    write_text(dmi_root / "product_name", "Test Machine")

    environment = os.environ.copy()
    environment.update({
        "PLASMA_HARDWARE_SENSORS_HWMON_ROOT": str(hwmon_root),
        "PLASMA_HARDWARE_SENSORS_DMI_ROOT": str(dmi_root),
        "PLASMA_HARDWARE_SENSORS_CPU_ROOT": str(cpu_root),
    })

    completed = subprocess.run(
        [sys.executable, str(MODULE_PATH)],
        check=True,
        capture_output=True,
        env=environment,
        text=True,
    )

    result = json.loads(completed.stdout)

    assert result["model"] == "Test Machine"
    assert result["cpu"] == 72000
    assert result["temperatures"][0]["label"] == "Tctl"
