# Dockerfile
FROM python:3.10-slim

WORKDIR /source

COPY /source/performance_score.py .

CMD ["python", "performance_score.py"]
