"""Valida R03 y R05 con fixtures sintéticas en memoria, mediante SQLite."""

import argparse
from datetime import date
from pathlib import Path
import re
import sqlite3

FIXTURE_SCHEMA = """
ATTACH DATABASE ':memory:' AS dw;
CREATE TABLE dw.DimFecha(fecha_key INTEGER PRIMARY KEY, fecha TEXT);
CREATE TABLE dw.DimVendedor(vendedor_key INTEGER PRIMARY KEY, seller_id TEXT);
CREATE TABLE dw.DimGeografiaVendedor(geografia_vendedor_key INTEGER PRIMARY KEY, seller_state TEXT);
CREATE TABLE dw.DimGeografiaCliente(geografia_cliente_key INTEGER PRIMARY KEY, customer_state TEXT, customer_city TEXT);
CREATE TABLE dw.FactDetallePedido(order_id TEXT, order_item_id INTEGER, vendedor_key INTEGER,
 geografia_vendedor_key INTEGER, fecha_compra_key INTEGER, order_status TEXT, price INTEGER, freight_value INTEGER,
 PRIMARY KEY (order_id, order_item_id));
CREATE TABLE dw.FactPedidos(order_id TEXT PRIMARY KEY, geografia_cliente_key INTEGER, fecha_compra_key INTEGER,
 order_purchase_timestamp TEXT, order_estimated_delivery_date TEXT, order_delivered_customer_date TEXT,
 order_status TEXT, fecha_entrega_estimada_key INTEGER, fecha_entrega_real_key INTEGER);
INSERT INTO dw.DimFecha VALUES (-1, NULL), (20200101, '2020-01-01'), (20200102, '2020-01-02'), (20200103, '2020-01-03');
INSERT INTO dw.DimVendedor VALUES (-1, NULL);
INSERT INTO dw.DimGeografiaVendedor VALUES (-1, NULL), (1, 'SP'), (2, 'RJ');
INSERT INTO dw.DimGeografiaCliente VALUES (-1, NULL, NULL), (1, 'SP', 'Sao Paulo');
"""


def read_reference(path):
    markdown = path.read_text(encoding="utf-8-sig")
    blocks = re.findall(
        r"^## (R03|R05) [^\n]+\n\n```sql\n([\s\S]*?)^```", markdown, re.MULTILINE
    )
    if sorted(report for report, _ in blocks) != ["R03", "R05"]:
        raise ValueError("Se esperaba un solo bloque SQL para R03 y otro para R05.")
    return {report: sql.strip() for report, sql in blocks}


def main():
    contract = Path(__file__).resolve().parents[2] / "docs/nivel-2/06_CONTRATO_CONSULTAS_SQL.md"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contrato", nargs="?", type=Path, default=contract)
    args = parser.parse_args()
    with sqlite3.connect(":memory:") as db:
        verify_reports(db, read_reference(args.contrato))


def verify_reports(db, reference):
    db.executescript(FIXTURE_SCHEMA)
    verify_r03(db, reference["R03"])
    verify_r05(db, reference["R05"])
    print("SQLite", sqlite3.sqlite_version, "| 10 comprobaciones sintéticas sin servidor")


def check(label, actual, expected):
    if actual != expected:
        raise AssertionError(f"{label}. Esperado {expected!r}. Obtenido {actual!r}.")
    print(f"{label}: {actual}")


def adapt_dates(sql):
    return re.sub(r"CAST\((@(?:Desde|Hasta)) AS date\)", r"DATE(\1)", sql)


