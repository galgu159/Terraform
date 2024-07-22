import json
import os
import time
import logging
import boto3
import requests
import uuid
import telebot
from loguru import logger
from telebot.types import InputFile
from img_proc import Img
from botocore.exceptions import ClientError

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
region_name = os.environ['REGION']


def get_secret_Queue():
    secret_name = "galgu-sqs_queue_name-tf"
    region_name = os.environ.get("AWS_REGION")

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
        secret = get_secret_value_response.get('SecretString')
        if secret:
            secret_dict_Queue = json.loads(secret)
            Queue_name = secret_dict_Queue.get('sqs_queue_name')
            return Queue_name
        else:
            logger.error("No secret string found")
    except ClientError as e:
        logger.error(f"Error retrieving Queue secret {secret_name}: {e}")
        raise e
    return None


def get_secret_Bucket():
    secret_name = "galgu-bucket_name-tf"
    region_name = os.environ.get("AWS_REGION")

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
        secret = get_secret_value_response.get('SecretString')
        if secret:
            secret_dict_Queue = json.loads(secret)
            Queue_name = secret_dict_Queue.get('bucket_name')
            return Queue_name
        else:
            logger.error("No secret string found")
    except ClientError as e:
        logger.error(f"Error retrieving Bucket secret {secret_name}: {e}")
        raise e
    return None



class Bot:

    def __init__(self, token, telegram_chat_url):
        # create a new instance of the TeleBot class.
        # all communication with Telegram servers are done using self.telegram_bot_client
        self.telegram_bot_client = telebot.TeleBot(token)

        # remove any existing webhooks configured in Telegram servers
        self.telegram_bot_client.remove_webhook()
        time.sleep(0.5)

        # set the webhook URL
        self.telegram_bot_client.set_webhook(url=f'{telegram_chat_url}/{token}/', timeout=60)

        logger.info(f'Telegram Bot information\n\n{self.telegram_bot_client.get_me()}')

    def send_text(self, chat_id, text):
        self.telegram_bot_client.send_message(chat_id, text)

    def send_text_with_quote(self, chat_id, text, quoted_msg_id):
        self.telegram_bot_client.send_message(chat_id, text, reply_to_message_id=quoted_msg_id)

    def is_current_msg_photo(self, msg):
        return 'photo' in msg

    def download_user_photo(self, msg):
        """
        Downloads the photos that sent to the Bot to `photos` directory (should be existed)
        :return:
        """
        if not self.is_current_msg_photo(msg):
            raise RuntimeError(f'Message content of type \'photo\' expected')

        file_info = self.telegram_bot_client.get_file(msg['photo'][-1]['file_id'])
        data = self.telegram_bot_client.download_file(file_info.file_path)
        folder_name = file_info.file_path.split('/')[0]

        if not os.path.exists(folder_name):
            os.makedirs(folder_name)

        with open(file_info.file_path, 'wb') as photo:
            photo.write(data)

        return file_info.file_path

    def send_photo(self, chat_id, img_path):
        if not os.path.exists(img_path):
            raise RuntimeError("Image path doesn't exist")

        self.telegram_bot_client.send_photo(
            chat_id,
            InputFile(img_path)
        )

    def handle_message(self, msg):
        """Bot Main message handler"""
        logger.info(f'Incoming message: {msg}')
        self.send_text(msg['chat']['id'], f'Your original message: {msg["text"]}')


class ObjectDetectionBot(Bot):
    def handle_message(self, msg):
        """Bot Main message handler"""
        logger.info(f'Incoming message: {msg}')
        if "text" in msg:
            self.send_text(msg['chat']['id'], f'Your original message: {msg["text"]}')
        else:
            # if there is checkbox caption
            if "caption" in msg:
                try:
                    img_path = self.download_user_photo(msg)
                    if msg["caption"] == "Blur":
                        # Send message to telegram bot
                        self.send_text(msg['chat']['id'], "Blur filter in progress")
                        new_img = Img(img_path)
                        new_img.blur()
                        new_path = new_img.save_img()
                        self.send_photo(msg["chat"]["id"], new_path)
                        self.send_text(msg['chat']['id'], "Blur filter applied")
                    elif msg["caption"] == "Contour":
                        self.send_text(msg['chat']['id'], "Contour filter in progress")
                        new_img = Img(img_path)
                        new_img.contour()
                        new_path = new_img.save_img()
                        self.send_photo(msg["chat"]["id"], new_path)
                        self.send_text(msg['chat']['id'], "Contour filter applied")
                    elif msg["caption"] == "Salt and pepper":  # concat, segment
                        self.send_text(msg['chat']['id'], "salt_n_pepper filter in progress")
                        new_img = Img(img_path)
                        new_img.salt_n_pepper()
                        new_path = new_img.save_img()
                        self.send_photo(msg["chat"]["id"], new_path)
                        self.send_text(msg['chat']['id'], "salt_n_pepper filter applied")
                    elif msg["caption"] == "mix":
                        self.send_text(msg['chat']['id'], "mix filter in progress")
                        new_img = Img(img_path)
                        new_img.salt_n_pepper()
                        new_path = new_img.save_img()

                        new_img2 = Img(new_path)
                        new_img2.blur()
                        new_path = new_img2.save_img()

                        self.send_photo(msg["chat"]["id"], new_path)
                        self.send_text(msg['chat']['id'], "mix filter applied")
                    elif msg["caption"] == "predict":
                        self.send_text(msg['chat']['id'], "Your image is being processed. Please wait...")
                        logger.info(f'Photo downloaded to: {img_path}')
                        # Create an env of queue name
                        queue_name = get_secret_Queue()
                        # Split photo name
                        photo_s3_name = img_path.split("/")

                        # Get the bucket name from secret in aws
                        images_bucket = get_secret_Bucket()

                        # Upload the image to S3
                        s3_client = boto3.client('s3')
                        s3_client.upload_file(img_path, images_bucket, photo_s3_name[-1])

                        # Prepare the data to be sent to SQS
                        prediction_id = str(uuid.uuid4())
                        json_data = {
                            'imgName': img_path,
                            'chat_id': msg['chat']['id'],
                            'prediction_id': prediction_id
                        }

                        try:
                            # Send job to queue
                            sqs = boto3.client('sqs', region_name=region_name)
                            # Retrieve the queue URL
                            try:
                                response = sqs.get_queue_url(QueueName=queue_name)
                                sqs_queue_url = response['QueueUrl']
                                logger.info(f'Queue URL for {queue_name} is {sqs_queue_url}')
                            except sqs.exceptions.QueueDoesNotExist:
                                logger.error(f'Queue {queue_name} does not exist.')
                                raise
                            response = sqs.send_message(
                                QueueUrl=sqs_queue_url,
                                MessageBody=json.dumps(json_data)
                            )
                            self.send_text(msg['chat']['id'], f"Job sent to queue. PredictionId: {prediction_id}")
                        except Exception as e:
                            logger.error(f'Error: {str(e)}')
                            self.send_text(msg.chat.id, 'Failed to process the image. Please try again later.')
                    else:
                        self.send_text(msg['chat']['id'], "Error invalid caption\n Available captions are :\n 1)Blur\n2)mix\n3)Salt and pepper\n 4)predict")
                except Exception as e:
                    logger.info(f"Error {e}")
                    self.send_text(msg['chat']['id'], f'failed - try again later')
            else:
                self.send_text(msg['chat']['id'], "please provide caption")