import json
import os
import pymysql

def lambda_handler(event, context):
    """
    Handles login requests by verifying if a CPF exists in the database.
    """
    db_host = os.environ.get('DB_HOST')
    db_user = os.environ.get('DB_USER')
    db_password = os.environ.get('DB_PASSWORD')
    db_name = os.environ.get('DB_NAME')
    db_port = int(os.environ.get('DB_PORT', 3306))

    if not all([db_host, db_user, db_password, db_name]):
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Database credentials not configured'})
        }

    try:
        body = json.loads(event['body'])
        cpf = body.get('cpf')

        if not cpf:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'CPF is required'})
            }

        connection = pymysql.connect(
            host=db_host,
            user=db_user,
            password=db_password,
            database=db_name,
            port=db_port,
            cursorclass=pymysql.cursors.DictCursor
        )

        with connection.cursor() as cursor:
            sql = "SELECT COUNT(*) FROM customers WHERE cpf = %s"
            cursor.execute(sql, (cpf,))
            result = cursor.fetchone()
            
            if result and result['COUNT(*)'] > 0:
                return {
                    'statusCode': 200,
                    'body': json.dumps({'message': 'Authentication successful'})
                }
            else:
                return {
                    'statusCode': 401,
                    'body': json.dumps({'message': 'Authentication failed: Invalid CPF'})
                }

    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'Invalid JSON in request body'})
        }
    except pymysql.Error as e:
        print(f"Database error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Database error: {str(e)}'})
        }
    except Exception as e:
        print(f"Internal server error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Internal server error: {str(e)}'})
        }
    finally:
        if 'connection' in locals() and connection.open:
            connection.close()
