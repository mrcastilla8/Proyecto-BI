#!/usr/bin/env python3
"""Valida base documental, contratos y fixtures sintéticas sin dependencias."""
import csv
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_DOCS = [
    "AGENTS.md", "database/AGENTS.md", "ssis/AGENTS.md", "ssis/ingesta/AGENTS.md",
    "ssis/transformaciones/AGENTS.md", "ssas/AGENTS.md", "powerbi/AGENTS.md", "docs/AGENTS.md",
]
EXPECTED_FILES = {
    "orders.csv": ["order_id", "customer_id", "order_status", "order_purchase_timestamp", "order_delivered_customer_date", "order_estimated_delivery_date"],
    "order_items.csv": ["order_id", "order_item_id", "product_id", "seller_id", "price", "freight_value"],
    "order_payments.csv": ["order_id", "payment_sequential", "payment_type", "payment_value"],
    "order_reviews.csv": ["review_id", "order_id", "review_score"],
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    for rel in REQUIRED_DOCS:
        p = ROOT / rel
        require(p.is_file() and len(p.read_text(encoding="utf-8").strip()) >= 80,
                f"AGENTS ausente o insuficiente: {rel}")

    model = json.loads((ROOT / "contracts/modelo-dimensional.v1.json").read_text(encoding="utf-8"))
    metrics = json.loads((ROOT / "contracts/metricas.v1.json").read_text(encoding="utf-8"))
    require(model["status"] == metrics["status"] == "PROPUESTA_PENDIENTE_VALIDACION", "Estado contractual incoherente")
    require(model["database"] == "BI_OLIST" and model["schemas"] == ["stg", "dw", "audit"], "Base/esquemas inesperados")
    facts = {f["name"]: f for f in model["facts"]}
    require(facts["dw.FactPedidos"]["grain"] == "una fila por order_id", "Grano FactPedidos incorrecto")
    require(facts["dw.FactDetallePedido"]["grain"] == "una fila por (order_id, order_item_id)", "Grano detalle incorrecto")
    require("order_id" in facts["dw.FactPedidos"]["degenerate_dimensions"] and "order_id" in facts["dw.FactDetallePedido"]["degenerate_dimensions"], "Falta order_id degenerado")
    require(model["relationships"]["facts_directly_related"] is False, "No relacionar hechos directamente")
    ids = [m["id"] for m in metrics["metrics"]]
    require(len(ids) == len(set(ids)) and len(ids) >= 8, "IDs de métricas duplicados o incompletos")
    required_metrics = {"ventas_productos_entregados", "pedidos_entregados_con_items", "pedidos_totales", "ticket_promedio_productos_entregados", "flete_pedidos_entregados", "porcentaje_entregas_a_tiempo", "dias_promedio_entrega", "calificacion_promedio"}
    require(required_metrics.issubset(ids), "Faltan métricas obligatorias")
    require(set(model["source_files"]) == {
        "olist_orders_dataset.csv", "olist_order_items_dataset.csv", "olist_order_payments_dataset.csv", "olist_order_reviews_dataset.csv", "olist_customers_dataset.csv", "olist_sellers_dataset.csv", "olist_products_dataset.csv", "olist_geolocation_dataset.csv", "product_category_name_translation.csv"}, "Lista de fuentes inesperada")
    for rel in ("docs/contrato-datos.md", "docs/contrato-metricas.md"):
        require((ROOT / rel).is_file() and len((ROOT / rel).read_text(encoding="utf-8")) > 100, f"Documentación contractual insuficiente: {rel}")

    rows = {}
    for filename, columns in EXPECTED_FILES.items():
        path = ROOT / "data/fixtures" / filename
        with path.open(encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            require(reader.fieldnames == columns, f"Cabecera inesperada en {filename}")
            records = list(reader)
        require(records, f"Fixture vacía: {filename}")
        require(all(all(v is not None for v in row.values()) for row in records), f"Fila mal formada en {filename}")
        rows[filename] = records
    orders = {r["order_id"]: r for r in rows["orders.csv"]}
    require(len(orders) == len(rows["orders.csv"]), "order_id duplicado en fixture de pedidos")
    line_keys = [(r["order_id"], r["order_item_id"]) for r in rows["order_items.csv"]]
    require(len(line_keys) == len(set(line_keys)), "Clave de línea duplicada")
    require(all(r["order_id"] in orders for group in rows.values() for r in group), "Fixture huérfana")
    require(any(sum(x["order_id"] == oid for x in rows["order_items.csv"]) > 1 for oid in orders), "Falta pedido con varias líneas")
    require(any(sum(x["order_id"] == oid for x in rows["order_payments.csv"]) > 1 for oid in orders), "Falta pedido con varios pagos")
    require(any(sum(x["order_id"] == oid for x in rows["order_reviews.csv"]) > 1 for oid in orders), "Falta pedido con varias reseñas")
    require(any(r["order_status"] == "delivered" and r["order_delivered_customer_date"] > r["order_estimated_delivery_date"] for r in orders.values()), "Falta entrega tardía")
    require(any(not r["order_delivered_customer_date"] for r in orders.values()), "Falta fecha real de entrega nula")
    fixture_note = (ROOT / "data/fixtures/README.md").read_text(encoding="utf-8").lower()
    require("sintéticas" in fixture_note and "no proceden" in fixture_note, "Fixtures no identificadas claramente como sintéticas")

    env_example = (ROOT / ".env.example").read_text(encoding="utf-8")
    require("SQL_SERVER=localhost" in env_example and "SQL_PASSWORD=" in env_example, "Ejemplo de entorno no es ilustrativo/local")
    forbidden = re.compile(r"C:\\Users\\[^\\\s]+|(?:password|passwd|token|secret)\s*[:=]\s*\S+", re.I)
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts or path.name in {".env.example", "validar_base.py"}:
            continue
        if path.suffix.lower() in {".csv", ".json", ".md", ".py", ".yml", ".sql", ".txt", ".editorconfig", ".gitattributes", ".gitignore"}:
            try:
                content = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            require(not forbidden.search(content), f"Ruta local/posible secreto en {path.relative_to(ROOT)}")
    git = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=ROOT, capture_output=True, text=True)
    if git.returncode == 0:
        branch = subprocess.run(["git", "branch", "--show-current"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
        if branch and branch != "master":
            require(re.fullmatch(r"(castilla|poma|cueva|basualdo|angel)/[a-z0-9]+(?:-[a-z0-9]+)*", branch) is not None, f"Rama fuera de convención: {branch}")
    print("PASS: documentación, contratos, fixtures sintéticas y controles base")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
