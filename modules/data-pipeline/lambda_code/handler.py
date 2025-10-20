import boto3 # type: ignore 
import io
import json
import urllib.parse
import pyarrow as pa # type: ignore 
import pyarrow.csv as pv # type: ignore 
import pyarrow.parquet as pq # type: ignore 

s3 = boto3.client("s3")

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    # Step 1: Get SQS message body
    body = event['Records'][0]['body']
    body_json = json.loads(body)

    # Step 2: Extract SNS message if needed
    if "Message" in body_json:
        sns_message = json.loads(body_json["Message"])
    else:
        sns_message = body_json

    # Step 3: Extract S3 bucket/key
    s3_record = sns_message["Records"][0]["s3"]
    bucket = s3_record["bucket"]["name"]
    key = urllib.parse.unquote_plus(s3_record["object"]["key"])
    print(f"Processing file: s3://{bucket}/{key}")

    # Step 4: Read CSV from S3
    obj = s3.get_object(Bucket=bucket, Key=key)
    csv_bytes = obj['Body'].read()

    # Step 5: Convert CSV → Arrow Table → Parquet
    table = pv.read_csv(io.BytesIO(csv_bytes))
    buf = io.BytesIO()
    pq.write_table(table, buf)

    # Step 6: Write Parquet back to S3
    new_key = key.replace("raw-data/", "processed-data/").replace(".csv", ".parquet")
    s3.put_object(Bucket=bucket, Key=new_key, Body=buf.getvalue())

    print(f"Wrote Parquet to: s3://{bucket}/{new_key}")
    return {"status": "ok", "output_key": new_key}
