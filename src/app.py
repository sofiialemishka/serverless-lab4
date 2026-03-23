import json
import os
import boto3
import psycopg2
import traceback
from datetime import datetime

DB_HOST = os.environ['DB_HOST']
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASS = os.environ['DB_PASS']
S3_BUCKET = os.environ['S3_BUCKET']

s3 = boto3.client('s3')

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, database=DB_NAME,
        user=DB_USER, password=DB_PASS
    )

def log_to_s3(event_data):
    key = f'logs/{datetime.now().strftime("%Y/%m/%d")}/{datetime.now().isoformat()}.json'
    s3.put_object(Bucket=S3_BUCKET, Key=key, Body=json.dumps(event_data))

def handler(event, context):
    print("EVENT:", json.dumps(event))
    try:
        req_ctx = event.get('requestContext', {})
        if 'http' in req_ctx:
            method = req_ctx['http']['method']
            path   = req_ctx['http']['path']
        else:
            method = req_ctx.get('httpMethod', event.get('httpMethod', 'GET'))
            path   = event.get('path', '/')

        print(f"METHOD: {method}, PATH: {path}")

        if method == 'POST' and '/grades' in path:
            body = json.loads(event.get('body') or '{}')
            conn = get_db_connection()
            cur  = conn.cursor()
            cur.execute(
                '''CREATE TABLE IF NOT EXISTS grades (
                    id SERIAL PRIMARY KEY,
                    student_id VARCHAR(50),
                    subject VARCHAR(100),
                    score NUMERIC,
                    created_at TIMESTAMP
                )'''
            )
            cur.execute(
                'INSERT INTO grades (student_id, subject, score, created_at)'
                ' VALUES (%s, %s, %s, %s) RETURNING id',
                (body['student_id'], body['subject'], body['score'], datetime.now())
            )
            grade_id = cur.fetchone()[0]
            conn.commit()
            cur.close()
            conn.close()
            log_to_s3({'action': 'POST /grades', 'id': grade_id})
            return {
                'statusCode': 201,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'id': grade_id, 'status': 'created'})
            }

        elif method == 'GET' and '/grades/student/' in path:
            student_id = path.split('/')[-1]
            conn = get_db_connection()
            cur  = conn.cursor()
            cur.execute(
                'SELECT id, subject, score, created_at FROM grades'
                ' WHERE student_id = %s ORDER BY created_at DESC',
                (student_id,)
            )
            rows = cur.fetchall()
            cur.close()
            conn.close()
            grades = [{'id': r[0], 'subject': r[1],
                       'score': float(r[2]),
                       'created_at': str(r[3])} for r in rows]
            avg = round(sum(g['score'] for g in grades) / len(grades), 2) if grades else 0
            log_to_s3({'action': 'GET /grades/student', 'student_id': student_id})
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'avg_score': avg, 'grades': grades})
            }

        return {'statusCode': 405, 'body': json.dumps({'message': 'Method Not Allowed'})}

    except Exception as e:
        print("ERROR:", traceback.format_exc())
        return {'statusCode': 500, 'body': json.dumps({'message': str(e)})}