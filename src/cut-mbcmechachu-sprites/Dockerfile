#syntax=docker/dockerfile:1.4

FROM python:3 AS app

WORKDIR /usr/src/app

COPY requirements.txt ./

RUN apt-get update \
    && apt-get install libmagickwand-dev

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["bash"]

FROM app AS app_dev

COPY requirements-dev.txt ./

RUN pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt

COPY . .

CMD ["bash"]