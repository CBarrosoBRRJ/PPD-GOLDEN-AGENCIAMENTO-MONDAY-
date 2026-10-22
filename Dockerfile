# Imagem do Cloud Run Job gold-agenciamento: atualiza as tabelas gold uma vez e termina.
FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

# o job lê os SELECTs, esquemas e validações versionados em sql/
COPY job/ ./job/
COPY sql/ ./sql/

# roda sem privilégios de root
RUN useradd --create-home --uid 10001 appuser
USER appuser

# sai com código 1 se algo falhar -> o Cloud Run marca a execução como falha
ENTRYPOINT ["python", "job/main.py"]
