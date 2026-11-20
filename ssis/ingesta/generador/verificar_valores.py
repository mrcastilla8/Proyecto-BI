"""Compare authenticated CSV values with SQL staging by ordinal and SHA-256."""
import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
from decimal import Decimal
from itertools import zip_longest
from pathlib import Path


CONTRACT = Path(__file__).resolve().parents[3] / "contracts" / "modelo-dimensional.v1.json"
COLUMN = re.compile(r"([a-z_]+) (VARCHAR|NVARCHAR|CHAR|INT|TINYINT|DECIMAL|DATETIME2)(?:\((\d+)(?:,(\d+))?\))?( NULL)?")
BASES = ("BI_OLIST", "BI_OLIST_VALIDACION_TEXTO")
LOCALDB = r"(localdb)\BI_OLIST_ISSUE1_PROTO"


def row_digest(row, columns):
    parts = []
    for name, kind, _, scale, nullable in columns:
        value = row[name]
        if value == "" and nullable:
            parts.append("N;")
            continue
        if kind in ("INT", "TINYINT"):
            value = str(int(value))
        elif kind == "DECIMAL":
            number = Decimal(value)
            value = format(abs(number) if number == 0 else number, f".{scale}f")
        encoded = value.encode("utf-16le")
        parts.append(f"{len(encoded)}:{value}")
    return hashlib.sha256("".join(parts).encode("utf-16le")).hexdigest().upper()


def quote(value):
    return "N'" + value.replace("'", "''") + "'"


def verify(args, source, entry):
    table = source["table"]
    columns = [COLUMN.fullmatch(item).groups() for item in source["columns"]]
    file = args.csv / source["file"]
    with file.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if digest != entry["sha256"]:
        raise ValueError(f"Huella CSV distinta del perfil: {table}")

    fields = []
    for name, kind, _, _, _ in columns:
        style = ",120" if kind == "DATETIME2" else ""
        # Use max strings to avoid truncating the combined payload.
        val = f"CONVERT(nvarchar(max),[{name}]{style})"
        fields.append(f"CASE WHEN [{name}] IS NULL THEN N'N;' ELSE CONCAT(DATALENGTH({val}),N':',{val}) END")
    payload = "CONCAT(CONVERT(nvarchar(max),N'')," + ",".join(fields) + ")"
    sql = f"""
SET NOCOUNT ON;
{args.guard}
DECLARE @batch bigint=(SELECT batch_id FROM audit.Batch WHERE source_name={quote(entry["source"])}
 AND source_sha256='{digest}' AND contract_version='1.0.0' AND status='COMPLETE');
IF @batch IS NULL THROW 51901,'Lote no encontrado',1;
SELECT source_row_number,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),{payload})),2)
FROM {table} WHERE batch_id=@batch ORDER BY source_row_number;
"""
    command = ["sqlcmd", "-S", args.instancia, "-d", args.base, "-E", "-C", "-b", "-W",
               "-h", "-1", "-s", "|", "-r", "1", "-Q", sql]
    compared = differences = 0
    examples = []
    with file.open(encoding="utf-8-sig", newline="") as stream, subprocess.Popen(
        command, stdout=subprocess.PIPE, text=True, encoding="ascii", errors="replace"
    ) as process:
        rows = csv.DictReader(stream, strict=True)
        for ordinal, (row, line) in enumerate(zip_longest(rows, process.stdout), 1):
            if row is not None:
                compared += 1
            if row is None or line is None or line.strip() != f"{ordinal}|{row_digest(row, columns)}":
                differences += 1
                if len(examples) < 12:
                    examples.append(ordinal)
        if process.wait():
            raise RuntimeError(f"SQLCMD falló para {table}")
    if compared != entry["records"]:
        raise ValueError(f"Cantidad CSV distinta del perfil: {table}")
    return differences, compared, examples


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--perfil", required=True, type=Path)
    parser.add_argument("--archivos", type=Path)
    parser.add_argument("--base", choices=BASES)
    parser.add_argument("--instancia")
    parser.add_argument("--principal", action="store_true", help="Consulta de solo lectura a BI_OLIST del servicio local MSSQLSERVER.")
    args = parser.parse_args()
    if args.principal:
        if args.archivos or args.instancia or args.base:
            parser.error("--principal identifica el servicio local y no admite opciones de LocalDB.")
        computer = os.getenv("COMPUTERNAME", "")
        if not re.fullmatch(r"[A-Za-z0-9_-]+", computer):
            parser.error("No se pudo identificar el equipo Windows.")
        args.instancia = f"lpc:{computer}"
        args.base = BASES[0]
        args.guard = f"""IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>0
 OR SERVERPROPERTY('InstanceName') IS NOT NULL OR DB_NAME()<>N'BI_OLIST'
 OR @@SERVERNAME<>{quote(computer)} OR CONNECTIONPROPERTY('net_transport')<>N'Shared memory'
 THROW 51900,'Destino distinto de BI_OLIST principal local',1;"""
    else:
        args.instancia = args.instancia or LOCALDB
        args.base = args.base or BASES[1]
        if not args.archivos or not re.fullmatch(r"\(localdb\)\\[a-zA-Z0-9_-]+", args.instancia):
            parser.error("Se requieren LocalDB con nombre y --archivos.")
        directory = str(args.archivos.resolve(strict=True)).rstrip("\\") + "\\"
        args.guard = f"""IF COALESCE(CONVERT(int,SERVERPROPERTY('IsLocalDB')),0)<>1 OR DB_NAME()<>{quote(args.base)}
 OR EXISTS(SELECT 1 FROM sys.database_files WHERE LEFT(physical_name,LEN({quote(directory)}))<>{quote(directory)})
 THROW 51900,'Destino fuera del laboratorio',1;"""
    sources = json.loads(CONTRACT.read_text(encoding="utf-8"))["staging_sources"]
    profile = {item["source"]: item for item in json.loads(args.perfil.read_text(encoding="utf-8-sig"))}
    total = differences = 0
    print("tabla|filas CSV comparadas|diferencias|primeros ordinales", flush=True)
    for source in sources:
        name = source["table"].removeprefix("stg.")
        delta, count, examples = verify(args, source, profile[name])
        differences += delta
        total += count
        print(f"{name}|{count}|{delta}|{','.join(map(str, examples))}", flush=True)
    print(f"TOTAL|{total}|{differences}|")
    return int(differences != 0)


if __name__ == "__main__":
    raise SystemExit(main())
