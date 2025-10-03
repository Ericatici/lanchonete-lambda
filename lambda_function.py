import json
import os
import pymysql
from datetime import datetime

def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError ("Type %s not serializable" % type(obj))

def lambda_handler(event, context):
    db_host = os.environ.get("DB_HOST")
    db_name = os.environ.get("DB_NAME")
    db_user = os.environ.get("DB_USER")
    db_password = os.environ.get("DB_PASSWORD")

    if not all([db_host, db_name, db_user, db_password]):
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Database environment variables not configured."})
        }

    print(f"Attempting to connect to DB: {db_host}/{db_name} with user {db_user}")

    try:
        body = json.loads(event["body"])
        cpf = body.get("cpf")

        if not cpf:
            print("CPF is missing from the request body.")
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "CPF is required."})
            }

        connection = pymysql.connect(
            host=db_host,
            user=db_user,
            password=db_password,
            database=db_name,
            cursorclass=pymysql.cursors.DictCursor
        )
        print("Successfully connected to the database.")

        with connection.cursor() as cursor:
            # Changed table name from 'Customer' to 'customers' based on init.sql
            sql = "SELECT * FROM customers WHERE cpf = %s"
            print(f"Executing query: {sql} with CPF: {cpf}")
            cursor.execute(sql, (cpf,))
            result = cursor.fetchone()
            print(f"Query result: {result}")

            if result:
                return {
                    "statusCode": 200,
                    "body": json.dumps({"message": "CPF exists, user logged in.", "customer": result}, default=json_serial)
                }
            else:
                return {
                    "statusCode": 404,
                    "body": json.dumps({"message": "CPF not found."})
                }

    except pymysql.Error as e:
        print(f"Database error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Database error: {e}"})
        }
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "Invalid JSON in request body."})
        }
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"An unexpected error occurred: {e}"})
        }
    finally:
        if 'connection' in locals() and connection.open:
            connection.close()