def verify_r03(db, sql):
    db.executemany("INSERT INTO dw.DimVendedor VALUES (?, ?)", [(i, f"v{i:02}") for i in range(1, 57)])
    items = [
        ("comun", 1, 1, 1, 20200101, "delivered", 60, 2),
        ("comun", 2, 2, 1, 20200101, "delivered", 100, 5),
        ("comun", 56, 1, 1, 20200101, "delivered", 40, 3),
        ("desconocido", 1, -1, -1, 20200102, "delivered", 10, 1),
        ("desconocido", 2, 56, -1, 20200102, "delivered", 15, 1),
        ("cancelado", 1, 55, 1, 20200101, "canceled", 99999, 0),
        ("fuera-rango", 1, 55, 1, 20200103, "delivered", 99999, 0),
        ("sin-fecha", 1, 55, 1, -1, "delivered", 99999, 0),
    ]
    items.extend(
        (f"pedido-{i}", 1, i, 1 if i <= 30 else 2, 20200101, "delivered", 100, 5)
        for i in range(3, 56)
    )
    db.executemany("INSERT INTO dw.FactDetallePedido VALUES (?, ?, ?, ?, ?, ?, ?, ?)", items)

    top = "CASE WHEN @TopN IN (10,20,50) THEN @TopN ELSE 0 END"
    prefix = f"SELECT TOP ({top})"
    if not sql.startswith(prefix):
        raise ValueError("Cambió TOP en R03. Revisar la adaptación a SQLite.")
    r03 = "SELECT" + sql.removeprefix(prefix).rstrip(";") + f" LIMIT ({top})"
    r03 = r03.replace("COUNT_BIG", "COUNT").replace("CONVERT(float,SUM(d.price))", "CAST(SUM(d.price) AS REAL)")
    r03 = adapt_dates(r03)

    def ranking(n=10, state="__TODOS__", **overrides):
        parameters = {
            "Desde": "2020-01-01", "Hasta": "2020-01-02", "TopN": n, "EstadoVendedor": state,
        }
        return db.execute(r03, parameters | overrides).fetchall()

    check("R03 límites Top 10/20/50", [len(ranking(n)) for n in (10, 20, 50)], [10, 20, 50])
    check("R03 empate en el corte", [row[0] for row in ranking()], [f"v{i:02}" for i in range(1, 11)])
    sp = ranking(state="SP")
    check("R03 dos líneas de un pedido en el mismo vendedor", sp[0][2:], (100, 1, 100.0, 5))

    market_count = db.execute("""
        SELECT COUNT(DISTINCT order_id) FROM dw.FactDetallePedido
        WHERE vendedor_key IN (1, 2)
          AND geografia_vendedor_key = 1 AND order_status = 'delivered'
          AND fecha_compra_key BETWEEN 20200101 AND 20200102
    """).fetchone()[0]
    check("R03 conteo por vendedor y conteo conjunto", (sp[0][3] + sp[1][3], market_count), (2, 1))
    check(
        "R03 geografía desconocida y vendedor desconocido",
        [(row[0], row[2], row[3]) for row in ranking(state="__DESCONOCIDO__")],
        [("v56", 15, 1), (None, 10, 1)],
    )
    check(
        "R03 TopN inválido o nulo, fechas invertidas y estado sin coincidencias",
        [ranking(11), ranking(None), ranking(Desde="2020-01-03"), ranking(state="AC")],
        [[], [], [], []],
    )


def verify_r05(db, sql):
    def calendar_difference(start, end):
        if start is None or end is None:
            return None
        return (date.fromisoformat(end) - date.fromisoformat(start)).days

    db.create_function("days_between", 2, calendar_difference)
    def header(order, est, real, *, state=1, status="delivered", compra=20200101):
        purchase_date = str(compra)
        purchase_timestamp = None
        if compra != -1:
            purchase_timestamp = f"{purchase_date[:4]}-{purchase_date[4:6]}-{purchase_date[6:]} 08:00:00"
        promised_key = int(est[:10].replace("-", "")) if est else -1
        delivered_key = int(real[:10].replace("-", "")) if real else -1
        return (order, state, compra, purchase_timestamp, est, real, status, promised_key, delivered_key)

    est = "2020-01-02 23:59:59"
    late = "2020-01-03 00:00:00"
    headers = [
        header("mismo-dia", "2020-01-02 00:00:00", est),
        header("dia-siguiente", est, late),
        header("dos-dias", est, "2020-01-04 03:00:00", state=-1, compra=20200102),
        header("real-nula", est, None),
        header("estimada-nula", None, late),
        header("compra-nula", est, late, compra=-1),
        header("cancelado", est, late, status="canceled"),
        header("temprano", est, "2020-01-01 23:59:59"),
        header("fuera-rango", est, late, compra=20200103),
    ]
    db.executemany("INSERT INTO dw.FactPedidos VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", headers)

    delay_expression = (
        "DATEDIFF(DAY,CAST(p.order_estimated_delivery_date AS date),"
        "CAST(p.order_delivered_customer_date AS date))"
    )
    if sql.count(delay_expression) != 2:
        raise ValueError("Cambió DATEDIFF en R05. Revisar la adaptación a SQLite.")
    r05 = adapt_dates(sql.replace(
        delay_expression,
        "days_between(DATE(p.order_estimated_delivery_date),DATE(p.order_delivered_customer_date))",
    ))

    def delays(minimum=1, state="__TODOS__", **overrides):
        parameters = {
            "Desde": "2020-01-01", "Hasta": "2020-01-02", "DiasRetrasoMin": minimum, "EstadoCliente": state,
        }
        rows = db.execute(r05, parameters | overrides)
        return [(row[0], row[-1]) for row in rows]

    check("R05 uno y dos días calendario", delays(), [("dos-dias", 2), ("dia-siguiente", 1)])
    check(
        "R05 mínimo dos días y geografía desconocida",
        (delays(2), delays(state="__DESCONOCIDO__")),
        ([("dos-dias", 2)], [("dos-dias", 2)]),
    )
    check(
        "R05 compra inclusiva del último día y filtro SP",
        (delays(Desde="2020-01-02"), delays(state="SP")),
        ([("dos-dias", 2)], [("dia-siguiente", 1)]),
    )
    check(
        "R05 mínimos inválidos, nulos o sin coincidencias y rango invertido",
        [delays(n) for n in (0, 36501, None, 36500)] + [delays(Desde="2020-01-03")],
        [[], [], [], [], []],
    )


if __name__ == "__main__":
    main()
