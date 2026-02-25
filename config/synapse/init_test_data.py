#!/usr/bin/env python3
"""
Initialize Matrix Synapse test server with test users, rooms, and messages.
This script is run as part of the Docker startup process.
"""

import requests
import json
import sys
import time
import hmac
import hashlib
from typing import Dict, Any, Optional

# Configuration
# Use Docker service name when running in Docker, or localhost when running locally
SYNAPSE_URL = "http://matrix-synapse:8008"
REGISTRATION_SHARED_SECRET = "test_registration_secret"

# Test users to create
TEST_USERS = [
    {"username": "testuser1", "password": "testpass123", "display_name": "Test User 1"},
    {"username": "testuser2", "password": "testpass123", "display_name": "Test User 2"},
    {"username": "testadmin", "password": "testpass123", "display_name": "Test Admin"},
]

# Test rooms to create
# Set populate_with_messages to False for empty room testing
TEST_ROOMS = [
    {
        "name": "test_general",
        "topic": "General test room",
        "populate_with_messages": True,  # Will have messages
        "message_count": 5,
        "invite_users": True,  # Invite all users
        # Seed one of each media type so display tests can verify rendering
        "seed_media": True,
    },
    {
        "name": "test_photos",
        "topic": "Photo sharing test room",
        "populate_with_messages": True,  # Will have messages
        "message_count": 3,
        "invite_users": True,  # Invite all users
        "seed_media": True,
    },
    {
        "name": "test_art",
        "topic": "Art community test room",
        "populate_with_messages": False,  # Empty room - no messages
        "message_count": 0,
        "invite_users": True,  # Invite all users
        "has_avatar": True,
    },
    {
        "name": "test_invite_only",
        "topic": "Room to test joining/discovery",
        "populate_with_messages": True,  # Some messages to find
        "message_count": 2,
        "invite_users": False,  # Do NOT invite users - they must discover and join
    },
    {
        "name": "test_avatar",
        "topic": "Room with an avatar",
        "populate_with_messages": False,
        "message_count": 0,
        "invite_users": True,
        "has_avatar": True,
    },
]

# Sample messages to post
SAMPLE_MESSAGES = [
    "Hello everyone! Welcome to this test room.",
    "This is the second message in the room.",
    "Check out this amazing content!",
    "What do you think about this?",
    "Looking forward to your feedback.",
    "This is a test message.",
    "Another interesting post here.",
    "Feel free to share your thoughts.",
]


def wait_for_server(max_attempts: int = 30) -> bool:
    """Wait for Synapse server to be ready."""
    for attempt in range(max_attempts):
        try:
            response = requests.get(f"{SYNAPSE_URL}/_matrix/client/versions", timeout=5)
            if response.status_code == 200:
                print(f"✓ Synapse server is ready")
                return True
        except requests.ConnectionError:
            pass

        if attempt < max_attempts - 1:
            time.sleep(2)

    print(f"✗ Synapse server did not become ready after {max_attempts * 2} seconds")
    return False


def register_user(
    username: str, password: str, display_name: str
) -> Optional[Dict[str, Any]]:
    """Register a test user."""
    payload = {
        "auth": {"type": "m.login.dummy"},
        "username": username,
        "password": password,
        "initial_device_display_name": display_name,
    }

    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/r0/register",
        json=payload,
    )

    if response.status_code in [200, 201]:
        data = response.json()
        print(f"✓ Created user: {username}")
        return data
    elif response.status_code == 400:
        print(f"ℹ User likely already exists: {username}")
        return {"user_id": f"@{username}:test.matrix.local"}
    else:
        print(
            f"✗ Failed to create user {username}: {response.status_code} {response.text}"
        )
        return None


