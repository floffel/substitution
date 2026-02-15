#!/usr/bin/env python3
"""
Initialize Matrix Synapse test server with test users, rooms, and messages.
This script is run as part of the Docker startup process.
"""

import requests
import json
import sys
import time
from typing import Dict, Any, Optional

# Configuration
# Use Docker service name when running in Docker, or localhost when running locally
SYNAPSE_URL = "http://matrix-synapse:8008"

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
    },
    {
        "name": "test_photos",
        "topic": "Photo sharing test room",
        "populate_with_messages": True,  # Will have messages
        "message_count": 3,
        "invite_users": True,  # Invite all users
    },
    {
        "name": "test_art",
        "topic": "Art community test room",
        "populate_with_messages": False,  # Empty room - no messages
        "message_count": 0,
        "invite_users": True,  # Invite all users
    },
    {
        "name": "test_invite_only",
        "topic": "Room to test joining/discovery",
        "populate_with_messages": True,  # Some messages to find
        "message_count": 2,
        "invite_users": False,  # Do NOT invite users - they must discover and join
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
    elif response.status_code == 400 and "user_in_use" in response.text:
        print(f"ℹ User already exists: {username}")
        return {"user_id": f"@{username}:test.matrix.local"}
    else:
        print(f"✗ Failed to create user {username}: {response.status_code}")
        return None


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
        f"{SYNAPSE_URL}/_matrix/client/r0/createRoom",
        json=payload,
        headers=headers,
    )

    if response.status_code in [200, 201]:
        data = response.json()
        room_id = data.get("room_id")
        print(f"✓ Created room: {room_name} ({room_id})")
        return room_id
    else:
        print(f"✗ Failed to create room {room_name}: {response.status_code}")
        return None


def invite_users_to_room(access_token: str, room_id: str, user_ids: list) -> bool:
    """Invite users to a room."""
    headers = {"Authorization": f"Bearer {access_token}"}

    for user_id in user_ids:
        payload = {"user_id": user_id}
        response = requests.post(
            f"{SYNAPSE_URL}/_matrix/client/r0/rooms/{room_id}/invite",
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

                    # Invite other users to the room (if configured)
                    if room_config.get("invite_users", True):
                        other_users = [
                            u["user_id"]
                            for u in users.values()
                            if u["user_id"] != first_user["user_id"]
                        ]
                        invite_users_to_room(token, room_id, other_users)
                    else:
                        print(f"  ℹ Skipping user invites for room (discovery test)")

                    # Populate with messages if configured
                    if room_config.get("populate_with_messages", False):
                        print(
                            f"  Populating room with {room_config['message_count']} messages..."
                        )
                        populate_room_with_messages(
                            token,
                            room_id,
                            room_config["message_count"],
                        )

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
    print(f"  test_general - 5 messages (for testing message lists)")
    print(f"  test_photos  - 3 messages (for testing photo content)")
    print(f"  test_art     - 0 messages (for testing empty rooms)")
    print()


if __name__ == "__main__":
    main()
