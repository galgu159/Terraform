import flask
from flask import request, jsonify
import os
import boto3
import json

from bot import ObjectDetectionBot
from loguru import logger
from botocore.exceptions import ClientError


app = flask.Flask(__name__)
region_name = os.environ.get("AWS_REGION")
logger.info(f"Using AWS Region: {region_name}")
# Dynamically create DynamoDB table name using f-string
DYNAMODB_NAME = f"galgu-PolybotService-DynamoDB-tf-{region_name}"
# Print DynamoDB name for verification
logger.info(f"DynamoDB Name: {DYNAMODB_NAME}")

# return my secret from aws
def get_secret():

    secret_name = "telegram_token"
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
    print("secret token without cut:")
    print(secret)
    return secret


secret_json_str = get_secret()
if secret_json_str:
    secret_dict = json.loads(secret_json_str)
    TELEGRAM_TOKEN = secret_dict.get('telegram_token')
else:
    print("Failed to retrieve the secret")



print("with cut:")
print(TELEGRAM_TOKEN)

TELEGRAM_APP_URL="https://galgu.int-devops.click"
print(TELEGRAM_APP_URL)

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
    dynamodb = boto3.resource('dynamodb', region_name=region_name)
    table = dynamodb.Table(DYNAMODB_NAME)

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
