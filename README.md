# PC5-Grupo4-Proyecto1-DesarrolloDeSoftware

## Equipo 4:

| Miembro del Equipo | Codigo |
| :----------------- | :-------------------- |
| **Choquecambi Germain** | `20211360A` |
| **Serrano Edy** | `20211229B` | 
| **Hinojosa Frank** | `20210345I`  | 

## Descripción del Proyecto
**Proyecto 1 - "Local Secure Stack para notas de estudiantes"**

Sistema de Gestión de Notas desarrollado con FastAPI y PostgreSQL. El proyecto incluye configuraciones para Docker Compose y Kubernetes, permitiendo despliegues flexibles en diferentes entornos.


## Tecnologías Utilizadas

- **Backend:** FastAPI (Python)
- **Base de Datos:** PostgreSQL 15 Alpine
- **ORM:** SQLAlchemy
- **Contenedores:** Docker & Docker Compose
- **Orquestación:** Kubernetes (Minikube)
- **Testing:** Pytest

---

## Estructura del Proyecto

```
.
├── app/
│   ├── __init__.py
│   ├── main.py              # Endpoints de la API
│   └── database.py          # Configuración de la BD
├── k8s/
│   ├── configmap.yaml       # Variables de configuración
│   ├── secret.yaml          # Credenciales (base64)
│   ├── deployment.yaml      # Deployment de la API
│   ├── service.yaml         # Service de la API
│   ├── postgres-pvc.yaml    # Almacenamiento persistente
│   ├── postgres-deployment.yaml  # Deployment de PostgreSQL
│   └── postgres-service.yaml     # Service de PostgreSQL
├── tests/
│   ├── __init__.py
│   └── test_main.py
├── scripts/
│   ├── check_db_connection.py
│   └── verify_deploy.py
├── docker-compose.yml
├── Dockerfile
├── Makefile
├── requirements.txt
└── README.md
```

---

## Comandos del Makefile

El proyecto incluye un Makefile con comandos para desarrollo, testing, build y Kubernetes.

### Comandos Generales

| Comando | Descripción |
|---------|-------------|
| `make help` | Mostrar todos los comandos disponibles |
| `make install` | Instalar dependencias de Python |
| `make lint` | Formatear código con Ruff y validar con flake8 |
| `make test` | Ejecutar pruebas con pytest |
| `make coverage` | Ejecutar pruebas con reporte de cobertura |
| `make clean` | Eliminar archivos temporales y caché |

### Comandos de Docker

| Comando | Descripción |
|---------|-------------|
| `make build` | Construir imagen Docker |
| `make evidence` | Generar SBOM (Syft) y escaneo de seguridad (Trivy) |
| `make full-evidence` | Pipeline completo: Build + Test + Lint + Evidence |

### Comandos de Kubernetes

| Comando | Descripción |
|---------|-------------|
| `make k8s-deploy-all` | **Pipeline completo: Inicia Minikube + Construye imagen + Despliega (RECOMENDADO)** |
| `make k8s-start` | Iniciar Minikube |
| `make k8s-stop` | Detener Minikube |
| `make k8s-delete` | Eliminar cluster de Minikube |
| `make k8s-status` | Ver estado de Minikube |
| `make k8s-dashboard` | Abrir dashboard de Kubernetes |
| `make k8s-build` | Construir imagen en el daemon de Minikube |
| `make k8s-deploy` | Desplegar toda la aplicación (requiere Minikube iniciado) |
| `make k8s-undeploy` | Eliminar todos los recursos de Kubernetes |
| `make k8s-port-forward` | Iniciar port-forward para acceder a la aplicación |
| `make k8s-status-all` | Mostrar estado de todos los recursos (pods, services, etc) |
| `make k8s-logs-api` | Ver logs de la API |
| `make k8s-logs-postgres` | Ver logs de PostgreSQL |
| `make k8s-describe-api` | Describir el pod de la API |
| `make k8s-describe-postgres` | Describir el pod de PostgreSQL |
| `make k8s-reset` | Reset completo: elimina recursos, borra cluster y lo recrea |


---

## Instrucciones de Uso

### Clonar el Repositorio

```bash
git clone https://github.com/EdySerrano/PC5-Grupo4-Proyecto1-DesarrolloDeSoftware.git
cd PC5-Grupo4-Proyecto1-DesarrolloDeSoftware
```

---

## Despliegue con Docker Compose

### Prerequisitos
- Docker
- Docker Compose

### Pasos

1. **Iniciar los servicios:**
   ```bash
   docker-compose up --build
   ```

2. **Acceder a la API:**
   ```bash
   curl http://localhost:8000/health
   ```

3. **Detener los servicios:**
   ```bash
   docker-compose down
   ```

---

