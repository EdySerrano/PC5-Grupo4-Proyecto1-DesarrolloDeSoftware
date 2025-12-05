from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.database import get_db, create_tables, NoteDB
import os

app = FastAPI(
    title="Sistema de Gestión de Notas",
    description="API simple para gestión de notas - Práctica Calificada 5",
    version="1.0.0"
)

# Crear las tablas al inicio
create_tables()

# Modelo Pydantic para la API
class Note(BaseModel):
    id: int
    title: str
    content: str

class NoteCreate(BaseModel):
    title: str
    content: str

# Base de datos en memoria como fallback si PostgreSQL no esta disponible
notes_db: List[Note] = []
USE_MEMORY_DB = os.getenv("USE_MEMORY_DB", "false").lower() == "true"
