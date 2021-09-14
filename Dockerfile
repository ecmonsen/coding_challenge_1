# syntax=docker/dockerfile:1
FROM python:3.8-alpine
WORKDIR /code
COPY ./src/ .
RUN pip install -r requirements.txt
CMD ["python", "etl.py"]
