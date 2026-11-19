#!/usr/bin/env python3
"""Perfil local, agregado y sin mostrar filas de los nueve CSV Olist (stdlib)."""
import argparse
import collections
import csv
import hashlib
import io
import json
from decimal import Decimal
from datetime import datetime
from pathlib import Path

FILES = {
    "olist_orders_dataset.csv": ["order_id"],
    "olist_order_items_dataset.csv": ["order_id", "order_item_id"],
    "olist_order_payments_dataset.csv": ["order_id", "payment_sequential"],
    "olist_order_reviews_dataset.csv": ["review_id"],
    "olist_customers_dataset.csv": ["customer_id"],
    "olist_sellers_dataset.csv": ["seller_id"],
    "olist_products_dataset.csv": ["product_id"],
    "olist_geolocation_dataset.csv": [],
    "product_category_name_translation.csv": ["product_category_name"],
}
NUMERIC_FIELDS = {"price", "freight_value", "payment_value", "geolocation_lat", "geolocation_lng",
                  "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm",
                  "order_item_id", "payment_sequential", "payment_installments", "review_score",
                  "product_name_lenght", "product_description_lenght", "product_photos_qty"}


class DecimalSummary:
    """Min/max/scale incremental sin retener cada observación."""
    def __init__(self):
        self.minimum = None
        self.maximum = None
        self.max_scale = 0

    def add(self, raw):
        value = Decimal(raw)
        self.minimum = value if self.minimum is None or value < self.minimum else self.minimum
        self.maximum = value if self.maximum is None or value > self.maximum else self.maximum
        self.max_scale = max(self.max_scale, max(0, -value.as_tuple().exponent))

    def as_dict(self):
        return {"min": str(self.minimum), "max": str(self.maximum), "max_decimal_places": self.max_scale}


class HashingReader(io.RawIOBase):
    """Calcula SHA-256 sobre los mismos bytes que consume el parser CSV."""
    def __init__(self, source):
        super().__init__()
        self.source = source
        self.digest = hashlib.sha256()

    def readable(self):
        return True

    def readinto(self, buffer):
        count = self.source.readinto(buffer)
        if count:
            self.digest.update(memoryview(buffer)[:count])
        return count


def profile(path):
    dialect = csv.excel
    rows = 0
    nulls = collections.Counter()
    max_lengths = collections.Counter()
    duplicate_counts = collections.Counter()
    exact_row_hashes = set()
    numeric_values = collections.defaultdict(DecimalSummary)
    date_lengths = collections.defaultdict(collections.Counter)
    categorical_values = collections.defaultdict(collections.Counter)
    header = None
    with path.open("rb") as binary:
        hashing_reader = HashingReader(binary)
        with io.TextIOWrapper(io.BufferedReader(hashing_reader), encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle, dialect=dialect, strict=True)
            header = reader.fieldnames
            for row in reader:
                if None in row or any(value is None for value in row.values()):
                    raise ValueError(f"Registro CSV irregular en {path.name}, línea lógica {reader.line_num}")
                exact_row_hashes.add(hashlib.sha256(json.dumps(row, ensure_ascii=False, sort_keys=True).encode("utf-8")).digest())
                rows += 1
                for name, value in row.items():
                    if value is None or value == "":
                        nulls[name] += 1
                    elif value is not None:
                        max_lengths[name] = max(max_lengths[name], len(value))
                        if name in NUMERIC_FIELDS:
                            numeric_values[name].add(value)
                        if name.endswith(("timestamp", "_date")):
                            date_lengths[name][len(value)] += 1
                            datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
                        if name in {"order_status", "payment_type", "review_score"}:
                            categorical_values[name][value] += 1
                keys = FILES[path.name]
                if keys:
                    duplicate_counts[tuple(row.get(k) for k in keys)] += 1
        digest = hashing_reader.digest.hexdigest()
    duplicates = sum(n - 1 for n in duplicate_counts.values() if n > 1)
    contract_path = Path(__file__).resolve().parents[1] / "contracts" / "modelo-dimensional.v1.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    expected = next(source for source in contract["staging_sources"] if source["file"] == path.name)
    contracted_headers = [column.split(maxsplit=1)[0] for column in expected["columns"]]
    if header != contracted_headers:
        raise ValueError(f"Encabezados no coinciden con contrato preliminar: {path.name}")
    return {
        "file": path.name,
        "sha256": digest,
        "encoding": "UTF-8 (BOM permitido)",
        "delimiter": repr(dialect.delimiter),
        "quotechar": repr(dialect.quotechar),
        "headers": header,
        "rows": rows,
        "duplicate_exact_rows": rows - len(exact_row_hashes),
        "null_or_empty_by_column": dict(nulls),
        "max_text_length_by_column": dict(max_lengths),
        "numeric_observations": {name: summary.as_dict() for name, summary in numeric_values.items()},
        "timestamp_text_lengths": {name: dict(counts) for name, counts in date_lengths.items()},
        "small_categorical_domains": {name: dict(counts) for name, counts in categorical_values.items()},
        "candidate_key": FILES[path.name] or None,
        "duplicate_candidate_key_rows": duplicates if FILES[path.name] else None,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="Carpeta local que contiene los nueve CSV")
    args = parser.parse_args()
    reports = []
    for name in FILES:
        path = args.directory / name
        if not path.is_file():
            raise SystemExit(f"Falta archivo requerido: {name}")
        reports.append(profile(path))
    print(json.dumps(reports, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
