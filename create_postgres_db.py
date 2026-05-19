import os

from sqlalchemy import create_engine, text


ADMIN_DATABASE_URL = os.getenv("POSTGRES_ADMIN_URL")
TARGET_DATABASE_NAME = os.getenv("POSTGRES_DB_NAME", "waste_sorting_db")


def main():
    if not ADMIN_DATABASE_URL:
        raise SystemExit("Set POSTGRES_ADMIN_URL before running this script.")

    engine = create_engine(ADMIN_DATABASE_URL, future=True, isolation_level="AUTOCOMMIT")
    with engine.connect() as connection:
        exists = connection.execute(
            text("SELECT 1 FROM pg_database WHERE datname = :name"),
            {"name": TARGET_DATABASE_NAME},
        ).scalar()
        if exists:
            print(f"Database '{TARGET_DATABASE_NAME}' already exists.")
            return
        connection.execute(text(f'CREATE DATABASE "{TARGET_DATABASE_NAME}"'))
        print(f"Database '{TARGET_DATABASE_NAME}' created.")


if __name__ == "__main__":
    main()
