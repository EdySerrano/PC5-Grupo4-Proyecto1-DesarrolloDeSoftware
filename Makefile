# Variables de entorno
EVIDENCE_DIR = .evidence
IMAGE_NAME = myapp:latest
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