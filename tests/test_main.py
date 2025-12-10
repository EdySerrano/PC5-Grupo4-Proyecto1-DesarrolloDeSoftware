import os
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

import app.main as main_module
from app.main import app, get_db

os.environ["USE_MEMORY_DB"] = "true"


def override_get_db():
    yield None


app.dependency_overrides[get_db] = override_get_db
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


def test_obtener_nota_inexistente():
    # Intentar obtener una nota que no existe
    response = client.get("/notes/9999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Note not found"


def test_salud_db_con_error(monkeypatch):
    monkeypatch.setattr(main_module, "USE_MEMORY_DB", False)

    with patch("app.main.get_db") as mock_get_db:
        mock_db_session = MagicMock()
        mock_db_session.execute.side_effect = Exception("DB Error")
        mock_get_db.return_value = iter([mock_db_session])

        original_overrides = app.dependency_overrides.copy()
        app.dependency_overrides = {}

        response = client.get("/health")

        app.dependency_overrides = original_overrides

        assert response.status_code == 200
        assert response.json()["database"] == "memory"


def test_logica_db():
    with patch("app.database.SessionLocal") as mock_session_local:
        mock_session = MagicMock()
        mock_session_local.return_value = mock_session

        generator = get_db()
        db_instance = next(generator)

        assert db_instance == mock_session
        generator.close()
        mock_session.close.assert_called_once()


def test_crear_nota_postgres_excepcion(monkeypatch):
    monkeypatch.setattr(main_module, "USE_MEMORY_DB", False)
    with patch("app.main.get_db") as mock_get_db:
        mock_session = MagicMock()
        mock_session.add.side_effect = Exception("Commit Fail")
        mock_get_db.return_value = iter([mock_session])

        orig = app.dependency_overrides.copy()
        app.dependency_overrides = {}
        response = client.post("/notes", json={"title": "Err", "content": "Err"})
        app.dependency_overrides = orig

        assert response.status_code == 200
