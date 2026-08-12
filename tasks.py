import json
import os
import ssl
import smtplib
import urllib.request
from email.message import EmailMessage

from celery import Celery

celery_app = Celery(
    "ecosort",
    broker=os.getenv("REDIS_URL", "redis://localhost:6379/0"),
    backend=os.getenv("REDIS_URL", "redis://localhost:6379/0"),
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def send_email_task(self, to_address: str, subject: str, body: str):
    smtp_server = os.getenv("SMTP_SERVER", "")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_username = os.getenv("SMTP_USERNAME", "")
    smtp_password = os.getenv("SMTP_PASSWORD", "")
    smtp_use_tls = os.getenv("SMTP_USE_TLS", "true").lower() in ("true", "1", "yes")
    email_from = os.getenv("EMAIL_FROM_ADDRESS", "no-reply@example.com")

    if not smtp_server or not email_from:
        return False

    message = EmailMessage()
    message["From"] = email_from
    message["To"] = to_address
    message["Subject"] = subject
    message.set_content(body)

    try:
        if smtp_use_tls:
            context = ssl.create_default_context()
            with smtplib.SMTP(smtp_server, smtp_port, timeout=10) as server:
                server.starttls(context=context)
                if smtp_username:
                    server.login(smtp_username, smtp_password)
                server.send_message(message)
        else:
            with smtplib.SMTP(smtp_server, smtp_port, timeout=10) as server:
                if smtp_username:
                    server.login(smtp_username, smtp_password)
                server.send_message(message)
        return True
    except Exception as exc:
        raise self.retry(exc=exc)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=10)
def send_push_notification_task(self, tokens: list[str], title: str, message: str, data: dict | None = None):
    fcm_server_key = os.getenv("FCM_SERVER_KEY", "")

    if not fcm_server_key or not tokens:
        return False

    payload = {
        "registration_ids": tokens,
        "notification": {
            "title": title,
            "body": message,
            "sound": "default",
        },
        "priority": "high",
    }

    if data:
        payload["data"] = data

    request = urllib.request.Request(
        "https://fcm.googleapis.com/fcm/send",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"key={fcm_server_key}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return 200 <= response.status < 300
    except Exception as exc:
        raise self.retry(exc=exc)