def register_admin_user(
    username: str, password: str, display_name: str
) -> Optional[Dict[str, Any]]:
    """Register a test user as a server admin using the shared secret API."""
    # Step 1: Get a nonce from Synapse
    nonce_response = requests.get(
        f"{SYNAPSE_URL}/_synapse/admin/v1/register",
    )
    if nonce_response.status_code != 200:
        print(
            f"✗ Failed to get nonce: {nonce_response.status_code} {nonce_response.text}"
        )
        return None

    nonce = nonce_response.json().get("nonce")
    if not nonce:
        print("✗ No nonce in response")
        return None

    # Step 2: Compute the HMAC-SHA1 MAC
    # Format: nonce + \x00 + username + \x00 + password + \x00 + "admin"
    mac_payload = "\x00".join([nonce, username, password, "admin"])
    mac = hmac.new(
        REGISTRATION_SHARED_SECRET.encode("utf-8"),
        mac_payload.encode("utf-8"),
        hashlib.sha1,
    ).hexdigest()

    # Step 3: Register as admin
    payload = {
        "nonce": nonce,
        "username": username,
        "password": password,
        "displayname": display_name,
        "admin": True,
        "mac": mac,
    }

    response = requests.post(
        f"{SYNAPSE_URL}/_synapse/admin/v1/register",
        json=payload,
    )

    if response.status_code in [200, 201]:
        data = response.json()
        print(f"✓ Created admin user: {username}")
        return data
    elif response.status_code == 400 and "already" in response.text.lower():
        print(f"ℹ Admin user likely already exists: {username}")
        return {"user_id": f"@{username}:test.matrix.local"}
    else:
        print(
            f"✗ Failed to create admin user {username}: {response.status_code} {response.text}"
        )
        # Fall back to regular registration
        return register_user(username, password, display_name)


def login_user(user_id: str, password: str) -> Optional[str]:
    """Login a user and get access token."""
    payload = {
        "type": "m.login.password",
        "user": user_id,
        "password": password,
    }

    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/r0/login",
        json=payload,
    )

    if response.status_code == 200:
        data = response.json()
        token = data.get("access_token")
        print(f"✓ Logged in user: {user_id}")
        return token
    else:
        print(f"✗ Failed to login user {user_id}: {response.status_code}")
        print(f"  Response: {response.text}")
        return None


def create_room(access_token: str, room_name: str, topic: str) -> Optional[str]:
    """Create a test room."""
    payload = {
        "visibility": "public",
        "room_alias_name": room_name,
        "name": room_name,
        "topic": topic,
        "initial_state": [
            {
                "type": "m.room.join_rules",
                "content": {"join_rule": "public"},
                "state_key": "",
            },
            {
                "type": "m.room.history_visibility",
                "content": {"history_visibility": "shared"},
                "state_key": "",
            },
        ],
    }

    headers = {"Authorization": f"Bearer {access_token}"}

    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/v3/createRoom",
        json=payload,
        headers=headers,
    )

    if response.status_code in [200, 201]:
        data = response.json()
        room_id = data.get("room_id")
        print(f"✓ Created room: {room_name} ({room_id})")
        return room_id
    elif response.status_code == 400:
        # Try to resolve alias if creation failed
        alias = f"#{room_name}:test.matrix.local"
        resolve_resp = requests.get(
            f"{SYNAPSE_URL}/_matrix/client/v3/directory/room/{alias.replace('#', '%23')}"
        )
        if resolve_resp.status_code == 200:
            room_id = resolve_resp.json().get("room_id")
            print(f"ℹ Room already exists: {room_name} ({room_id})")
            return room_id
        else:
            print(
                f"✗ Failed to create or resolve room {room_name}: {response.status_code} {response.text}"
            )
            return None
    else:
        print(
            f"✗ Failed to create room {room_name}: {response.status_code} {response.text}"
        )
        return None


def publish_room(access_token: str, room_id: str, use_admin_api: bool = False) -> bool:
    """Publish a room to the public directory using the standard Matrix client API.

    Requires the caller to be a member of the room (created it, or joined).
    The use_admin_api parameter is kept for compatibility but ignored;
    the standard client API is always used.
    """
    headers = {"Authorization": f"Bearer {access_token}"}
    payload = {"visibility": "public"}
    url = f"{SYNAPSE_URL}/_matrix/client/v3/directory/list/room/{room_id}"

    response = requests.put(url, json=payload, headers=headers)

    if response.status_code == 200:
        print(f"  ✓ Published room to directory")
        return True
    else:
        print(f"  ⚠ Failed to publish room: {response.status_code} {response.text}")
        return False


def verify_public_rooms(access_token: str) -> None:
    """Verify that rooms appear in the public directory (for debugging)."""
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.get(
        f"{SYNAPSE_URL}/_matrix/client/v3/publicRooms?limit=20",
        headers=headers,
    )
    if response.status_code == 200:
        data = response.json()
        rooms = data.get("chunk", [])
        print(f"  📋 Public room directory has {len(rooms)} room(s):")
        for room in rooms:
            print(f"    - {room.get('name', 'unnamed')} ({room.get('room_id', '?')})")
    else:
        print(
            f"  ⚠ Could not query public rooms: {response.status_code} {response.text}"
        )


