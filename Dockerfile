FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
WORKDIR /app
COPY api/requirements.txt api/requirements.txt
RUN pip install --no-cache-dir -r api/requirements.txt
COPY api api
COPY model model
COPY data data
EXPOSE 8080
CMD ["sh", "-c", "gunicorn --chdir api --bind 0.0.0.0:${PORT} --workers 2 --threads 4 --timeout 120 app:app"]
