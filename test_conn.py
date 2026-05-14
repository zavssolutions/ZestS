import sqlalchemy
from sqlalchemy import create_engine
import sys

db_url = sys.argv[1]
print("Connecting to:", db_url)
try:
    engine = create_engine(db_url)
    with engine.connect() as conn:
        print("Success!")
except Exception as e:
    print("Error:", e)
