# Variables de entorno
EVIDENCE_DIR = .evidence
IMAGE_NAME = myapp:latest
K8S_NAMESPACE = default
K8S_DIR = k8s
PORT_FORWARD_PORT = 8080
# Flags comunes para pytest (puedes ampliarlas)
PYTEST_FLAGS ?= -q -v
PY_WARNINGS  ?= ignore::DeprecationWarning

# Lint (modo "relajado" por defecto para desarrollo)
LINT_MAX_LINE ?= 88
LINT_IGNORE   ?= E501,W391,W293
# Ignora F401 en reexport del __init__ y E402 solo en archivos de tests
LINT_PER_FILE ?= Actividades/mocking_objetos/models/__init__.py:F401,Actividades/*/tests/*.py:E402

# Ayuda

.PHONY: help
help: ## Mostrar ayuda
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':|##' '{printf "  %-20s %s\n", $$1, $$3}'

# Instalar dependencias

.PHONY: install ## Instalar dependencias
install:
	@echo "Instalando dependencias..."
	pip install -r requirements.txt
	@if [ -f requirements-dev.txt ]; then \
		echo "Instalando dependencias de desarrollo..."; \
		pip install -r requirements-dev.txt; \
	fi

# Lint / Formato (una sola diana)

.PHONY: lint
lint: ## Formatea (ruff), ordena imports (ruff I), autofix y pasa flake8 relajado
	@echo "Formateando con Ruff..."
	ruff format app tests
	@echo "Ordenando imports (Ruff rule I)..."
	ruff check app tests --select I --fix
	@echo "Autofix de reglas con Ruff (whitespace, etc.)..."
	ruff check app tests --fix
	@echo "Lint con flake8 (relajado: ignora $(LINT_IGNORE); ancho $(LINT_MAX_LINE))..."
	flake8 app/ tests/ \
	    --max-line-length=$(LINT_MAX_LINE) \
	    --extend-ignore=$(LINT_IGNORE) \
	    --per-file-ignores="$(LINT_PER_FILE)"
	@echo "Lint OK"

# Test
.PHONY: test test_all
test: ## Ejecuta pytest
	@echo "Ejecutando pruebas en tests:"
	cd tests/ && PYTHONWARNINGS="$(PY_WARNINGS)" pytest . $(PYTEST_FLAGS)
# Coverage
coverage: ## Ejecuta la cobertura
	@echo "Ejecutando cobertura"
	cd tests/ && PYTHONWARNINGS="$(PY_WARNINGS)" pytest --cov=. --cov-report=term-missing --cov-report=html:htmlcov . $(PYTEST_FLAGS); 

# Limpiar

.PHONY: clean
clean: ## Elimina archivos temporales, caches, etc.
	@echo "Eliminando archivos de caché y reportes..."
	# caches python/pytest
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache
	# coverage
	rm -rf .coverage htmlcov tests/htmlcov tests/.coverage 2>/dev/null || true
	coverage erase || true
	# ruff
	rm -rf .ruff_cache 2>/dev/null || true
	@echo "Limpieza completa."

.PHONY: coverage_reporte
coverage_reporte: 
	@mkdir -p $(EVIDENCE_DIR)
	@echo "Ejecutando cobertura..."
	PYTHONWARNINGS="$(PY_WARNINGS)" pytest --cov=app --cov-report=term-missing > $(EVIDENCE_DIR)/ci-report.txt
	@echo "Reporte de cobertura guardado en $(EVIDENCE_DIR)/ci-report.txt"

.PHONY: build
build: ## Construye la imagen Docker
	@echo "Construyendo imagen $(IMAGE_NAME)..."
	@docker build -t $(IMAGE_NAME) . || (echo "Error en build" && exit 1)
	@echo "Imagen $(IMAGE_NAME) construida exitosamente"

.PHONY: evidence
evidence: coverage_reporte lint ## Genera SBOM (Syft) y Escaneo (Trivy)
	@mkdir -p $(EVIDENCE_DIR)
	@echo "Verificando que la imagen $(IMAGE_NAME) existe"
	@docker image inspect $(IMAGE_NAME) >/dev/null 2>&1 || \
		(echo "Imagen $(IMAGE_NAME) no encontrada. Ejecutar 'make build' primero" && exit 1)
	@echo "Generando SBOM con Syft"
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $(PWD)/$(EVIDENCE_DIR):/evidence anchore/syft $(IMAGE_NAME) -o json > $(EVIDENCE_DIR)/sbom.json || \
		(echo "Error generando SBOM" && exit 1)
	@echo "SBOM generado: $(EVIDENCE_DIR)/sbom.json"
	@echo "Ejecutando escaneo de seguridad con Trivy..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $(PWD)/$(EVIDENCE_DIR):/evidence ghcr.io/aquasecurity/trivy:latest image --format json --output /evidence/trivy-report.json $(IMAGE_NAME) || \
		(echo "Error en escaneo Trivy" && exit 1)
	@echo "Scan completado: $(EVIDENCE_DIR)/trivy-report.json"
	@echo "Evidencias completadas en $(EVIDENCE_DIR)/"

.PHONY: full-evidence
full-evidence: build evidence ## Pipeline completo: Build + Test + Lint + Evidence
	@echo "Pipeline de evidencias completado exitosamente"
	@echo "Archivos generados:"
	@ls -lh $(EVIDENCE_DIR)/ | tail -n +2
	@echo "Resumen:"
	@echo "  - Cobertura: $(EVIDENCE_DIR)/ci-report.txt"
	@echo "  - SBOM: $$(wc -l < $(EVIDENCE_DIR)/sbom.json) líneas"
	@echo "  - Vulnerabilidades: $$(jq '[.Results[]?.Vulnerabilities[]?] | length' $(EVIDENCE_DIR)/trivy-report.json 2>/dev/null || echo 'N/A')"

.PHONY: k8s-start
k8s-start: ## Inicia Minikube
	@echo "Iniciando Minikube"
	minikube start
	@echo "Minikube iniciado exitosamente"
	@minikube status

.PHONY: k8s-stop
k8s-stop: ## Detiene Minikube
	@echo "Deteniendo Minikube"
	minikube stop
	@echo "Minikube detenido"

.PHONY: k8s-delete
k8s-delete: ## Elimina el cluster de Minikube
	@echo "Esto eliminará completamente el cluster de Minikube"
	@read -p "¿Estás seguro? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	minikube delete
	@echo "Cluster eliminado"

.PHONY: k8s-status
k8s-status: ## Muestra el estado de Minikube
	@minikube status

.PHONY: k8s-dashboard
k8s-dashboard: ## Abre el dashboard de Kubernetes
	@echo "Abriendo dashboard de Kubernetes"
	minikube dashboard

.PHONY: k8s-build
k8s-build: ## Construye la imagen en el daemon de Minikube
	@echo "Configurando Docker para usar Minikube"
	@eval $$(minikube docker-env) && docker build -t $(IMAGE_NAME) .
	@echo "Imagen $(IMAGE_NAME) construida en Minikube"
	@eval $$(minikube docker-env) && docker images | grep myapp

.PHONY: k8s-deploy
k8s-deploy: ## Despliega toda la aplicación en Kubernetes
	@echo "Desplegando aplicación en Kubernetes"
	@echo "[1/9] Aplicando Secret..."
	kubectl apply -f $(K8S_DIR)/secret.yaml
	@echo "[2/9] Aplicando ConfigMap..."
	kubectl apply -f $(K8S_DIR)/configmap.yaml
	@echo "[3/9] Creando PersistentVolumeClaim..."
	kubectl apply -f $(K8S_DIR)/postgres-pvc.yaml
	@echo "[4/9] Desplegando PostgreSQL..."
	kubectl apply -f $(K8S_DIR)/postgres-deployment.yaml
	@echo "[5/9] Creando Service de PostgreSQL..."
	kubectl apply -f $(K8S_DIR)/postgres-service.yaml
	@echo "[6/9] Esperando a que PostgreSQL esté listo (timeout: 120s)..."
	kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s || \
		(echo "PostgreSQL no está listo. Ver logs con: make k8s-logs-postgres" && exit 1)
	@echo "PostgreSQL listo"
	@echo "[7/9] Desplegando API..."
	kubectl apply -f $(K8S_DIR)/deployment.yaml
	@echo "[8/9] Creando Service de la API..."
	kubectl apply -f $(K8S_DIR)/service.yaml
	@echo "[9/9] Esperando a que la API esté lista (timeout: 120s)..."
	kubectl wait --for=condition=ready pod -l app=notes --timeout=120s || \
		(echo "API no está lista. Ver logs con: make k8s-logs-api" && exit 1)
	@echo "API lista"
	@echo "Despliegue completado exitosamente"
	@kubectl get all
	@echo "Para acceder a la aplicación, ejecuta: make k8s-port-forward"

.PHONY: k8s-deploy-all
k8s-deploy-all: k8s-start k8s-build k8s-deploy ## Pipeline completo: Start + Build + Deploy
	@echo "Pipeline completo de Kubernetes ejecutado exitosamente"

.PHONY: k8s-undeploy
k8s-undeploy: ## Elimina todos los recursos de Kubernetes
	@echo "Eliminando recursos de Kubernetes..."
	kubectl delete -f $(K8S_DIR)/ || true
	@echo "Recursos eliminados"
	@kubectl get all

.PHONY: k8s-port-forward
k8s-port-forward: ## Inicia port-forward para acceder a la aplicación (Ctrl+C para detener)
	@echo "Iniciando port-forward en http://localhost:$(PORT_FORWARD_PORT)"
	@echo "Presiona Ctrl+C para detener"
	kubectl port-forward service/notes-service $(PORT_FORWARD_PORT):80

.PHONY: k8s-status-all
k8s-status-all: ## Muestra el estado de todos los recursos
	@echo "Estado de recursos en Kubernetes"
	@echo "PODS:"
	@kubectl get pods
	@echo "SERVICES:"
	@kubectl get svc
	@echo "DEPLOYMENTS:"
	@kubectl get deployments
	@echo "PERSISTENT VOLUME CLAIMS:"
	@kubectl get pvc
	@echo "CONFIGMAPS & SECRETS:"
	@kubectl get configmaps,secrets | grep notes

.PHONY: k8s-logs-api
k8s-logs-api: ## Muestra los logs de la API
	@echo "Logs de la API (últimas 50 líneas):"
	@kubectl logs -l app=notes --tail=50

.PHONY: k8s-logs-postgres
k8s-logs-postgres: ## Muestra los logs de PostgreSQL
	@echo "Logs de PostgreSQL (últimas 50 líneas):"
	@kubectl logs -l app=postgres --tail=50

.PHONY: k8s-describe-api
k8s-describe-api: ## Describe el pod de la API
	@kubectl describe pod -l app=notes

.PHONY: k8s-describe-postgres
k8s-describe-postgres: ## Describe el pod de PostgreSQL
	@kubectl describe pod -l app=postgres

.PHONY: k8s-reset
k8s-reset: k8s-undeploy k8s-delete k8s-start ## Reset completo (elimina cluster y lo recrea)
	@echo "Reset completado - Cluster recreado"