## Despliegue con Kubernetes

### Prerequisitos

- Minikube
- kubectl
- Docker

### Instalación de Minikube y kubectl (Linux)

```bash
# Instalar Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verificar instalación
minikube version
kubectl version --client
```

### Despliegue Rápido con Makefile - Recomendado

**Pipeline Completo Automatizado:**

```bash
make k8s-deploy-all
```

Este comando ejecuta automáticamente:
1. Inicia Minikube
2. Construye la imagen Docker en Minikube
3. Despliega todos los recursos (PostgreSQL + API)
4. Espera a que todo esté listo

#### Acceder a la Aplicación

```bash
# Iniciar port-forward (presiona Ctrl+C para detener)
make k8s-port-forward
```

#### Ver Estado y Logs

```bash
# Ver estado de todos los recursos
make k8s-status-all

# Ver logs de la API
make k8s-logs-api

# Ver logs de PostgreSQL
make k8s-logs-postgres
```

#### Limpieza

```bash
# Eliminar todos los recursos
make k8s-undeploy

# Detener Minikube
make k8s-stop

# Reset completo (elimina y recrea cluster)
make k8s-reset
```

---

### Pasos de Despliegue Manual - Alternativa

#### 1. Iniciar Minikube

```bash
# Iniciar el cluster
minikube start

# Verificar estado
minikube status
```

#### 2. Construir la Imagen Docker

```bash
# Configurar Docker para usar el daemon de Minikube
eval $(minikube docker-env)

# Construir la imagen
docker build -t myapp:latest .

# Verificar
docker images | grep myapp
```

#### 3. Aplicar Manifiestos (EN ORDEN)

```bash
# 1. Secret (credenciales)
kubectl apply -f k8s/secret.yaml

# 2. ConfigMap (configuración)
kubectl apply -f k8s/configmap.yaml

# 3. PersistentVolumeClaim (almacenamiento)
kubectl apply -f k8s/postgres-pvc.yaml

# 4. PostgreSQL Deployment
kubectl apply -f k8s/postgres-deployment.yaml

# 5. PostgreSQL Service
kubectl apply -f k8s/postgres-service.yaml

# 6. Esperar a que PostgreSQL esté listo
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s

# 7. API Deployment
kubectl apply -f k8s/deployment.yaml

# 8. API Service
kubectl apply -f k8s/service.yaml

# 9. Esperar a que la API esté lista
kubectl wait --for=condition=ready pod -l app=notes --timeout=120s
```

#### 4. Verificar el Despliegue

```bash
# Ver todos los recursos
kubectl get all

# Ver los pods
kubectl get pods

# Ver los servicios
kubectl get svc

# Ver logs de la API
kubectl logs -l app=notes --tail=20

# Ver logs de PostgreSQL
kubectl logs -l app=postgres --tail=20
```

#### 5. Acceder a la Aplicación

```bash
# Iniciar port-forward
kubectl port-forward service/notes-service 8080:80 &

# Esperar 2 segundos
sleep 2

# Verificar health check
curl http://localhost:8080/health
```

**Respuesta esperada:**
```json
{"status":"ok","database":"postgresql"}
```

---

## API Endpoints

### Health Check
```bash
curl http://localhost:8080/health
```

### Crear una Nota
```bash
curl -X POST http://localhost:8080/notes \
  -H "Content-Type: application/json" \
  -d '{"title":"Mi nota","content":"Contenido de ejemplo"}'
```

**Respuesta:**
```json
{"id":1,"title":"Mi nota","content":"Contenido de la nota"}
```

### Listar Todas las Notas
```bash
curl http://localhost:8080/notes
```

**Respuesta:**
```json
[
  {"id":1,"title":"Mi nota","content":"Contenido de la nota"},
  {"id":2,"title":"Otra nota","content":"Otro contenido"}
]
```

### Obtener una Nota Específica
```bash
curl http://localhost:8080/notes/1
```

---

## Pruebas de Persistencia

### Verificar que los datos persisten después de reiniciar pods:

```bash
# 1. Crear algunas notas
curl -X POST http://localhost:8080/notes \
  -H "Content-Type: application/json" \
  -d '{"title":"Nota de prueba","content":"Verificar persistencia"}'

# 2. Eliminar el pod de la API (simular crash)
kubectl delete pod -l app=notes

# 3. Esperar a que se recree
kubectl wait --for=condition=ready pod -l app=notes --timeout=60s

# 4. Reiniciar port-forward
pkill -f "port-forward"
kubectl port-forward service/notes-service 8080:80 &
sleep 2

# 5. Verificar que los datos siguen ahí
curl http://localhost:8080/notes
```

Las notas deben seguir existiendo - Lo que confirma que PostgreSQL está persistiendo los datos correctamente.

---
