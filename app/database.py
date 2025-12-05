from sqlalchemy import create_engine, Column, Integer, String, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# Configuracion de la base de datos
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@db:5432/notes_db")

# Para desarrollo local sin Docker
if "localhost" in os.getenv("DATABASE_URL", "") or os.getenv("LOCAL_DEV", "false") == "true":
    DATABASE_URL = "postgresql://user:password@localhost:5433/notes_db"

try:
    engine = create_engine(DATABASE_URL)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
except Exception as e:
    print(f"Advertencia: No se pudo crear el motor de base de datos: {e}")
    engine = None
    SessionLocal = None

Base = declarative_base()

# Modelo SQLAlchemy
class NoteDB(Base):
    __tablename__ = "notes"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    content = Column(Text)