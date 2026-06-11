"""
Astronomer default DAG integrity test.
Imports every DAG in dags/ to catch syntax/import errors before runtime.
"""
import os
import logging
from contextlib import contextmanager

import pytest
from airflow.models import DagBag

LOG = logging.getLogger(__name__)


@contextmanager
def suppress_logging(namespace):
    logger = logging.getLogger(namespace)
    old_value = logger.disabled
    logger.disabled = True
    try:
        yield
    finally:
        logger.disabled = old_value


def get_import_errors():
    with suppress_logging("airflow"):
        dag_bag = DagBag(include_examples=False)

        def strip_path_prefix(path):
            return os.path.relpath(path, os.environ.get("AIRFLOW_HOME"))

        return [(None, None)] + [
            (strip_path_prefix(k), v.strip()) for k, v in dag_bag.import_errors.items()
        ]


@pytest.mark.parametrize(
    "rel_path,rv", get_import_errors(), ids=[x[0] for x in get_import_errors()]
)
def test_file_imports(rel_path, rv):
    """Test for import errors on a file."""
    if rel_path and rv:
        raise Exception(f"{rel_path} failed to import with message \n {rv}")
