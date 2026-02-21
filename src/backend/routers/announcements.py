from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from ..database import announcements_collection
from ..routers.auth import check_session

router = APIRouter(
    prefix="/announcements",
    tags=["announcements"]
)

class Announcement(BaseModel):
    title: str
    content: str
    start_date: Optional[datetime] = None
    expiration_date: datetime

# Dependency to check if user is signed in
def get_current_user(username: str = Depends(check_session)):
    if not username:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return username

@router.get("/", response_model=List[Announcement])
def get_announcements():
    """Retrieve all announcements."""
    current_time = datetime.utcnow()
    announcements = list(announcements_collection.find({
        "$or": [
            {"start_date": None, "expiration_date": {"$gte": current_time}},
            {"start_date": {"$lte": current_time}, "expiration_date": {"$gte": current_time}}
        ]
    }))
    for announcement in announcements:
        announcement["id"] = str(announcement.pop("_id"))
    return announcements

@router.post("/add")
def add_announcement(announcement: Announcement, current_user: str = Depends(get_current_user)):
    """Add a new announcement."""
    announcement_dict = announcement.dict()
    announcements_collection.insert_one(announcement_dict)
    return {"message": "Announcement added successfully."}

@router.put("/update/{announcement_id}")
def update_announcement(announcement_id: str, announcement: Announcement, current_user: str = Depends(get_current_user)):
    """Update an existing announcement."""
    result = announcements_collection.update_one(
        {"_id": announcement_id},
        {"$set": announcement.dict()}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Announcement not found.")
    return {"message": "Announcement updated successfully."}

@router.delete("/delete/{announcement_id}")
def delete_announcement(announcement_id: str, current_user: str = Depends(get_current_user)):
    """Delete an announcement."""
    result = announcements_collection.delete_one({"_id": announcement_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Announcement not found.")
    return {"message": "Announcement deleted successfully."}