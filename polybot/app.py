import flask
from flask import request, jsonify
import os
import boto3
import json

from bot import ObjectDetectionBot
from loguru import logger
from botocore.exceptions import ClientError


app = flask.Flask(__name__)


# return my secret from aws
def get_secret():

    secret_name = "galgu-bot_token"
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
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        raise e

    secret = get_secret_value_response['SecretString']
    print(secret)
    return secret


secret_json_str = get_secret()
if secret_json_str:
    secret_dict = json.loads(secret_json_str)
    TELEGRAM_TOKEN = secret_dict.get('galgu-bot_token-tf')
else:
    print("Failed to retrieve the secret")


def get_secret_url():

    secret_name = "galgu-TELEGRAM_APP_URL-tf"
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
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        raise e

    secret = get_secret_value_response['SecretString']
    print(secret)
    return secret


secret_json_str = get_secret()
if secret_json_str:
    secret_dict = json.loads(secret_json_str)
    TELEGRAM_APP_URL = secret_dict.get('TELEGRAM_APP_URL')
else:
    print("Failed to retrieve the secret")

print(TELEGRAM_TOKEN)
print(TELEGRAM_APP_URL)


def get_secret_dynamoDB():
    secret_name = "galgu-dynamodb_name-tf"
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
            secret_dict_dynamoDB = json.loads(secret)
            dynamodb_name = secret_dict_dynamoDB.get('dynamodb_name')
            return dynamodb_name
        else:
            logger.error("No secret string found")
    except ClientError as e:
        logger.error(f"Error retrieving DynamoDB secret {secret_name}: {e}")
        raise e

    return None


@app.route('/', methods=['GET'])
def index():
    return 'Ok'


@app.route(f'/{TELEGRAM_TOKEN}/', methods=['POST'])
def webhook():
    req = request.get_json()
    bot.handle_message(req['message'])
    return 'Ok'


@app.route(f'/results', methods=['POST'])
def results():
    region_name = os.environ['REGION']
    dynamodb_name = get_secret_dynamoDB()
    if not dynamodb_name:
        return 'DynamoDB name not found', 500

    dynamodb = boto3.resource('dynamodb', region_name=region_name)
    table = dynamodb.Table(dynamodb_name)

    logger.info("Received request at /results endpoint")
    try:
        prediction_id = flask.request.args.get('predictionId')
        if not prediction_id:
            prediction_id = flask.request.json.get('predictionId')

        if not prediction_id:
            return 'predictionId is required', 400
        response = table.get_item(Key={'prediction_id': prediction_id})
        if 'Item' in response:
            item = response['Item']
            chat_id = item['chat_id']
            labels = item['labels']
            unique_filename = item['unique_filename']

            text_results = f"Prediction results for image {item['original_img_path']}:\n"
            for label in labels:
                text_results += f"- {label['class']} at ({label['cx']:.2f}, {label['cy']:.2f}) with size ({label['width']:.2f}, {label['height']:.2f})\n"

            bot.send_text(chat_id, text_results)

            # file_name = os.path.basename(item['unique_filename'])
            # S3_PREDICTED_URL = "https://galgu-bucket.s3.eu-north-1.amazonaws.com/"
            # s3_full_url = f"{S3_PREDICTED_URL}{file_name}"

            # bot.send_text(chat_id, "You can download the predicted image here:")
            # bot.send_text(chat_id, s3_full_url)
            return 'Ok'
        else:
            return 'No results found', 404
    except Exception as e:
        print(f"Error processing results: {str(e)}")
        return 'Error', 500


@app.route('/health_checks/', methods=['GET'])
def health_checks():
    return 'Ok', 200


@app.route(f'/loadTest/', methods=['POST'])
def load_test():
    req = request.get_json()
    bot.handle_message(req['message'])
    return 'Ok'


if __name__ == "__main__":
    bot = ObjectDetectionBot(TELEGRAM_TOKEN, TELEGRAM_APP_URL)

    app.run(host='0.0.0.0', port=8443)
