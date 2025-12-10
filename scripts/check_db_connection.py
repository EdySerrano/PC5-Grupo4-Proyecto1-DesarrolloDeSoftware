#!/usr/bin/env python3
"""
Script para verificar la conexion a la base de datos y crear datos de prueba
"""
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import create_tables, get_db, NoteDB
from sqlalchemy.orm import Session

def check_database_connection():
    """Verifica la conexion a la base de datos"""
    try:
        # Crear las tablas
        create_tables()
        print("Tablas creadas correctamente")
        
        # Obtener sesion de DB
        db = next(get_db())
        
        # Crear una nota de prueba
        test_note = NoteDB(
            title="Nota de prueba - Sprint 1",
            content="Esta es una nota creada para verificar la conexion a PostgreSQL"
        )
        db.add(test_note)
        db.commit()
        db.refresh(test_note)
        
        print(f"Nota creada con ID: {test_note.id}")
        
        # Listar todas las notas
        notes = db.query(NoteDB).all()
        print(f"Total de notas en la BD: {len(notes)}")
        
        for note in notes:
            print(f"  - ID: {note.id}, Titulo: {note.title}")
        
        db.close()
        return True
        
    except Exception as e:
        print(f"Error de conexion a la base de datos: {e}")
        return False

if __name__ == "__main__":
    print("Verificando conexion a PostgreSQL...")
    success = check_database_connection()
    if success:
        print("Conexion a base de datos exitosa")
    else:
        print("Fallo en la conexion a base de datos")
        sys.exit(1)
