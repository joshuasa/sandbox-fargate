import base64
from cmath import log
import boto3
import gzip
import json
import logging

from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def logpayload(event):

    logger.setLevel(logging.DEBUG)
    logger.debug(event['awslogs']['data'])
    compressed_payload = base64.b64decode(event['awslogs']['data'])
    uncompressed_payload = gzip.decompress(compressed_payload)
    log_payload = json.loads(uncompressed_payload)

    return log_payload


def error_details(payload):

    error_msg = ''
    log_events = payload['logEvents']


def lambda_handler(event, context):

    pload = logpayload(event)
    lgroup, lstream, errmessage, lambdaname = error_details(pload)