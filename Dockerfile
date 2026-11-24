FROM python:3.13-slim
WORKDIR /app

# TODO 1: copiar requirements.txt antes de app.py (aproveita a cache de camadas)
COPY requirements.txt .
# TODO 2: instalar as dependencias sem cache do pip (imagem mais pequena)
RUN pip install --no-cache-dir -r requirements.txt
# TODO 3: copiar apenas a aplicacao
COPY app.py .
# TODO 4: utilizador sem privilegios + /data com permissoes de escrita
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser \
    && mkdir -p /data \
    && chown appuser:appuser /data
# TODO 5: executar como utilizador nao root
USER appuser

EXPOSE 8000
CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