def join_room(access_token: str, room_id: str) -> bool:
    """Join a room."""
    headers = {"Authorization": f"Bearer {access_token}"}

    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/v3/join/{room_id}",
        json={},
        headers=headers,
    )

    if response.status_code == 200:
        return True
    else:
        print(f"  ⚠ Failed to join room {room_id}: {response.status_code}")
        return False


def invite_users_to_room(access_token: str, room_id: str, user_ids: list) -> bool:
    """Invite users to a room."""
    headers = {"Authorization": f"Bearer {access_token}"}

    for user_id in user_ids:
        payload = {"user_id": user_id}
        response = requests.post(
            f"{SYNAPSE_URL}/_matrix/client/v3/rooms/{room_id}/invite",
            json=payload,
            headers=headers,
        )

        if response.status_code in [200, 201]:
            print(f"  ✓ Invited {user_id} to room")
        else:
            print(f"  ⚠ Failed to invite {user_id}: {response.status_code}")

    return True


def post_message(access_token: str, room_id: str, message: str) -> bool:
    """Post a message to a room."""
    headers = {"Authorization": f"Bearer {access_token}"}

    payload = {
        "msgtype": "m.text",
        "body": message,
    }

    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/r0/rooms/{room_id}/send/m.room.message",
        json=payload,
        headers=headers,
    )

    if response.status_code in [200, 201]:
        return True
    else:
        print(f"  ⚠ Failed to post message: {response.status_code}")
        return False


def populate_room_with_messages(
    access_token: str, room_id: str, message_count: int
) -> int:
    """Populate a room with test messages."""
    posted_count = 0
    for i in range(min(message_count, len(SAMPLE_MESSAGES))):
        if post_message(access_token, room_id, SAMPLE_MESSAGES[i]):
            posted_count += 1

    if posted_count > 0:
        print(f"  ✓ Posted {posted_count} messages to room")

    return posted_count


def upload_media(
    access_token: str, data: bytes, content_type: str, filename: str
) -> Optional[str]:
    """Upload binary media to Matrix and return its MXC URI."""
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": content_type,
    }
    params = {"filename": filename}

    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/media/v3/upload",
        data=data,
        headers=headers,
        params=params,
    )

    if response.status_code == 200:
        mxc_uri = response.json().get("content_uri")
        print(f"  ✓ Uploaded media '{filename}': {mxc_uri}")
        return mxc_uri
    else:
        print(
            f"  ⚠ Failed to upload media '{filename}': {response.status_code} {response.text}"
        )
        return None


def post_image_message(
    access_token: str, room_id: str, mxc_uri: str, filename: str = "test_image.png"
) -> bool:
    """Post an m.image message to a room."""
    headers = {"Authorization": f"Bearer {access_token}"}
    payload = {
        "msgtype": "m.image",
        "body": filename,
        "url": mxc_uri,
        "info": {
            "mimetype": "image/png",
            "size": 68,
            "w": 1,
            "h": 1,
        },
    }
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/r0/rooms/{room_id}/send/m.room.message",
        json=payload,
        headers=headers,
    )
    if response.status_code in [200, 201]:
        print(f"  ✓ Posted m.image message to room")
        return True
    else:
        print(f"  ⚠ Failed to post m.image message: {response.status_code}")
        return False


def post_video_message(
    access_token: str, room_id: str, mxc_uri: str, filename: str = "test_video.mp4"
) -> bool:
    """Post an m.video message to a room."""
    headers = {"Authorization": f"Bearer {access_token}"}
    payload = {
        "msgtype": "m.video",
        "body": filename,
        "url": mxc_uri,
        "info": {
            "mimetype": "video/mp4",
            "size": 28,
            "duration": 0,
        },
    }
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/r0/rooms/{room_id}/send/m.room.message",
        json=payload,
        headers=headers,
    )
    if response.status_code in [200, 201]:
        print(f"  ✓ Posted m.video message to room")
        return True
    else:
        print(f"  ⚠ Failed to post m.video message: {response.status_code}")
        return False


