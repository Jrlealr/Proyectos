#!/usr/bin/env python3
"""Genera assets/ley/utm.json con el valor UTM del mes desde la API de
mindicador.cl (que publica los valores del SII / Banco Central).

Uso: utm.py <mindicador_utm.json> <salida.json>
"""
import json
import sys


def main():
    entrada, salida = sys.argv[1], sys.argv[2]
    with open(entrada, encoding="utf-8") as f:
        serie = json.load(f)["serie"]
    ultimo = max(serie, key=lambda x: x["fecha"])
    valor = int(round(float(ultimo["valor"])))
    if not 50_000 <= valor <= 200_000:
        sys.exit(f"Valor UTM fuera de rango: {valor}")
    datos = {
        "valor": valor,
        "mes": ultimo["fecha"][:7],
        "fuente": "SII (vía mindicador.cl)",
    }
    try:
        with open(salida, encoding="utf-8") as f:
            if json.load(f) == datos:
                print("UTM sin cambios.")
                return
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    with open(salida, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=1)
    print(f"UTM {datos['mes']}: ${valor}")


if __name__ == "__main__":
    main()
