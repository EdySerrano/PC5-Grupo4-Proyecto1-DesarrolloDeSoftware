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

@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    # Verificar si tenemos conexión a PostgreSQL
    if USE_MEMORY_DB or db is None:
        return {"status": "ok", "database": "memory"}
    
    try:
        # Probar una consulta simple para verificar la conexion
        db.execute(text("SELECT 1"))
        return {"status": "ok", "database": "postgresql"}
    except Exception as e:
        print(f"Database health check error: {e}")
        return {"status": "ok", "database": "memory"}

@app.get("/notes", response_model=List[Note])
def get_notes(db: Session = Depends(get_db)):
    if USE_MEMORY_DB or db is None:
        return notes_db
    
    try:
        db_notes = db.query(NoteDB).all()
        return [Note(id=note.id, title=note.title, content=note.content) for note in db_notes]
    except Exception as e:
        print(f"Database error: {e}")
        # Fallback a memoria si hay problemas con la DB
        return notes_db

@app.post("/notes", response_model=Note)
def create_note(note: NoteCreate, db: Session = Depends(get_db)):
    if USE_MEMORY_DB or db is None:
        # Generar ID simple para memoria
        new_id = len(notes_db) + 1
        new_note = Note(id=new_id, title=note.title, content=note.content)
        notes_db.append(new_note)
        return new_note
    
    try:
        # Crear en PostgreSQL
        db_note = NoteDB(title=note.title, content=note.content)
        db.add(db_note)
        db.commit()
        db.refresh(db_note)
        return Note(id=db_note.id, title=db_note.title, content=db_note.content)
    except Exception as e:
        print(f"Database error: {e}")
        # Fallback a memoria si hay problemas con la DB
        new_id = len(notes_db) + 1
        new_note = Note(id=new_id, title=note.title, content=note.content)
        notes_db.append(new_note)
        return new_note

@app.get("/notes/{note_id}", response_model=Note)
def get_note_detail(note_id: int, db: Session = Depends(get_db)):
    if USE_MEMORY_DB or db is None:
        for note in notes_db:
            if note.id == note_id:
                return note
        raise HTTPException(status_code=404, detail="Note not found")
    
    try:
        db_note = db.query(NoteDB).filter(NoteDB.id == note_id).first()
        if db_note:
            return Note(id=db_note.id, title=db_note.title, content=db_note.content)
        raise HTTPException(status_code=404, detail="Note not found")
    except Exception as e:
        print(f"Database error: {e}")
        # Fallback a memoria
        for note in notes_db:
            if note.id == note_id:
                return note
        raise HTTPException(status_code=404, detail="Note not found")