def post_audio_message(
    access_token: str, room_id: str, mxc_uri: str, filename: str = "test_audio.mp3"
) -> bool:
    """Post an m.audio message to a room."""
    headers = {"Authorization": f"Bearer {access_token}"}
    payload = {
        "msgtype": "m.audio",
        "body": filename,
        "url": mxc_uri,
        "info": {
            "mimetype": "audio/mpeg",
            "size": 62,
            "duration": 0,
        },
    }
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/r0/rooms/{room_id}/send/m.room.message",
        json=payload,
        headers=headers,
    )
    if response.status_code in [200, 201]:
        print(f"  ✓ Posted m.audio message to room")
        return True
    else:
        print(f"  ⚠ Failed to post m.audio message: {response.status_code}")
        return False


def seed_media_messages(access_token: str, room_id: str) -> None:
    """Seed one image, one video, and one audio message into a room."""
    print(f"  Seeding media messages (image, video, audio)...")

    # --- Image: minimal 1×1 PNG (68 bytes) ---
    IMAGE_DATA = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02"
        b"\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\xd7c\xf8\xff\xff?\x00\x05\xfe"
        b"\x02\xfe\xdc\xccY\xe7\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    image_mxc = upload_media(access_token, IMAGE_DATA, "image/png", "test_image.png")
    if image_mxc:
        post_image_message(access_token, room_id, image_mxc)

    # --- Video: minimal ftyp-only MP4 (28 bytes) ---
    VIDEO_DATA = bytes(
        [
            # ftyp box
            0x00,
            0x00,
            0x00,
            0x14,
            0x66,
            0x74,
            0x79,
            0x70,
            0x69,
            0x73,
            0x6F,
            0x6D,
            0x00,
            0x00,
            0x00,
            0x00,
            0x69,
            0x73,
            0x6F,
            0x6D,
            # mdat box (empty)
            0x00,
            0x00,
            0x00,
            0x08,
            0x6D,
            0x64,
            0x61,
            0x74,
        ]
    )
    video_mxc = upload_media(access_token, VIDEO_DATA, "video/mp4", "test_video.mp4")
    if video_mxc:
        post_video_message(access_token, room_id, video_mxc)

    # --- Audio: minimal ID3v2 + silent MPEG frame (62 bytes) ---
    AUDIO_DATA = bytes(
        [
            # ID3v2.3 header
            0x49,
            0x44,
            0x33,
            0x03,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            # MPEG1 Layer3 frame header (128kbps, 44100Hz, stereo)
            0xFF,
            0xFB,
            0x90,
            0x00,
            # 48 bytes of silence
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
        ]
    )
    audio_mxc = upload_media(access_token, AUDIO_DATA, "audio/mpeg", "test_audio.mp3")
    if audio_mxc:
        post_audio_message(access_token, room_id, audio_mxc)


def upload_avatar(access_token: str) -> Optional[str]:
    """Upload a dummy avatar and return its MXC URI."""
    # A small red dot (1x1 PNG)
    IMAGE_DATA = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02"
        b"\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\xda\x63\xf8\xff\xff\x3f\x00\x05"
        b"\xfe\x02\xfe\xdc\x44\x74\x06\x00\x00\x00\x00IEND\xaeB`\x82"
    )

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "image/png",
    }

    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/media/v3/upload",
        data=IMAGE_DATA,
        headers=headers,
    )

    if response.status_code == 200:
        mxc_uri = response.json().get("content_uri")
        print(f"✓ Uploaded dummy avatar: {mxc_uri}")
        return mxc_uri
    else:
        print(f"✗ Failed to upload avatar: {response.status_code} {response.text}")
        return None


def set_room_avatar(access_token: str, room_id: str, mxc_uri: str) -> bool:
    """Set the avatar for a room."""
    headers = {"Authorization": f"Bearer {access_token}"}
    payload = {"url": mxc_uri}

    response = requests.put(
        f"{SYNAPSE_URL}/_matrix/client/v3/rooms/{room_id}/state/m.room.avatar/",
        json=payload,
        headers=headers,
    )

    if response.status_code == 200:
        print(f"  ✓ Set room avatar to {mxc_uri}")
        return True
    else:
        print(f"  ⚠ Failed to set room avatar: {response.status_code} {response.text}")
        return False


