import asyncpg
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from datetime import date, datetime

DATABASE = "postgresql://postgres:postgres@localhost:5432/project"

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
        rows = await conn.fetch("SELECT studio_id, studiщ_name FROM music_studio.studios ORDER BY studio_id")
    return [dict(row) for row in rows]

@app.get("/studios/{studio_id}")
async def get_studio_info(studio_id: int):
    async with app.state.pool.acquire() as conn:
        info = await conn.fetchrow("SELECT * FROM music_studio.studios WHERE studio_id=$1", studio_id)
    if info is None:
        raise HTTPException(status_code=404, detail="Studio not found")
    return dict(info)

@app.get("/studios/{studio_id}")
async def get_schedule(studio_id: int, date: date):
    async with app.state.pool.acquire() as conn:
        schedule = await conn.fetch("SELECT * FROM music_studio.get_studio_hourly_schedule($1, $2)", studio_id, date)
    if schedule is None:
        raise HTTPException(status_code=404, detail="Cannot make schedule")
    return [dict(sch) for sch in schedule]

