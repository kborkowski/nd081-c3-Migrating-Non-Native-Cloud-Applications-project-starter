from app import app, db, queue_client
from datetime import datetime
from app.models import Attendee, Conference, Notification
from flask import render_template, session, request, redirect, url_for, flash, make_response, session
from azure.servicebus import ServiceBusMessage
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
import logging

@app.route('/')
def index():
    return render_template('index.html')


@app.route('/Registration', methods=['POST', 'GET'])
def registration():
    if request.method == 'POST':
        attendee = Attendee()
        attendee.first_name = request.form['first_name']
        attendee.last_name = request.form['last_name']
        attendee.email = request.form['email']
        attendee.job_position = request.form['job_position']
        attendee.company = request.form['company']
        attendee.city = request.form['city']
        attendee.state = request.form['state']
        attendee.interests = request.form['interest']
        attendee.comments = request.form['message']
        attendee.conference_id = app.config.get('CONFERENCE_ID')

        try:
            db.session.add(attendee)
            db.session.commit()
            session['message'] = 'Thank you, {} {}, for registering!'.format(attendee.first_name, attendee.last_name)
            return redirect('/Registration')
        except:
            logging.error('Error occured while saving your information')

    else:
        if 'message' in session:
            message = session['message']
            session.pop('message', None)
            return render_template('registration.html', message=message)
        else:
             return render_template('registration.html')

@app.route('/Attendees')
def attendees():
    attendees = Attendee.query.order_by(Attendee.submitted_date).all()
    return render_template('attendees.html', attendees=attendees)


@app.route('/Notifications')
def notifications():
    notifications = Notification.query.order_by(Notification.id).all()
    return render_template('notifications.html', notifications=notifications)

@app.route('/Notification', methods=['POST', 'GET'])
def notification():
    if request.method == 'POST':
        notification = Notification()
        notification.message = request.form['message']
        notification.subject = request.form['subject']
        notification.status = 'Notifications submitted'
        notification.submitted_date = datetime.utcnow()

        try:
            db.session.add(notification)
            db.session.commit()

            ##################################################
            ## REFACTORED: Send notification ID to Azure Service Bus Queue
            ## Azure Function will process the notification asynchronously
            #################################################
            
            if queue_client:
                # Send notification ID to Service Bus queue
                try:
                    sender = queue_client.get_queue_sender(queue_name=app.config.get('SERVICE_BUS_QUEUE_NAME'))
                    message = ServiceBusMessage(str(notification.id))
                    sender.send_messages(message)
                    sender.close()
                    
                    notification.status = 'Queued for processing'
                    db.session.commit()
                    
                    logging.info(f'Notification {notification.id} queued to Service Bus')
                except Exception as e:
                    logging.error(f'Failed to queue notification: {str(e)}')
                    notification.status = 'Failed to queue'
                    db.session.commit()
            else:
                # Fallback: Process synchronously if Service Bus is not configured (local testing)
                logging.warning('Service Bus not configured. Processing notification synchronously.')
                attendees = Attendee.query.all()

                for attendee in attendees:
                    subject = '{}: {}'.format(attendee.first_name, notification.subject)
                    send_email(attendee.email, subject, notification.message)

                notification.completed_date = datetime.utcnow()
                notification.status = 'Notified {} attendees (synchronous)'.format(len(attendees))
                db.session.commit()

            #################################################
            ## END of REFACTORING
            #################################################

            return redirect('/Notifications')
        except Exception as e:
            logging.error(f'Error unable to save notification: {str(e)}')
            return redirect('/Notification')

    else:
        return render_template('notification.html')



def send_email(email, subject, body):
    sendgrid_key = app.config.get('SENDGRID_API_KEY')
    
    if not sendgrid_key:
        logging.info(f'SendGrid not configured. Would send email to {email} with subject: {subject}')
        return
    
    try:
        message = Mail(
            from_email=app.config.get('ADMIN_EMAIL_ADDRESS'),
            to_emails=email,
            subject=subject,
            plain_text_content=body)

        sg = SendGridAPIClient(sendgrid_key)
        response = sg.send(message)
        logging.info(f'Email sent to {email}, status: {response.status_code}')
    except Exception as e:
        logging.error(f'Failed to send email to {email}: {str(e)}')
