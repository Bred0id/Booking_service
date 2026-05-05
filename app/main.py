import asyncpg
from schemas import Booking
from config import DATABASE_URL, ADMIN_KEY, ANALYTICS_KEY
from typing import Optional
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends, Header
from datetime import date

async def check_admin(key: Optional[str] = Header(default=None)):
    if key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="Access denied")

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await asyncpg.create_pool(DATABASE)
    yield
    await app.state.pool.close()

app = FastAPI(lifespan=lifespan)

@app.get("/")
async def root():
    return {"status": "ok"}

@app.get("/studios")
async def get_all_studios():
    async with app.state.pool.acquire() as conn:
        rows = await conn.fetch("SELECT studio_id, studio_name FROM music_studio.studios ORDER BY studio_id")
    return [dict(row) for row in rows]

@app.get("/studios/{studio_id}")
async def get_studio_info(studio_id: int):
    async with app.state.pool.acquire() as conn:
        info = await conn.fetchrow("SELECT * FROM music_studio.studios WHERE studio_id=$1", studio_id)
    if info is None:
        raise HTTPException(status_code=404, detail="Studio not found")
    return dict(info)

@app.get("/studios/{studio_id}/schedule")
async def get_schedule(studio_id: int, day: date):
    try:
        async with app.state.pool.acquire() as conn:
            schedule = await conn.fetch("SELECT * FROM music_studio.get_studio_hourly_schedule($1, $2)", studio_id, day)
        
    except asyncpg.PostgresError as exc:
        message = str(exc)
        if "does not exist" in message:
            raise HTTPException(status_code=404, detail=message) from exc
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    
    return [dict(sch) for sch in schedule]

@app.post("/bookings")
async def new_booking(booking: Booking):
    try:
        async with app.state.pool.acquire() as conn:
            booking_id = await asyncpg.fetchval("SELECT * FROM music_studio.create_booking($1, $2, $3, $4, $5)", 
                                           booking.user_id,
                                           booking.studio_id,
                                           booking.start,
                                           booking.end,
                                           booking.purpose
                                        )
    except asyncpg.PostgresError as exc:
        message = str(exc)
        if "does not exist" in message:
            raise HTTPException(status_code=404, detail=message) from exc
        if "Studio is not available" in message or "Booking time overlaps with another booking" in message:
            raise HTTPException(status_code=409, detail=message) from exc
        raise HTTPEception(status_code=400, detail=message) from exc
    return {"booking_id": booking_id}

@app.get("/admin/bookings/active")
async def get_active_bookings(_: None = Depends(check_admin)):
    async with app.state.pool.acquire() as conn:
        rows = await conn.fetch("SELECT * FROM music_studio.v_active_bookings ORDER BY start_time")
    return [dict(row) for row in rows]

@app.get("/reviews/{studio_id}")
async def get_studio_review(studio_id: int):
    async with app.state.pool.acquire() as conn:
        rows = await conn.fetch("SELECT * FROM music_studio.v_studio_reviews WHERE studio_id = $1 ORDER BY studio_rating DESC", studio_id)
    return [dict(row) for row in rows]