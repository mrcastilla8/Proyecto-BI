#!/usr/bin/env python3
"""Valida base documental, contratos y fixtures sintéticas sin dependencias."""
import csv
import json
import re
import subprocess
import sys
from pathlib import Path
from datetime import date, datetime

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_DOCS = [
    "AGENTS.md", "database/AGENTS.md", "ssis/AGENTS.md", "ssis/ingesta/AGENTS.md",
    "ssis/transformaciones/AGENTS.md", "ssas/AGENTS.md", "powerbi/AGENTS.md", "docs/AGENTS.md",
]
CONTRACT_STATES = {"PROPUESTA_PENDIENTE_VALIDACION", "APROBADO"}
REQUIRED_SQL = [f"database/{name}" for name in (
    "00_crear_base.sql", "01_auditoria.sql", "02_staging.sql", "03_dimensiones.sql",
    "04_hechos.sql", "05_controles.sql", "06_pruebas.sql")]


def validate_contract_statuses(model, metrics):
    """Valida evidencia técnica contractual; no certifica aprobaciones de GitHub."""
    for name, contract in (("modelo dimensional", model), ("métricas", metrics)):
        state = contract.get("status")
        require(state in CONTRACT_STATES, f"Estado contractual desconocido en {name}: {state!r}")
    require(model["status"] == metrics["status"], "Estado contractual incoherente")
    require(model.get("source_contract_status") in CONTRACT_STATES,
            "Estado de fuentes desconocido en contrato dimensional")
    require(model["source_contract_status"] == model["status"],
            "Estado global y estado de fuentes incoherentes")
    sources = model.get("staging_sources")
    require(isinstance(sources, list) and len(sources) == 9,
            "El contrato dimensional debe enumerar las nueve fuentes")
    for source in sources:
        state = source.get("status")
        require(state in CONTRACT_STATES, f"Estado de fuente desconocido: {source.get('file')}")
        require(state == model["source_contract_status"],
                f"Estado global y estado de fuente incoherentes: {source.get('file')}")
    for name, contract in (("modelo dimensional", model), ("métricas", metrics)):
        state = contract["status"]
        if state == "APROBADO":
            approval = contract.get("approval")
            require(isinstance(approval, dict), f"Falta evidencia de aprobación en {name}")
            require(isinstance(approval.get("issue"), str) and approval["issue"].strip()
                    and isinstance(approval.get("pull_request"), str) and approval["pull_request"].strip(),
                    f"Falta referencia issue/PR de aprobación en {name}")
            try:
                date.fromisoformat(approval.get("approved_at", ""))
            except (ValueError, TypeError):
                require(False, f"Fecha de aprobación inválida en {name}")
            require(isinstance(approval.get("owner"), str) and approval["owner"].strip(),
                    f"Falta responsable de aprobación técnica en {name}")
            require(isinstance(approval.get("dataset_validation_evidence"), str)
                    and approval["dataset_validation_evidence"].strip(),
                    f"Falta evidencia de validación del dataset en {name}")
            require(approval.get("contract_version") == contract.get("version"),
                    f"Versión aprobada no coincide en {name}")


