import logging
from typing import List
from app.core.config import get_settings

logger = logging.getLogger(__name__)

def send_email(to_emails: List[str], subject: str, body: str):
    """
    Sends an email to the specified recipients.
    In a real production environment, this would use an SMTP client or a service like SendGrid/SES.
    For now, we log the email content.
    """
    settings = get_settings()
    # In a real app, you'd use something like:
    # with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
    #     server.login(settings.smtp_user, settings.smtp_password)
    #     message = f"Subject: {subject}\n\n{body}"
    #     server.sendmail(settings.from_email, to_emails, message)
    
    logger.info(f"SIMULATED EMAIL SENT TO: {to_emails}")
    logger.info(f"SUBJECT: {subject}")
    logger.info(f"BODY: {body}")
    
    # We also print it for visibility in logs during dev
    print(f"--- EMAIL SIMULATION START ---")
    print(f"To: {to_emails}")
    print(f"Subject: {subject}")
    print(f"Body:\n{body}")
    print(f"--- EMAIL SIMULATION END ---")

def notify_admins_of_support_issue(issue_id: str, user_email: str, message: str):
    settings = get_settings()
    admin_emails = [e.strip() for e in settings.admin_emails.split(",") if e.strip()]
    if not admin_emails:
        logger.warning("No admin emails configured. Cannot send support notification.")
        return

    subject = f"New Support Issue: {issue_id}"
    body = f"A new support issue has been submitted.\n\nFrom: {user_email}\nMessage: {message}\n\nIssue ID: {issue_id}"
    send_email(admin_emails, subject, body)

def notify_admins_of_reach_out(user_id: str, role: str, message: str):
    settings = get_settings()
    admin_emails = [e.strip() for e in settings.admin_emails.split(",") if e.strip()]
    if not admin_emails:
        return

    subject = f"New Reach Out from {role.capitalize()}"
    body = f"A {role} (User ID: {user_id}) has reached out for publishing/advertisement.\n\nMessage: {message}"
    send_email(admin_emails, subject, body)
