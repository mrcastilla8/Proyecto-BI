"""Pruebas de política de estados y puntualidad por día calendario."""
import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("validar_base", Path(__file__).with_name("validar_base.py"))
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def contract(status="PROPUESTA_PENDIENTE_VALIDACION", **extra):
    return {"status": status, "version": "1.0.0", **extra}


def model_contract(status="PROPUESTA_PENDIENTE_VALIDACION", **extra):
    return contract(status, source_contract_status=status,
                    staging_sources=[{"file": f"source-{n}.csv", "status": status} for n in range(9)],
                    **extra)


class ContractStateTests(unittest.TestCase):
    def test_accepts_coherent_proposals(self):
        validator.validate_contract_statuses(model_contract(), contract())

    def test_accepts_approved_state_structure_only(self):
        # Valores de prueba ilustran el formato; no representan evidencia real.
        approval = {"approved_at": "2026-11-17", "issue": "issue-reference",
                    "pull_request": "pull-request-reference", "owner": "responsable",
                    "dataset_validation_evidence": "perfil reproducible",
                    "contract_version": "1.0.0"}
        validator.validate_contract_statuses(model_contract("APROBADO", approval=approval),
                                             contract("APROBADO", approval=approval))

    def test_rejects_unknown_primary_state(self):
        with self.assertRaisesRegex(ValueError, "desconocido"):
            validator.validate_contract_statuses(model_contract("ACEPTADO"), contract())

    def test_rejects_unknown_source_contract_state(self):
        model = model_contract()
        model["source_contract_status"] = "ACEPTADO"
        with self.assertRaisesRegex(ValueError, "Estado de fuentes desconocido"):
            validator.validate_contract_statuses(model, contract())

    def test_rejects_unknown_individual_source_state(self):
        model = model_contract()
        model["staging_sources"][4]["status"] = "ACEPTADO"
        with self.assertRaisesRegex(ValueError, "Estado de fuente desconocido"):
            validator.validate_contract_statuses(model, contract())

    def test_rejects_mixed_source_approval(self):
        model = model_contract("APROBADO")
        model["staging_sources"][4]["status"] = "PROPUESTA_PENDIENTE_VALIDACION"
        with self.assertRaisesRegex(ValueError, "incoherentes"):
            validator.validate_contract_statuses(model, contract("APROBADO", approval={}))

    def test_rejects_incoherent_contract_states(self):
        with self.assertRaisesRegex(ValueError, "Estado contractual incoherente"):
            validator.validate_contract_statuses(model_contract(), contract("APROBADO", approval={}))

    def test_rejects_approval_without_technical_owner(self):
        approval = {"approved_at": "2026-11-17", "issue": "issue-reference",
                    "pull_request": "pull-request-reference", "dataset_validation_evidence": "perfil",
                    "contract_version": "1.0.0"}
        with self.assertRaisesRegex(ValueError, "responsable"):
            validator.validate_contract_statuses(model_contract("APROBADO", approval=approval),
                                                 contract("APROBADO", approval=approval))

    def test_rejects_approval_without_dataset_evidence(self):
        approval = {"approved_at": "2026-11-17", "issue": "issue-reference",
                    "pull_request": "pull-request-reference", "owner": "responsable",
                    "contract_version": "1.0.0"}
        with self.assertRaisesRegex(ValueError, "evidencia"):
            validator.validate_contract_statuses(model_contract("APROBADO", approval=approval),
                                                 contract("APROBADO", approval=approval))

    def test_rejects_approval_version_mismatch(self):
        approval = {"approved_at": "2026-11-17", "issue": "issue-reference",
                    "pull_request": "pull-request-reference", "owner": "responsable",
                    "dataset_validation_evidence": "perfil", "contract_version": "2.0.0"}
        with self.assertRaisesRegex(ValueError, "Versión"):
            validator.validate_contract_statuses(model_contract("APROBADO", approval=approval),
                                                 contract("APROBADO", approval=approval))


class CalendarDayTests(unittest.TestCase):
    def test_delivery_during_promised_day_is_on_time_despite_later_clock_time(self):
        self.assertTrue(validator.is_on_time_calendar_day("2018-05-05 14:00:00", "2018-05-05 00:00:00"))

    def test_delivery_on_following_day_is_late(self):
        self.assertFalse(validator.is_on_time_calendar_day("2018-05-06 00:00:00", "2018-05-05 23:59:00"))


if __name__ == "__main__":
    unittest.main()
