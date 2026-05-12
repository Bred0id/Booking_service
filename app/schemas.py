from datetime import datetime
from pydantic import BaseModel
from decimal import Decimal

class Booking(BaseModel):
    user_id: int
    studio_id: int
    start: datetime
    end: datetime
    purpose: str
    
class Payment(BaseModel):
    booking_id: int
    amount: Decimal
    payment_method: str
    status: str