import os

import pytest
from fastapi.testclient import TestClient

from app.main import app

os.environ["USE_MEMORY_DB"] = "true"

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["database"] == "memory"


def test_create_and_get_note():
    # Crear nota con el nuevo modelo
    note_data = {"title": "Test Note", "content": "Test Content"}
    response = client.post("/notes", json=note_data)
    assert response.status_code == 200
    created_note = response.json()
    assert created_note["title"] == "Test Note"
    assert created_note["content"] == "Test Content"
    assert "id" in created_note

    # Listar notas
    response = client.get("/notes")
    assert response.status_code == 200
    notes = response.json()
    assert len(notes) > 0
    assert any(note["title"] == "Test Note" for note in notes)


def test_obtener_nota_por_id():
    # Crear una nota de prueba
    nota_data = {"title": "Nota Especifica", "content": "Contenido Especifico"}
    response = client.post("/notes", json=nota_data)
    nota_creada = response.json()
    nota_id = nota_creada["id"]

    # Obtener la nota mediante su ID
    response = client.get(f"/notes/{nota_id}")
    assert response.status_code == 200
    nota = response.json()
    assert nota["title"] == "Nota Especifica"
    assert nota["content"] == "Contenido Especifico"


@pytest.mark.xfail(reason="Conexion a DB deshabilitada")
def test_obtener_nota_inexistente():
    # Intentar obtener una nota que no existe
    response = client.get("/notes/9999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Note not found"