def main():
    """Initialize Matrix test server."""
    print("Initializing Matrix Synapse test server...")
    print()

    # Wait for server to be ready
    if not wait_for_server():
        sys.exit(1)

    print()
    print("Creating test users...")
    users = {}
    for user_config in TEST_USERS:
        # Register testadmin as a server admin (needed to publish rooms to public directory)
        if user_config["username"] == "testadmin":
            user_data = register_admin_user(
                user_config["username"],
                user_config["password"],
                user_config["display_name"],
            )
        else:
            user_data = register_user(
                user_config["username"],
                user_config["password"],
                user_config["display_name"],
            )
        if user_data:
            # Store both the user_id and username for later use
            users[user_config["username"]] = {
                "user_id": user_data.get("user_id"),
                "username": user_config["username"],
                "password": user_config["password"],
            }

    print()
    print("Creating test rooms and populating with data...")
    rooms = {}

    # Log in as testadmin (kept for future use; not currently used for publishing)
    admin_token = None
    if "testadmin" in users:
        admin_token = login_user(
            users["testadmin"]["user_id"], users["testadmin"]["password"]
        )
        if admin_token:
            print("✓ Admin token acquired")
        else:
            print("⚠ Could not get admin token")

    # Use first user to create rooms and post messages
    if users:
        first_username = list(users.keys())[0]
        first_user = users[first_username]
        # Login using the user_id that was returned by registration
        token = login_user(first_user["user_id"], first_user["password"])

        if token:
            for room_config in TEST_ROOMS:
                room_id = create_room(
                    token,
                    room_config["name"],
                    room_config["topic"],
                )
                if room_id:
                    rooms[room_config["name"]] = room_id

                    # Invite other users and make them join first.
                    # We need the room creator (token) OR an admin (admin_token) to be
                    # a member before we can publish the room to the public directory.
                    if room_config.get("invite_users", True):
                        for username, user_info in users.items():
                            if user_info["user_id"] != first_user["user_id"]:
                                # Invite
                                payload = {"user_id": user_info["user_id"]}
                                requests.post(
                                    f"{SYNAPSE_URL}/_matrix/client/v3/rooms/{room_id}/invite",
                                    json=payload,
                                    headers={"Authorization": f"Bearer {token}"},
                                )
                                # Login as that user and join
                                other_token = login_user(
                                    user_info["user_id"], user_info["password"]
                                )
                                if other_token:
                                    join_room(other_token, room_id)
                                    print(f"  ✓ User {username} joined room")
                    else:
                        print(f"  ℹ Skipping user invites for room (discovery test)")

                    # Publish room to directory AFTER joining.
                    # The standard Matrix client API requires room membership to publish.
                    # The room creator (token) is always a member (they created the room),
                    # so we can use their token directly.
                    publish_room(token, room_id, use_admin_api=False)

                    # Populate with text messages if configured
                    if room_config.get("populate_with_messages", False):
                        populate_room_with_messages(
                            token,
                            room_id,
                            room_config["message_count"],
                        )

                    # Seed media messages (image, video, audio) if configured
                    if room_config.get("seed_media", False):
                        seed_media_messages(token, room_id)

                    # Set avatar if configured
                    if room_config.get("has_avatar", False):
                        mxc_uri = upload_avatar(token)
                        if mxc_uri:
                            set_room_avatar(token, room_id, mxc_uri)

    print()
    print("=" * 60)
    print("✅ Matrix test server initialized successfully!")
    print("=" * 60)
    print()
    print("📝 Test Users:")
    for username, data in users.items():
        print(f"  {username}")
        print(f"    ID: {data['user_id']}")
        print(f"    Password: {data['password']}")

    print()
    print("🏠 Test Rooms:")
    for room_config in TEST_ROOMS:
        room_name = room_config["name"]
        room_id = rooms.get(room_name, "N/A")
        status = (
            "with messages" if room_config.get("populate_with_messages") else "empty"
        )
        print(f"  {room_name} ({status})")
        print(f"    ID: {room_id}")

    print()
    print("🔑 Test Credentials for Integration Tests:")
    print(f"  Server:    {SYNAPSE_URL}")
    print(f"  Test User: testuser1")
    print(f"  Password:  testpass123")
    print()
    print("Room Status:")
    print(
        f"  test_general - 5 text + image/video/audio messages (for testing message lists and media rendering)"
    )
    print(
        f"  test_photos  - 3 text + image/video/audio messages (for testing photo/media content)"
    )
    print(f"  test_art     - 0 messages (for testing empty rooms)")

    # Verify rooms are in the public directory
    if users:
        first_username = list(users.keys())[0]
        first_user = users[first_username]
        verify_token = login_user(first_user["user_id"], first_user["password"])
        if verify_token:
            print()
            verify_public_rooms(verify_token)
    print()


if __name__ == "__main__":
    main()
