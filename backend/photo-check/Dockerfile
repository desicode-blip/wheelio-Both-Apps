FROM python:3.12-slim-bookworm
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN python download_models.py
ENV PORT=8080 PYTHONUNBUFFERED=1
USER 65534:65534
CMD ["python", "server.py"]
