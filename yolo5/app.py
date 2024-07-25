import json
import time
from pathlib import Path
import boto3
import requests
from botocore.exceptions import ClientError
from detect import run
import uuid
import yaml
from loguru import logger
import os
import logging
from decimal import Decimal
from bson import json_util

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

region_name = os.environ.get("AWS_REGION")
# Queue Name
queue_name = f"galgu-PolybotServiceQueue-{region_name}"
logger.info(f"Queue Name: {queue_name}")
# Dynamically create DynamoDB table name using f-string
DYNAMODB_NAME = f"galgu-PolybotService-DynamoDB-tf-{region_name}"
# Print DynamoDB name for verification
logger.info(f"DynamoDB Name: {DYNAMODB_NAME}")
# Bucket create DynamoDB table name using f-string
images_bucket = f"galgu-bucket-{region_name}"
# Print DynamoDB name for verification
logger.info(f"bucket Name: {images_bucket}")

print(images_bucket)

with open("data/coco128.yaml", "r") as stream:
    names = yaml.safe_load(stream)['names']


def consume():
    # The function runs in an infinite loop, continually polling the SQS queue for new messages.
    while True:
        sqs_client = boto3.client('sqs', region_name=region_name)
        # Receive Message from SQS
        response = sqs_client.receive_message(QueueUrl=queue_name, MaxNumberOfMessages=1, WaitTimeSeconds=5)
        # Check for Messages:
        if 'Messages' in response:
            # Extract message details
            message_body = response['Messages'][0]['Body']
            receipt_handle = response['Messages'][0]['ReceiptHandle']
            # Parses the message body from JSON format to a Python dictionary and retrieves the message ID
            message = json.loads(message_body)
            prediction_id = response['Messages'][0]['MessageId']
            logger.info(f'Prediction: {prediction_id}. Start processing')
            # Retrieve Chat ID and Image Name
            chat_id = message.get('chat_id')
            logger.info(f'chat_id !!!!!!!!!!!!!!!!!!!!!!      : {chat_id}. ')
            img_name = message.get('imgName')
            if not img_name or not chat_id:
                logger.error('Invalid message format: chat_id or imgName missing')
                sqs_client.delete_message(QueueUrl=queue_name, ReceiptHandle=receipt_handle)
                continue

            logger.info(f'img_name received: {img_name}')
            photo_s3_name = img_name.split("/")
            file_path_pic_download = os.path.join(os.getcwd(), photo_s3_name[1])
            logger.info(f'Download path: {file_path_pic_download}')
            # Download Image from S3
            s3_client = boto3.client('s3')
            s3_client.download_file(images_bucket, photo_s3_name[1], file_path_pic_download)

            original_img_path = file_path_pic_download
            logger.info(f'Prediction: {prediction_id}{original_img_path}. Download img completed')
            # Predicts the objects in the image
            run(
                weights='yolov5s.pt',
                data='data/coco128.yaml',
                source=original_img_path,
                project='static/data',
                name=prediction_id,
                save_txt=True
            )

            logger.info(f'prediction: {prediction_id}/{original_img_path}. done')

            # This is the path for the predicted image with labels
            # The predicted image typically includes bounding boxes drawn around the detected objects, along with class labels and possibly confidence scores.
            # predicted_img_path = Path('static') / 'data' / prediction_id / Path(original_img_path).name
            predicted_img_path = Path(f'static/data/{prediction_id}/{str(photo_s3_name[1])}')
            logger.info(f'predicted_img_path: {predicted_img_path}.')
            # Upload predicted image to S3
            unique_filename = str(uuid.uuid4()) + '.jpeg'
            s3_client.upload_file(str(predicted_img_path), images_bucket, unique_filename)
            logger.info("upload to s3.")
            # Parse prediction labels and create a summary
            #pred_summary_path = Path(f'static/data/{prediction_id}/labels/{original_img_path.split(".")[0]}.txt')
            pred_summary_path = Path(f'static/data/{prediction_id}/labels/{photo_s3_name[1].split(".")[0]}.txt')
            logger.info(f'pred_summary_path: {pred_summary_path}.')
            if pred_summary_path.exists():
                with open(pred_summary_path) as f:
                    labels = f.read().splitlines()
                    labels = [line.split(' ') for line in labels]
                    labels = [{
                        'class': names[int(l[0])],
                        'cx': Decimal(l[1]),
                        'cy': Decimal(l[2]),
                        'width': Decimal(l[3]),
                        'height': Decimal(l[4]),
                    } for l in labels]

                logger.info(f'prediction: {prediction_id}/{original_img_path}. prediction summary:\n\n{labels}')
                chat_id = str(chat_id)  # Convert chat_id to string
                prediction_summary = {
                    'prediction_id': prediction_id,
                    'chat_id': chat_id,
                    'original_img_path': original_img_path,
                    'predicted_img_path': str(predicted_img_path),
                    'labels': labels,
                    'unique_filename': unique_filename,
                    'time': Decimal(time.time())
                }

                # TODO store the prediction_summary in a DynamoDB table
                # TODO perform a GET request to Polybot to `/results` endpoint
                # Store the prediction_summary in a DynamoDB table
                dynamodb = boto3.resource('dynamodb', region_name=region_name)
                table = dynamodb.Table(DYNAMODB_NAME)
                logger.info(f"DynamoDB Table: {table}")
                table.put_item(Item=prediction_summary)

                # Send the message from my yolo5 to load balancer:
                POLYBOT_RESULTS_URL = "https://galgu.int-devops.click/results"
                try:
                    response = requests.post(f'{POLYBOT_RESULTS_URL}', params={'predictionId': prediction_id})
                    response.raise_for_status()  # Raise an error for bad status codes
                    logger.info(f'prediction: {prediction_id}. Notified Polybot microservice successfully')
                except requests.exceptions.RequestException as e:
                    logger.error(f'prediction: {prediction_id}. Failed to notify Polybot microservice. Error: {str(e)}')
                    if response is not None:
                        logger.error(f'Response status code: {response.status_code}')
                        logger.error(f'Response text: {response.text}')
            else:
                logger.error(f'Prediction: {prediction_id}{original_img_path}. prediction result not found')
                sqs_client.delete_message(QueueUrl=queue_name, ReceiptHandle=receipt_handle)
                continue

            # Delete the message from the queue as the job is considered as DONE
            sqs_client.delete_message(QueueUrl=queue_name, ReceiptHandle=receipt_handle)


if __name__ == "__main__":
    consume()
