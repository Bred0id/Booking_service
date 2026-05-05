from datetime import datetime
from pydantic import BaseModel

class Booking(BaseModel):
    user_id: int
    studio_id: int
    start: datetime
    end: datetime
    purpose: str