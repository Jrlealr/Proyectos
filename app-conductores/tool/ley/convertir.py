#!/usr/bin/env python3
"""Convierte el XML oficial de LeyChile (Ley 18.290, DFL 1 de 2009) al JSON
que usa la app (assets/ley/ley_18290.json). Solo usa la biblioteca estándar.

Uso: convertir.py <entrada.xml> <salida.json>
"""
import json
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

NS = {"n": "http://www.leychile.cl/esquemas"}
FUENTE = "https://www.bcn.cl/leychile/navegar?idNorma=1007469"

# Las notas de modificación ("LEY Nº18.290 / Art. 45 / D.O 07.02.1984") van
# en una columna al margen derecho, desde ~la columna 68.
COLUMNA_NOTAS = 60

# Etiquetado automático por palabras clave (texto sin tildes, minúsculas).
TEMAS = {
    "documentos": [
        "permiso de circulacion", "seguro obligatorio", "revision tecnica",
        "certificado de inscripcion", "portar", "porte",
    ],
    "fiscalizacion": [
        "carabineros", "inspectores fiscales", "retiro de circulacion",
        "retirar de circulacion", "retirado de la circulacion", "corrales",
        "fiscalizacion", "juzgado de policia local",
    ],
    "infracciones": [
        "gravisima", "infracciones o contravenciones", "multa",
        "unidades tributarias mensuales", "suspension de la licencia",
    ],
    "velocidad": ["velocidad", "kilometros por hora"],
    "alcohol": [
        "alcohol", "ebriedad", "estupefacientes", "psicotropicas",
        "alcoholemia", "narcotest",
    ],
    "celular": ["telefonia movil", "dispositivo", "audifonos", "pantallas"],
    "motos": ["motocicleta", "motoneta", "ciclomotor", "casco"],
    "licencias": ["licencia de conductor", "licencias de conductor", "licencia clase", "clase a", "clase b", "clase c"],
}


def sin_tildes(s):
    return "".join(
        c for c in unicodedata.normalize("NFD", s.lower())
        if unicodedata.category(c) != "Mn"
    )


# Notas que a veces quedan desalineadas dentro del cuerpo (ej. "LEY Nº18.290",
# "Art. 45", "D.O. 07.02.1984"), separadas por 3+ espacios.
NOTA_SUELTA = re.compile(
    r"\s{3,}(?:LEY|Ley|DL|D\.L\.?|DFL|D\.F\.L\.?|D\.O\.?|Art\.|ART\.)"
    r" ?N?[º°]? ?[\d.]+(?: [^\s]+){0,3}?(?=\s{3,}|$)"
)


def quitar_notas(linea):
    """Elimina la columna de notas al margen derecho de una línea."""
    if linea[:COLUMNA_NOTAS].strip() == "" and linea.strip():
        return None  # la línea completa es una nota: no corta el párrafo
    linea = NOTA_SUELTA.sub("   ", linea)
    m = None
    for m in re.finditer(r"\s{3,}", linea):
        pass
    if m and m.end() >= COLUMNA_NOTAS:
        return linea[: m.start()]
    return linea


def limpiar(texto):
    """Quita notas y rearma párrafos. Un párrafo empieza con sangría o
    tras una línea en blanco."""
    parrafos, actual = [], []
    for cruda in texto.splitlines():
        linea = quitar_notas(cruda.rstrip())
        if linea is None:
            continue
        if not linea.strip():
            if actual:
                parrafos.append(actual)
                actual = []
            continue
        if linea.startswith("     ") and actual:
            parrafos.append(actual)
            actual = []
        actual.append(linea.strip())
    if actual:
        parrafos.append(actual)
    return "\n\n".join(re.sub(r"\s+", " ", " ".join(p)).strip() for p in parrafos)


def titulo_de(ef):
    t = re.sub(r"\s+", " ", ef.findtext("n:Texto", "", NS)).strip()
    t = re.sub(r"\(?\s*Arts?\.[^)]*\)?\s*$", "", t, flags=re.I).strip()
    t = t.replace("LEY Nº18.290 ", "")
    return t


def convertir(ruta_xml):
    raiz = ET.parse(ruta_xml).getroot()
    articulos = []

    def recorrer(nodo, ubicacion):
        for ef in nodo.findall("n:EstructurasFuncionales/n:EstructuraFuncional", NS):
            tipo = ef.get("tipoParte")
            if tipo in ("Título", "Párrafo"):
                base = ubicacion[:1] if tipo == "Párrafo" else []
                recorrer(ef, base + [titulo_de(ef)])
            elif tipo == "Artículo" and ubicacion:
                if ef.get("derogado") != "no derogado":
                    continue
                nombre = ef.findtext("n:Metadatos/n:NombreParte", "", NS).strip()
                transitorio = ef.get("transitorio") == "transitorio"
                numero = f"Transitorio {nombre}" if transitorio else nombre
                texto = limpiar(ef.findtext("n:Texto", "", NS))
                norm = sin_tildes(texto)
                temas = sorted(t for t, claves in TEMAS.items()
                               if any(c in norm for c in claves))
                articulos.append({
                    "id": ef.get("idParte"),
                    "numero": numero,
                    "ubicacion": " › ".join(ubicacion),
                    "texto": texto,
                    "temas": temas,
                })
            else:
                recorrer(ef, ubicacion)

    recorrer(raiz, [])
    nombre = raiz.findtext("n:Metadatos/n:NombresUsoComun/n:NombreUsoComun", "", NS)
    return {
        "titulo": nombre.strip().capitalize().replace("transito", "tránsito") or "Ley de Tránsito",
        "norma": "Ley 18.290 de Tránsito (texto refundido DFL 1 de 2009)",
        "fuente": FUENTE,
        "versionFecha": raiz.get("fechaVersion", ""),
        "obtenido": datetime.now(timezone.utc).date().isoformat(),
        "articulos": articulos,
    }


def main():
    entrada, salida = sys.argv[1], sys.argv[2]
    datos = convertir(entrada)
    if len(datos["articulos"]) < 200:
        sys.exit(f"Muy pocos artículos ({len(datos['articulos'])}); ¿cambió el formato?")
    # Si solo cambió la fecha de descarga, no se reescribe (evita commits vacíos).
    try:
        with open(salida, encoding="utf-8") as f:
            previo = json.load(f)
        if {**previo, "obtenido": ""} == {**datos, "obtenido": ""}:
            print("Sin cambios en el contenido.")
            return
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    import os
    os.makedirs(os.path.dirname(salida), exist_ok=True)
    with open(salida, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=1)
    print(f"{len(datos['articulos'])} artículos → {salida}")


if __name__ == "__main__":
    main()
