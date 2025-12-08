import os

from sqlalchemy import Column, Integer, String, Text, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Configuracion de la base de datos
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@db:5432/notes_db")

# Para desarrollo local sin Docker
if (
    "localhost" in os.getenv("DATABASE_URL", "")
    or os.getenv("LOCAL_DEV", "false") == "true"
):
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


# Crear las tablas
def create_tables():
    if engine:
        try:
            Base.metadata.create_all(bind=engine)
        except Exception as e:
            print(f"Advertencia: No se pudo crear las tablas: {e}")


# Dependency para obtener la sesiOn de DB
def get_db():
    if SessionLocal:
        db = SessionLocal()
        try:
            yield db
        except Exception as e:
            print(f"Database error: {e}")
            yield None
        finally:
            if db:
                db.close()
    else:
        yield None
