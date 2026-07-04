from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.database_mongo import get_mongo_db
from app.schemas import AdminCreateRequest, AdminLoginRequest, AdminLoginResponse
from app.auth import hash_password, verify_password, create_access_token, verify_token
from app.logger import logger

router = APIRouter(prefix="/admin", tags=["admin_auth"])

@router.get(
    "/setup-check",
    status_code=status.HTTP_200_OK,
    summary="Check if first-time system initialization (admin registration) is required"
)
async def setup_check(db = Depends(get_mongo_db)):
    user_count = await db.users.count_documents({})
    return {"setup_required": user_count == 0}

@router.post(
    "/add-account",
    response_model=AdminLoginResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new admin account"
)
async def add_admin_account(
    request: Request,
    body: AdminCreateRequest,
    db = Depends(get_mongo_db)
):
    user_count = await db.users.count_documents({})
    if user_count > 0:
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not authenticated: Admin token required",
                headers={"WWW-Authenticate": "Bearer"},
            )
        token = auth_header.split(" ")[1]
        payload = verify_token(token)
        if payload.get("role") != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Admin access required",
            )
            
    existing = await db.users.find_one({"username": body.username.lower()})
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken"
        )
        
    hashed_pwd = hash_password(body.password)
    user_doc = {
        "username": body.username.lower(),
        "password": hashed_pwd,
        "role": "admin"
    }
    await db.users.insert_one(user_doc)
    logger.success(f"New admin account created: {body.username.lower()}")
    
    token = create_access_token(data={"sub": body.username.lower(), "role": "admin"})
    return AdminLoginResponse(token=token, username=body.username.lower())

@router.post(
    "/login",
    response_model=AdminLoginResponse,
    status_code=status.HTTP_200_OK,
    summary="Admin login"
)
async def admin_login(body: AdminLoginRequest, db = Depends(get_mongo_db)):
    user = await db.users.find_one({"username": body.username.lower()})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )
        
    if not verify_password(body.password, user["password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )
        
    token = create_access_token(data={"sub": user["username"], "role": "admin"})
    logger.success(f"Admin logged in successfully: {user['username']}")
    return AdminLoginResponse(token=token, username=user["username"])

from app.auth import get_current_admin
from typing import List

@router.get(
    "/accounts",
    response_model=List[str],
    status_code=status.HTTP_200_OK,
    summary="Get all admin accounts"
)
async def get_admin_accounts(db = Depends(get_mongo_db), admin: dict = Depends(get_current_admin)):
    cursor = db.users.find({}, {"username": 1})
    users = await cursor.to_list(length=100)
    return [u["username"] for u in users]

@router.delete(
    "/accounts/{username}",
    status_code=status.HTTP_200_OK,
    summary="Delete an admin account"
)
async def delete_admin_account(username: str, db = Depends(get_mongo_db), admin: dict = Depends(get_current_admin)):
    if admin.get("sub") == username.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Self-deletion is forbidden. You cannot delete your own admin account while logged in."
        )
        
    user = await db.users.find_one({"username": username.lower()})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Admin account '{username}' not found"
        )
        
    user_count = await db.users.count_documents({})
    if user_count <= 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete the last administrator. The system must retain at least one administrator."
        )
        
    await db.users.delete_one({"username": username.lower()})
    logger.info(f"Admin account deleted by {admin.get('sub')}: {username.lower()}")
    return {"detail": f"Admin account '{username}' deleted successfully"}