def is_on_time_calendar_day(actual, estimated):
    """Compara días inclusivos, ignorando hora; ambas fechas deben existir."""
    require(actual and estimated, "Se requieren ambas fechas para evaluar puntualidad")
    try:
        actual_date = datetime.fromisoformat(actual).date()
        estimated_date = datetime.fromisoformat(estimated).date()
    except ValueError as exc:
        raise ValueError("Fecha sintética inválida") from exc
    return actual_date <= estimated_date


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
    validate_contract_statuses(model, metrics)
    for rel in REQUIRED_SQL:
        require((ROOT / rel).is_file() and (ROOT / rel).stat().st_size > 100,
                f"Script SQL obligatorio ausente o vacío: {rel}")
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
    sources = model["staging_sources"]
    require(len(model["source_files"]) == 9 and len(set(model["source_files"])) == 9,
            "El contrato debe listar nueve archivos de origen distintos")
    require([s["file"] for s in sources] == model["source_files"],
            "Las fuentes de staging deben corresponder, en orden, al contrato de archivos")
    require(len({s["fixture"] for s in sources}) == len(sources), "Fixtures de fuente duplicadas")
    for rel in ("docs/contrato-datos.md", "docs/contrato-metricas.md"):
        require((ROOT / rel).is_file() and len((ROOT / rel).read_text(encoding="utf-8")) > 100, f"Documentación contractual insuficiente: {rel}")
    collaboration_text = "\n".join((ROOT / rel).read_text(encoding="utf-8").lower() for rel in
        ("AGENTS.md", "docs/colaboracion.md", "docs/contrato-datos.md", "docs/plan-integracion.md",
         "docs/pruebas-y-evidencias.md", ".github/PULL_REQUEST_TEMPLATE.md"))
    require("aprobación externa obligatoria" not in collaboration_text
            and "revisor ajeno" not in collaboration_text
            and "dos revisores afectados" not in collaboration_text,
            "La documentación aún exige aprobación/revisor externo para merge")

    source_rows = {}
    for source in sources:
        column_specs = source.get("columns", [])
        require(bool(column_specs) and all(isinstance(c, str) and len(c.split(maxsplit=1)) == 2
                                           for c in column_specs),
                f"Columnas/tipos incompletos en contrato: {source['file']}")
        columns = [spec.split(maxsplit=1)[0] for spec in column_specs]
        require(len(set(columns)) == len(columns), f"Columna repetida en contrato: {source['file']}")
        fixture_name = source["fixture"]
        require(Path(fixture_name).name == fixture_name, f"Ruta de fixture no permitida: {fixture_name}")
        path = ROOT / "data/fixtures" / fixture_name
        with path.open(encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            require(reader.fieldnames == columns, f"Cabecera inesperada en {fixture_name} para {source['file']}")
            records = list(reader)
        require(records, f"Fixture vacía: {fixture_name}")
        require(all(all(v is not None for v in row.values()) for row in records), f"Fila mal formada en {fixture_name}")
        source_rows[source["file"]] = records
    invalid_path = ROOT / "data/fixtures/invalid_references.csv"
    with invalid_path.open(encoding="utf-8-sig", newline="") as f:
        invalid_reader = csv.DictReader(f)
        require(invalid_reader.fieldnames == ["order_id", "order_item_id", "product_id", "seller_id", "reason"],
                "Cabecera inesperada en invalid_references.csv")
        invalid_rows = list(invalid_reader)
    orders_rows = source_rows["olist_orders_dataset.csv"]
    items_rows = source_rows["olist_order_items_dataset.csv"]
    payments_rows = source_rows["olist_order_payments_dataset.csv"]
    reviews_rows = source_rows["olist_order_reviews_dataset.csv"]
    customers_rows = source_rows["olist_customers_dataset.csv"]
    sellers_rows = source_rows["olist_sellers_dataset.csv"]
    products_rows = source_rows["olist_products_dataset.csv"]
    geo_rows = source_rows["olist_geolocation_dataset.csv"]
    require(len(invalid_rows) == 1 and invalid_rows[0]["order_id"] not in {r["order_id"] for r in orders_rows},
            "Caso negativo de referencia inválida debe apuntar a pedido inexistente")
    orders = {r["order_id"]: r for r in orders_rows}
    require(len(orders) == len(orders_rows), "order_id duplicado en fixture de pedidos")
    line_keys = [(r["order_id"], r["order_item_id"]) for r in items_rows]
    require(len(line_keys) == len(set(line_keys)), "Clave de línea duplicada")
    for source_name, records in (("order_items", items_rows), ("order_payments", payments_rows),
                                 ("order_reviews", reviews_rows)):
        require(all(r["order_id"] in orders for r in records), f"Fixture huérfana: {source_name}")
    customer_ids = {r["customer_id"] for r in customers_rows}
    require(all(r["customer_id"] in customer_ids for r in orders.values()), "Pedido con customer_id desconocido")
    product_ids = {r["product_id"] for r in products_rows}
    seller_ids = {r["seller_id"] for r in sellers_rows}
    require(all(r["product_id"] in product_ids and r["seller_id"] in seller_ids for r in items_rows),
            "Línea con producto/vendedor desconocido")
    require(any(sum(x["order_id"] == oid for x in items_rows) > 1 for oid in orders), "Falta pedido con varias líneas")
    require(any(sum(x["order_id"] == oid for x in payments_rows) > 1 for oid in orders), "Falta pedido con varios pagos")
    require(any(sum(x["order_id"] == oid for x in reviews_rows) > 1 for oid in orders), "Falta pedido con varias reseñas")
    require(any(r["order_status"] == "delivered" and r["order_delivered_customer_date"]
                and r["order_estimated_delivery_date"]
                and not is_on_time_calendar_day(r["order_delivered_customer_date"], r["order_estimated_delivery_date"])
                for r in orders.values()), "Falta entrega tardía (día calendario posterior)")
    require(any(not r["order_delivered_customer_date"] for r in orders.values()), "Falta fecha real de entrega nula")
    require(any(not any(x["order_id"] == oid for x in items_rows) for oid in orders), "Falta pedido sin líneas")
    require(len({r["customer_unique_id"] for r in customers_rows}) < len(customers_rows),
            "Falta cliente recurrente customer_unique_id")
    require(len([r for r in geo_rows if r["geolocation_zip_code_prefix"] == "01001"]) > 1,
            "Falta multiplicidad geográfica para deduplicar")
    require(any(r["order_status"] == "delivered" and r["order_delivered_customer_date"].startswith("2018-05-05 ")
                and r["order_estimated_delivery_date"] == "2018-05-05 00:00:00"
                and is_on_time_calendar_day(r["order_delivered_customer_date"], r["order_estimated_delivery_date"])
                for r in orders.values()), "Falta entrega durante el día prometido")
    require(any(r["order_status"] == "delivered" and r["order_delivered_customer_date"].startswith("2018-05-06 ")
                and r["order_estimated_delivery_date"].startswith("2018-05-05 ")
                and not is_on_time_calendar_day(r["order_delivered_customer_date"], r["order_estimated_delivery_date"])
                for r in orders.values()), "Falta entrega al día siguiente del prometido")
    fixture_note = (ROOT / "data/fixtures/README.md").read_text(encoding="utf-8").lower()
    require("sintéticas" in fixture_note and "no proceden" in fixture_note, "Fixtures no identificadas claramente como sintéticas")

    env_example = (ROOT / ".env.example").read_text(encoding="utf-8")
    require("SQL_SERVER=localhost" in env_example and "SQL_PASSWORD=" in env_example, "Ejemplo de entorno no es ilustrativo/local")
    forbidden = re.compile(r"C:\\Users\\[^\\\s]+|(?:password|passwd|token|secret)\s*[:=]\s*\S+", re.I)
    git = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=ROOT, capture_output=True, text=True)
    if git.returncode == 0 and Path(git.stdout.strip()).resolve() == ROOT:
        listed = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            cwd=ROOT, capture_output=True, check=True, encoding="utf-8",
        )
        candidates = (ROOT / name for name in listed.stdout.split("\0") if name)
    else:
        candidates = ROOT.rglob("*")
    for path in candidates:
        if not path.is_file() or ".git" in path.parts or path.name in {".env.example", "validar_base.py"}:
            continue
        if path.suffix.lower() in {".csv", ".json", ".md", ".py", ".yml", ".sql", ".txt", ".editorconfig", ".gitattributes", ".gitignore"}:
            try:
                content = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            require(not forbidden.search(content), f"Ruta local/posible secreto en {path.relative_to(ROOT)}")
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
