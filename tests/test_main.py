import os
from fastapi.testclient import TestClient
from app.main import app

os.environ["USE_MEMORY_DB"] = "true"

client = TestClient(app)
