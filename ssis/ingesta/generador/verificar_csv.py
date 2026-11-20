"""Read and profile CSV records without writing source rows."""

import argparse
import csv
import hashlib
import json
from pathlib import Path


def profile(path, source):
    with path.open("rb") as raw:
        digest = hashlib.file_digest(raw, "sha256").hexdigest()
    with path.open(encoding="utf-8-sig", newline="") as stream:
        rows = csv.reader(stream, strict=True)
        header = next(rows)
        if header != [definition.split()[0] for definition in source["columns"]]:
            raise ValueError(f"Encabezado inesperado: {path.name}")
        name = source["table"].split(".")[1]
        seen = set()
        count = duplicated = multiline = long_units = 0
        for row in rows:
            if len(row) != len(header):
                raise ValueError(f"Anchura inesperada: {path.name}, ordinal {count + 1}")
            count += 1
            if name in ("Geolocation", "OrderReviews"):
                key = tuple(row) if name == "Geolocation" else row[0]
                if key in seen:
                    duplicated += 1
                seen.add(key)
            if name == "OrderReviews":
                comments = row[3:5]
                multiline += any("\n" in value or "\r" in value for value in comments)
                long_units = max(long_units, len(comments[-1].encode("utf-16-le")) // 2)
    result = {"source": name, "sha256": digest, "records": count}
    if name in ("Geolocation", "OrderReviews"):
        result["duplicate_rows_or_ids"] = duplicated
    if name == "OrderReviews":
        result.update(multiline_records=multiline, max_message_utf16_units=long_units)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_root", type=Path)
    args = parser.parse_args()
    contract_path = Path(__file__).resolve().parents[3] / "contracts/modelo-dimensional.v1.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    result = [profile(args.csv_root / item["file"], item) for item in contract["staging_sources"]]
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
