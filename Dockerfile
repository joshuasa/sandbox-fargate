FROM python:3.10.6-slim-bullseye

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY . ./

RUN pip install -r requirements.txt