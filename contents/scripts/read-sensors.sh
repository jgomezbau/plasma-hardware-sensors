#!/usr/bin/env bash

# Salida numérica y textual predecible.
export LC_ALL=C

# Localiza un dispositivo hwmon por su nombre exacto.
find_hwmon() {
    local requested_name="$1"
    local hwmon
    local actual_name

    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -r "$hwmon/name" ]] || continue
        actual_name=$(<"$hwmon/name")

        if [[ "$actual_name" == "$requested_name" ]]; then
            printf '%s' "$hwmon"
            return 0
        fi
    done

    return 1
}

# Localiza un dispositivo cuyo nombre comienza con un prefijo.
# Se utiliza para sensores como iwlwifi_1, cuyo número puede cambiar.
find_hwmon_prefix() {
    local requested_prefix="$1"
    local hwmon
    local actual_name

    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -r "$hwmon/name" ]] || continue
        actual_name=$(<"$hwmon/name")

        if [[ "$actual_name" == "$requested_prefix"* ]]; then
            printf '%s' "$hwmon"
            return 0
        fi
    done

    return 1
}

# Lee un valor numérico.
# Devuelve null si el archivo no existe, no puede leerse
# o no contiene un número entero.
read_number() {
    local file="$1"
    local value

    if [[ -r "$file" ]] &&
       value=$(<"$file") &&
       [[ "$value" =~ ^-?[0-9]+$ ]]; then
        printf '%s' "$value"
    else
        printf 'null'
    fi
}

# Busca una temperatura por la etiqueta publicada en hwmon.
read_temperature_by_label() {
    local hwmon="$1"
    local requested_label="$2"
    local label_file
    local input_file

    if [[ -n "$hwmon" ]]; then
        for label_file in "$hwmon"/temp*_label; do
            [[ -r "$label_file" ]] || continue

            if [[ "$(<"$label_file")" == "$requested_label" ]]; then
                input_file="${label_file%_label}_input"
                read_number "$input_file"
                return
            fi
        done
    fi

    printf 'null'
}

# Escapa texto para poder incluirlo de forma segura en JSON.
json_escape() {
    local value="$1"

    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}

    printf '%s' "$value"
}

# Obtiene el hostname configurado en el sistema.
hostname_value=$(hostname 2>/dev/null)

if [[ -z "$hostname_value" ]]; then
    hostname_value="Equipo"
fi

# Obtiene el modelo real publicado por DMI.
model_value=""

if [[ -r /sys/class/dmi/id/product_version ]]; then
    model_value=$(</sys/class/dmi/id/product_version)
fi

# Algunos equipos no informan product_version correctamente.
if [[ -z "$model_value" ||
      "$model_value" == "None" ||
      "$model_value" == "Default string" ]]; then

    if [[ -r /sys/class/dmi/id/product_name ]]; then
        model_value=$(</sys/class/dmi/id/product_name)
    fi
fi

# Último recurso: utilizar el hostname.
if [[ -z "$model_value" ||
      "$model_value" == "None" ||
      "$model_value" == "Default string" ]]; then
    model_value="$hostname_value"
fi

# Localización dinámica de dispositivos hwmon.
coretemp=$(find_hwmon "coretemp")
thinkpad=$(find_hwmon "thinkpad")
nvme=$(find_hwmon "nvme")
chipset=$(find_hwmon "pch_cannonlake")
wifi=$(find_hwmon_prefix "iwlwifi")
acpitz=$(find_hwmon "acpitz")

# Procesador.
cpu=$(read_temperature_by_label "$coretemp" "Package id 0")
core0=$(read_temperature_by_label "$coretemp" "Core 0")
core1=$(read_temperature_by_label "$coretemp" "Core 1")
core2=$(read_temperature_by_label "$coretemp" "Core 2")
core3=$(read_temperature_by_label "$coretemp" "Core 3")

# Almacenamiento.
nvme_temperature=$(read_temperature_by_label "$nvme" "Composite")

# ThinkPad y otros componentes.
thinkpad_temperature=$(read_number "$thinkpad/temp1_input")
fan_rpm=$(read_number "$thinkpad/fan1_input")
chipset_temperature=$(read_number "$chipset/temp1_input")
wifi_temperature=$(read_number "$wifi/temp1_input")
acpi_temperature=$(read_number "$acpitz/temp1_input")

# Generación de una única línea JSON.
printf '{'
printf '"hostname":"%s",' "$(json_escape "$hostname_value")"
printf '"model":"%s",' "$(json_escape "$model_value")"
printf '"cpu":%s,' "$cpu"
printf '"core0":%s,' "$core0"
printf '"core1":%s,' "$core1"
printf '"core2":%s,' "$core2"
printf '"core3":%s,' "$core3"
printf '"thinkpad":%s,' "$thinkpad_temperature"
printf '"acpi":%s,' "$acpi_temperature"
printf '"chipset":%s,' "$chipset_temperature"
printf '"nvme":%s,' "$nvme_temperature"
printf '"wifi":%s,' "$wifi_temperature"
printf '"fan":%s' "$fan_rpm"
printf '}\n'