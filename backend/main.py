from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "calculator.db"

app = FastAPI(title="Calculator API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class CalculationIn(BaseModel):
    expression: str = Field(..., min_length=1)
    result: str = Field(..., min_length=1)
    user: str = Field(..., min_length=1)


class CalculationOut(BaseModel):
    id: int
    expression: str
    result: str
    user: str
    created_at: str


def get_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def init_db() -> None:
    with get_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS calculations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                expression TEXT NOT NULL,
                result TEXT NOT NULL,
                user TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        connection.commit()


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/health")
def health_check() -> dict:
    return {"status": "ok"}


@app.post("/calculations", response_model=CalculationOut)
def create_calculation(payload: CalculationIn) -> CalculationOut:
    created_at = datetime.now(timezone.utc).isoformat()
    with get_connection() as connection:
        cursor = connection.execute(
            """
            INSERT INTO calculations (expression, result, user, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (payload.expression, payload.result, payload.user, created_at),
        )
        connection.commit()
        calculation_id = cursor.lastrowid

    return CalculationOut(
        id=calculation_id,
        expression=payload.expression,
        result=payload.result,
        user=payload.user,
        created_at=created_at,
    )


@app.get("/calculations", response_model=list[CalculationOut])
def list_calculations() -> list[CalculationOut]:
    with get_connection() as connection:
        rows = connection.execute(
            """
            SELECT id, expression, result, user, created_at
            FROM calculations
            ORDER BY id DESC
            LIMIT 50
            """
        ).fetchall()

    return [CalculationOut(**dict(row)) for row in rows]
