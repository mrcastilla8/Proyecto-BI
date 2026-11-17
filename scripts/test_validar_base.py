"""Casos positivos/negativos de los estados de contratos."""
import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("validar_base", Path(__file__).with_name("validar_base.py"))
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def contract(status="PROPUESTA_PENDIENTE_VALIDACION", **extra):
    return {"status": status, **extra}


class ContractStateTests(unittest.TestCase):
    def test_accepts_coherent_proposals(self):
        validator.validate_contract_statuses(contract(), contract())

    def test_accepts_approved_contracts_with_review_evidence(self):
        approval = {"approved_at": "2026-11-17", "issue": 3, "pull_request": 12,
                    "reviewers": ["Poma", "Cueva"]}
        validator.validate_contract_statuses(contract("APROBADO", approval=approval),
                                             contract("APROBADO", approval=approval))

    def test_rejects_unknown_state(self):
        with self.assertRaisesRegex(ValueError, "desconocido"):
            validator.validate_contract_statuses(contract("ACEPTADO"), contract())

    def test_rejects_incoherent_states(self):
        with self.assertRaisesRegex(ValueError, "incoherente"):
            validator.validate_contract_statuses(contract(), contract("APROBADO", approval={}))

    def test_rejects_approval_without_two_affected_reviewers(self):
        approval = {"approved_at": "2026-11-17", "issue": 3, "pull_request": 12,
                    "reviewers": ["Poma"]}
        with self.assertRaisesRegex(ValueError, "dos revisores"):
            validator.validate_contract_statuses(contract("APROBADO", approval=approval),
                                                 contract("APROBADO", approval=approval))


if __name__ == "__main__":
    unittest.main()
