import logging
import azure.functions as func
import psycopg2
import os
from datetime import datetime
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

def main(msg: func.ServiceBusMessage):

    notification_id = int(msg.get_body().decode('utf-8'))
    logging.info('Python ServiceBus queue trigger processed message: %s', notification_id)

    # Get connection to database
    connection = psycopg2.connect(
        host=os.environ['POSTGRES_URL'],
        database=os.environ['POSTGRES_DB'],
        user=os.environ['POSTGRES_USER'],
        password=os.environ['POSTGRES_PW']
    )
    cursor = connection.cursor()

    try:
        # Get notification message and subject from database using the notification_id
        cursor.execute("SELECT subject, message FROM notification WHERE id = %s", (notification_id,))
        notification = cursor.fetchone()
        
        if not notification:
            logging.error(f'Notification {notification_id} not found')
            return
        
        subject = notification[0]
        message = notification[1]

        # Get attendees email and name
        cursor.execute("SELECT first_name, email FROM attendee")
        attendees = cursor.fetchall()

        # Loop through each attendee and send an email with a personalized subject
        count = 0
        for attendee in attendees:
            first_name = attendee[0]
            email = attendee[1]
            personalized_subject = f'{first_name}: {subject}'
            
            # Send email using SendGrid
            try:
                send_email(email, personalized_subject, message)
                count += 1
            except Exception as e:
                logging.error(f'Failed to send email to {email}: {str(e)}')

        # Update the notification table by setting the completed date and updating the status
        completed_date = datetime.utcnow()
        status = f'Notified {count} attendees'
        cursor.execute(
            "UPDATE notification SET status = %s, completed_date = %s WHERE id = %s",
            (status, completed_date, notification_id)
        )
        connection.commit()
        
        logging.info(f'Successfully notified {count} attendees for notification {notification_id}')

    except (Exception, psycopg2.DatabaseError) as error:
        logging.error(f'Error processing notification {notification_id}: {str(error)}')
        connection.rollback()
    finally:
        # Close connection
        cursor.close()
        connection.close()


def send_email(email, subject, body):
    """Send email using SendGrid API"""
    admin_email = os.environ.get('ADMIN_EMAIL_ADDRESS', 'info@techconf.com')
    sendgrid_api_key = os.environ.get('SENDGRID_API_KEY')
    
    if not sendgrid_api_key:
        logging.warning(f'SendGrid API key not configured. Would send email to {email} with subject: {subject}')
        return
    
    message = Mail(
        from_email=admin_email,
        to_emails=email,
        subject=subject,
        plain_text_content=body
    )
    
    sg = SendGridAPIClient(sendgrid_api_key)
    sg.send(message)
