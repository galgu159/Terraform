FROM python:3.10-alpine
WORKDIR /usr/src/app
RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
ENV TELEGRAM_APP_URL="https://galgu.int-devops.click"
ENV BUCKET_NAME="galgu-bucket"
ENV DYNAMODB_TABLE_NAME="galgu-PolybotService-DynamoDB"
ENV S3_PREDICTED_URL="https://galgu-bucket.s3.eu-north-1.amazonaws.com/"
CMD ["python3", "app.py"]