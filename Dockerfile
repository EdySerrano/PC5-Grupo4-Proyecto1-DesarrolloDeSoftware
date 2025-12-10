# Imagen base oficial de Python
FROM python:3.9-slim

# Instalar curl para healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Directorio de trabajo
WORKDIR /app

# Copiar dependencias e instalar
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el codigo fuente
COPY . .

# Crear usuario no-root
RUN useradd -m appuser
USER appuser

# Exponer puerto
EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3   CMD curl -f http://localhost:8000/health || exit 1

# Correr la app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]