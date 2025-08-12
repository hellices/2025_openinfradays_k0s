from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from datetime import datetime


app = FastAPI(title="Sample CRUD API", version="0.1.0")


class ItemBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)


class ItemCreate(ItemBase):
    pass


class ItemUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)


class Item(ItemBase):
    id: int
    created_at: datetime
    updated_at: datetime


# In-memory local cache (not persistent). In real apps, use a database.
_items: Dict[int, Item] = {}
_next_id: int = 1


@app.get("/", summary="Root")
def root():
    return {"service": app.title, "version": app.version}


@app.get("/healthz", summary="Liveness/health check")
def healthz():
    return {"status": "ok", "time": datetime.utcnow().isoformat()}


@app.get("/items", response_model=List[Item], summary="List items")
def list_items():
    # return items sorted by id for stability
    return [
        _items[i]
        for i in sorted(_items.keys())
    ]


@app.post("/items", response_model=Item, status_code=201, summary="Create item")
def create_item(payload: ItemCreate, response: Response):
    global _next_id
    now = datetime.utcnow()
    item = Item(id=_next_id, name=payload.name, description=payload.description, created_at=now, updated_at=now)
    _items[_next_id] = item
    response.headers["Location"] = f"/items/{_next_id}"
    _next_id += 1
    return item


@app.get("/items/{item_id}", response_model=Item, summary="Get item")
def get_item(item_id: int):
    item = _items.get(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@app.put("/items/{item_id}", response_model=Item, summary="Replace item")
def replace_item(item_id: int, payload: ItemCreate):
    item = _items.get(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    now = datetime.utcnow()
    item = Item(id=item_id, name=payload.name, description=payload.description, created_at=item.created_at, updated_at=now)
    _items[item_id] = item
    return item


@app.patch("/items/{item_id}", response_model=Item, summary="Update item fields")
def update_item(item_id: int, payload: ItemUpdate):
    item = _items.get(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    data = item.model_dump()
    if payload.name is not None:
        data["name"] = payload.name
    if payload.description is not None:
        data["description"] = payload.description
    data["updated_at"] = datetime.utcnow()
    updated = Item(**data)
    _items[item_id] = updated
    return updated


@app.delete("/items/{item_id}", status_code=204, summary="Delete item")
def delete_item(item_id: int):
    if item_id not in _items:
        raise HTTPException(status_code=404, detail="Item not found")
    del _items[item_id]
    return Response(status_code=204)


# For local dev: `python -m uvicorn app.main:app --reload --port 8080`
