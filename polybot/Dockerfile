FROM python:3.10-alpine
WORKDIR /usr/src/app
RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
ENV REGION="us-east-2"
CMD ["python3", "app.py"]