FROM python:3.12-slim

RUN groupadd -r openclaw && useradd -r -g openclaw -m openclaw

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY dashboard.py .
COPY templates/ templates/

RUN chown -R openclaw:openclaw /app

USER openclaw

EXPOSE 7842

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:7842/api/status')" || exit 1

CMD ["python", "dashboard.py"]
