FROM python:3.10-slim
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8

WORKDIR /parent
COPY requirements.txt ./requirements.txt
COPY Pipfile ./Pipfile
COPY Pipfile.lock ./Pipfile.lock

RUN apt-get update \
    && apt-get install g++ -y \
    && apt-get install gcc -y \
    && apt-get install -y default-libmysqlclient-dev \
    && apt-get clean && \
    pip3 install -r requirements.txt && \
    mkdir -p /root/.streamlit && \
    mkdir -p /root/.streamlit && \
    cp .streamlit/config.toml /root/.streamlit && \
    bash -c 'echo -e "\
    [general]\n\
    email = \"\"\n\
    headless = true\n\
    " > /root/.streamlit/credentials.toml'

COPY app ./app
EXPOSE 8501

ENV PYTHONPATH /parent

ENTRYPOINT ["streamlit", "run"]
CMD ["app/main/python/ui/dashboard.py"]