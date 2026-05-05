import os
from dotenv import load_dotenv

load_dotenv()

def get_required_env(name: str) -> str:
    value = os.getenv(name)
    if value is None:
        raise RuntimeError(f"Environment variable {name} is not set")
    return value


DATABASE_URL = get_required_env("DATABASE_URL")
ADMIN_KEY = get_required_env("ADMIN_KEY")
ANALYTICS_KEY = get_required_env("ANALYTICS_KEY")