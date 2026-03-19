#!/usr/bin/env python3
"""
Initialize Matrix Synapse test server with visually rich data for Play Store screenshots.

This script creates realistic users, rooms, messages, and DM conversations
so that every app screen looks populated and appealing in automated screenshots.

Usage (via Docker Compose):
    docker compose -f docker-compose.yml -f docker-compose.screenshots.yml run --rm matrix-init
"""

import requests
import json
import sys
import time
import hmac
import hashlib
import struct
import zlib
from typing import Dict, Any, Optional, List

# Configuration
SYNAPSE_URL = "http://matrix-synapse:8008"
REGISTRATION_SHARED_SECRET = "test_registration_secret"

# ---------------------------------------------------------------------------
# Test users — realistic names and distinct avatar colours
# ---------------------------------------------------------------------------
TEST_USERS = [
    {
        "username": "testuser1",
        "password": "testpass123",
        "display_name": "Alice Chen",
        "avatar_color": (91, 140, 90),  # sage green (brand color)
    },
    {
        "username": "testuser2",
        "password": "testpass123",
        "display_name": "Marcus Webb",
        "avatar_color": (79, 120, 176),  # calm blue
    },
    {
        "username": "testuser3",
        "password": "testpass123",
        "display_name": "Sophia Rivera",
        "avatar_color": (176, 97, 134),  # dusty rose
    },
    {
        "username": "testadmin",
        "password": "testpass123",
        "display_name": "Test Admin",
        "avatar_color": (140, 140, 140),  # neutral grey
    },
]

# ---------------------------------------------------------------------------
# Rooms with curated content
# ---------------------------------------------------------------------------
TEST_ROOMS = [
    {
        "name": "photography",
        "display_name": "Photography",
        "topic": "Share your best shots and get inspired by others",
        "invite_users": True,
        "has_avatar": True,
        "avatar_color": (65, 105, 135),  # steel blue
        "messages": [
            {
                "user": "testuser2",
                "body": "Golden hour at the coast today was absolutely stunning",
                "html": "<p>Golden hour at the coast today was absolutely stunning</p>",
            },
            {
                "user": "testuser3",
                "body": "Just got back from a week in the mountains. The light at dawn is something else",
                "html": "<p>Just got back from a week in the mountains. The light at dawn is something else</p>",
            },
            {
                "user": "testuser1",
                "body": "Does anyone have tips for street photography at night? I keep struggling with noise",
                "html": "<p>Does anyone have tips for street photography at night? I keep struggling with noise</p>",
            },
            {
                "user": "testuser2",
                "body": "Try lowering your shutter speed and bracing against a wall. Also, modern sensors handle ISO 3200 really well",
                "html": "<p>Try lowering your shutter speed and bracing against a wall. Also, modern sensors handle ISO 3200 really well</p>",
            },
            {
                "user": "testuser3",
                "body": "I love how film grain looks in night shots. Sometimes the noise is the aesthetic",
                "html": "<p>I love how film grain looks in night shots. Sometimes the <em>noise</em> is the aesthetic</p>",
            },
        ],
        "seed_media": True,
    },
    {
        "name": "digital_art",
        "display_name": "Digital Art",
        "topic": "A community for digital artists to share work and techniques",
        "invite_users": True,
        "has_avatar": True,
        "avatar_color": (156, 89, 182),  # purple
        "messages": [
            {
                "user": "testuser3",
                "body": "Just finished a new piece inspired by Art Nouveau. Took about 20 hours",
                "html": "<p>Just finished a new piece inspired by Art Nouveau. Took about 20 hours</p>",
            },
            {
                "user": "testuser1",
                "body": "That sounds amazing! What software do you use?",
                "html": "<p>That sounds amazing! What software do you use?</p>",
            },
            {
                "user": "testuser3",
                "body": "Mostly Procreate on iPad, but I do the final touches in Photoshop",
                "html": "<p>Mostly Procreate on iPad, but I do the final touches in Photoshop</p>",
            },
            {
                "user": "testuser2",
                "body": "Has anyone tried the new AI-assisted brushes? Curious whether they actually save time",
                "html": "<p>Has anyone tried the new AI-assisted brushes? Curious whether they actually save time</p>",
            },
        ],
        "seed_media": True,
    },
    {
        "name": "creative_writing",
        "display_name": "Creative Writing",
        "topic": "Short stories, poetry, and prompts",
        "invite_users": True,
        "has_avatar": True,
        "avatar_color": (192, 148, 93),  # warm amber
        "messages": [
            {
                "user": "testuser1",
                "body": "Writing prompt for today: 'The last letter arrived on a Tuesday'",
                "html": "<p><strong>Writing prompt for today:</strong> <em>'The last letter arrived on a Tuesday'</em></p>",
            },
            {
                "user": "testuser2",
                "body": "Oh I love this one. Gives me epistolary novel vibes. Working on something now",
                "html": "<p>Oh I love this one. Gives me epistolary novel vibes. Working on something now</p>",
            },
            {
                "user": "testuser3",
                "body": "Just published my short story collection! It's been two years in the making",
                "html": "<p>Just published my short story collection! It's been two years in the making</p>",
            },
        ],
        "seed_media": False,
    },
    {
        "name": "music_production",
        "display_name": "Music Production",
        "topic": "Beats, mixing tips, and collaboration",
        "invite_users": True,
        "has_avatar": True,
        "avatar_color": (200, 100, 80),  # coral
        "messages": [
            {
                "user": "testuser2",
                "body": "New ambient track dropped. Feedback welcome",
                "html": "<p>New ambient track dropped. Feedback welcome</p>",
            },
            {
                "user": "testuser1",
                "body": "The reverb on the intro is gorgeous. What plugin are you using?",
                "html": "<p>The reverb on the intro is gorgeous. What plugin are you using?</p>",
            },
            {
                "user": "testuser3",
                "body": "Looking for a vocalist for a lo-fi project. Anyone interested?",
                "html": "<p>Looking for a vocalist for a lo-fi project. Anyone interested?</p>",
            },
            {
                "user": "testuser2",
                "body": "I might be! Send me some demos and I'll see if my style fits",
                "html": "<p>I might be! Send me some demos and I'll see if my style fits</p>",
            },
        ],
        "seed_media": False,
    },
    {
        "name": "open_studio",
        "display_name": "Open Studio",
        "topic": "Behind-the-scenes looks at creative processes",
        "invite_users": True,
        "has_avatar": True,
        "avatar_color": (100, 160, 130),  # muted teal
        "messages": [
            {
                "user": "testuser1",
                "body": "Rearranged my workspace today. Natural light makes such a difference",
                "html": "<p>Rearranged my workspace today. Natural light makes such a difference</p>",
            },
            {
                "user": "testuser3",
                "body": "My process: sketch on paper, scan, vector trace, color in digital. Old school meets new school",
                "html": "<p>My process: sketch on paper, scan, vector trace, color in digital. Old school meets new school</p>",
            },
        ],
        "seed_media": True,
    },
    {
        "name": "test_invite_only",
        "display_name": "Invite Only Room",
        "topic": "Room to test joining/discovery",
        "invite_users": False,
        "has_avatar": False,
        "avatar_color": None,
        "messages": [
            {
                "user": "testuser1",
                "body": "This room is for testing discovery",
                "html": None,
            },
        ],
        "seed_media": False,
    },
]

# ---------------------------------------------------------------------------
# DM conversations (so Messages tab is populated)
# ---------------------------------------------------------------------------
DM_CONVERSATIONS = [
    {
        "between": ("testuser1", "testuser2"),
        "messages": [
            ("testuser2", "Hey Alice! Loved your latest post in Photography"),
            ("testuser1", "Thanks Marcus! The lighting was really lucky that day"),
            (
                "testuser2",
                "Do you want to do a collab sometime? I've been experimenting with long exposures",
            ),
            (
                "testuser1",
                "Yes! That sounds great. Let's plan something for next weekend",
            ),
        ],
    },
    {
        "between": ("testuser1", "testuser3"),
        "messages": [
            ("testuser3", "Hi! I saw your writing prompt today. Really inspiring"),
            ("testuser1", "Thank you Sophia! Did you write something for it?"),
            (
                "testuser3",
                "Working on it right now. I'll share it in the room when it's done",
            ),
        ],
    },
]


# ===========================================================================
# Image generation helpers
# ===========================================================================


def _make_png(width: int, height: int, rgb: tuple) -> bytes:
    """Create a minimal solid-colour PNG image in pure Python."""
    r, g, b = rgb

    # Build raw image data (filter byte 0 + RGB pixels per row)
    raw_data = b""
    for _ in range(height):
        raw_data += b"\x00"  # filter: None
        raw_data += bytes([r, g, b]) * width

    compressed = zlib.compress(raw_data)

    def _chunk(chunk_type: bytes, data: bytes) -> bytes:
        c = chunk_type + data
        crc = struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack(">I", len(data)) + c + crc

    png = b"\x89PNG\r\n\x1a\n"
    # IHDR
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png += _chunk(b"IHDR", ihdr_data)
    # IDAT
    png += _chunk(b"IDAT", compressed)
    # IEND
    png += _chunk(b"IEND", b"")
    return png


def _make_gradient_png(width: int, height: int, color1: tuple, color2: tuple) -> bytes:
    """Create a vertical gradient PNG from color1 (top) to color2 (bottom)."""
    raw_data = b""
    for y in range(height):
        raw_data += b"\x00"  # filter: None
        t = y / max(height - 1, 1)
        r = int(color1[0] * (1 - t) + color2[0] * t)
        g = int(color1[1] * (1 - t) + color2[1] * t)
        b = int(color1[2] * (1 - t) + color2[2] * t)
        raw_data += bytes([r, g, b]) * width

    compressed = zlib.compress(raw_data)

    def _chunk(chunk_type: bytes, data: bytes) -> bytes:
        c = chunk_type + data
        crc = struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack(">I", len(data)) + c + crc

    png = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png += _chunk(b"IHDR", ihdr_data)
    png += _chunk(b"IDAT", compressed)
    png += _chunk(b"IEND", b"")
    return png


# ===========================================================================
# Matrix API helpers (reused from init_test_data.py)
# ===========================================================================


def wait_for_server(max_attempts: int = 30) -> bool:
    for attempt in range(max_attempts):
        try:
            response = requests.get(f"{SYNAPSE_URL}/_matrix/client/versions", timeout=5)
            if response.status_code == 200:
                print("Server is ready")
                return True
        except requests.ConnectionError:
            pass
        if attempt < max_attempts - 1:
            time.sleep(2)
    print(f"Server did not become ready after {max_attempts * 2}s")
    return False


def register_user(
    username: str, password: str, display_name: str
) -> Optional[Dict[str, Any]]:
    payload = {
        "auth": {"type": "m.login.dummy"},
        "username": username,
        "password": password,
        "initial_device_display_name": display_name,
    }
    response = requests.post(f"{SYNAPSE_URL}/_matrix/client/r0/register", json=payload)
    if response.status_code in [200, 201]:
        print(f"  Created user: {username}")
        return response.json()
    elif response.status_code == 400:
        print(f"  User likely already exists: {username}")
        return {"user_id": f"@{username}:test.matrix.local"}
    else:
        print(
            f"  Failed to create user {username}: {response.status_code} {response.text}"
        )
        return None


def register_admin_user(
    username: str, password: str, display_name: str
) -> Optional[Dict[str, Any]]:
    nonce_response = requests.get(f"{SYNAPSE_URL}/_synapse/admin/v1/register")
    if nonce_response.status_code != 200:
        return None
    nonce = nonce_response.json().get("nonce")
    if not nonce:
        return None
    mac_payload = "\x00".join([nonce, username, password, "admin"])
    mac = hmac.new(
        REGISTRATION_SHARED_SECRET.encode("utf-8"),
        mac_payload.encode("utf-8"),
        hashlib.sha1,
    ).hexdigest()
    payload = {
        "nonce": nonce,
        "username": username,
        "password": password,
        "displayname": display_name,
        "admin": True,
        "mac": mac,
    }
    response = requests.post(f"{SYNAPSE_URL}/_synapse/admin/v1/register", json=payload)
    if response.status_code in [200, 201]:
        print(f"  Created admin user: {username}")
        return response.json()
    elif response.status_code == 400 and "already" in response.text.lower():
        print(f"  Admin user likely already exists: {username}")
        return {"user_id": f"@{username}:test.matrix.local"}
    else:
        return register_user(username, password, display_name)


def login_user(user_id: str, password: str) -> Optional[str]:
    payload = {"type": "m.login.password", "user": user_id, "password": password}
    response = requests.post(f"{SYNAPSE_URL}/_matrix/client/r0/login", json=payload)
    if response.status_code == 200:
        return response.json().get("access_token")
    else:
        print(f"  Failed to login {user_id}: {response.status_code}")
        return None


def upload_media(
    access_token: str, data: bytes, content_type: str, filename: str
) -> Optional[str]:
    headers = {"Authorization": f"Bearer {access_token}", "Content-Type": content_type}
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/media/v3/upload",
        data=data,
        headers=headers,
        params={"filename": filename},
    )
    if response.status_code == 200:
        return response.json().get("content_uri")
    else:
        print(f"  Failed to upload {filename}: {response.status_code}")
        return None


def set_display_name(access_token: str, user_id: str, display_name: str) -> bool:
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.put(
        f"{SYNAPSE_URL}/_matrix/client/v3/profile/{user_id}/displayname",
        json={"displayname": display_name},
        headers=headers,
    )
    return response.status_code == 200


def set_avatar_url(access_token: str, user_id: str, mxc_uri: str) -> bool:
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.put(
        f"{SYNAPSE_URL}/_matrix/client/v3/profile/{user_id}/avatar_url",
        json={"avatar_url": mxc_uri},
        headers=headers,
    )
    return response.status_code == 200


def create_room(
    access_token: str, room_alias: str, room_name: str, topic: str
) -> Optional[str]:
    payload = {
        "visibility": "public",
        "room_alias_name": room_alias,
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
            {
                "type": "m.room.power_levels",
                "content": {
                    "users": {
                        "@testuser1:test.matrix.local": 100,
                        "@testuser2:test.matrix.local": 100,
                        "@testuser3:test.matrix.local": 100,
                        "@testadmin:test.matrix.local": 100,
                    },
                    "users_default": 0,
                    "events_default": 0,
                    "state_default": 50,
                    "ban": 50,
                    "kick": 50,
                    "redact": 50,
                    "invite": 0,
                },
                "state_key": "",
            },
        ],
    }
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/v3/createRoom", json=payload, headers=headers
    )
    if response.status_code in [200, 201]:
        room_id = response.json().get("room_id")
        print(f"  Created room: {room_name} ({room_id})")
        return room_id
    elif response.status_code == 400:
        alias = f"#{room_alias}:test.matrix.local"
        resolve = requests.get(
            f"{SYNAPSE_URL}/_matrix/client/v3/directory/room/{alias.replace('#', '%23')}"
        )
        if resolve.status_code == 200:
            room_id = resolve.json().get("room_id")
            print(f"  Room already exists: {room_name} ({room_id})")
            return room_id
    print(
        f"  Failed to create room {room_name}: {response.status_code} {response.text}"
    )
    return None


def publish_room(access_token: str, room_id: str) -> bool:
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.put(
        f"{SYNAPSE_URL}/_matrix/client/v3/directory/list/room/{room_id}",
        json={"visibility": "public"},
        headers=headers,
    )
    return response.status_code == 200


def join_room(access_token: str, room_id: str) -> bool:
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/v3/join/{room_id}", json={}, headers=headers
    )
    return response.status_code == 200


def mark_room_as_substitution(access_token: str, room_id: str, user_id: str) -> bool:
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.put(
        f"{SYNAPSE_URL}/_matrix/client/v3/user/{user_id}/rooms/{room_id}/account_data/substitution",
        json={"joined": True},
        headers=headers,
    )
    return response.status_code == 200


def post_message(
    access_token: str, room_id: str, body: str, html: Optional[str] = None
) -> bool:
    headers = {"Authorization": f"Bearer {access_token}"}
    payload: Dict[str, Any] = {"msgtype": "m.text", "body": body}
    if html:
        payload["format"] = "org.matrix.custom.html"
        payload["formatted_body"] = html
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/r0/rooms/{room_id}/send/m.room.message",
        json=payload,
        headers=headers,
    )
    return response.status_code in [200, 201]


def post_image(
    access_token: str, room_id: str, mxc_uri: str, w: int, h: int, size: int
) -> bool:
    headers = {"Authorization": f"Bearer {access_token}"}
    payload = {
        "msgtype": "m.image",
        "body": "photo.png",
        "url": mxc_uri,
        "info": {"mimetype": "image/png", "size": size, "w": w, "h": h},
    }
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/r0/rooms/{room_id}/send/m.room.message",
        json=payload,
        headers=headers,
    )
    return response.status_code in [200, 201]


def set_room_avatar(access_token: str, room_id: str, mxc_uri: str) -> bool:
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.put(
        f"{SYNAPSE_URL}/_matrix/client/v3/rooms/{room_id}/state/m.room.avatar/",
        json={"url": mxc_uri},
        headers=headers,
    )
    return response.status_code == 200


def create_dm(
    token_a: str,
    user_a_id: str,
    token_b: str,
    user_b_id: str,
    messages: List[tuple],
    tokens_by_user: Dict[str, str],
) -> Optional[str]:
    """Create a DM room between two users and populate it with messages."""
    headers = {"Authorization": f"Bearer {token_a}"}
    payload = {
        "is_direct": True,
        "invite": [user_b_id],
        "preset": "trusted_private_chat",
    }
    response = requests.post(
        f"{SYNAPSE_URL}/_matrix/client/v3/createRoom", json=payload, headers=headers
    )
    if response.status_code not in [200, 201]:
        print(f"  Failed to create DM: {response.status_code}")
        return None

    room_id = response.json().get("room_id")
    print(f"  Created DM between {user_a_id} and {user_b_id} ({room_id})")

    # User B joins
    join_room(token_b, room_id)

    # Mark as direct message in account data for both users
    for uid, tok in [(user_a_id, token_a), (user_b_id, token_b)]:
        other = user_b_id if uid == user_a_id else user_a_id
        h = {"Authorization": f"Bearer {tok}"}
        # Get current m.direct data
        resp = requests.get(
            f"{SYNAPSE_URL}/_matrix/client/v3/user/{uid}/account_data/m.direct",
            headers=h,
        )
        direct_data = resp.json() if resp.status_code == 200 else {}
        rooms_list = direct_data.get(other, [])
        if room_id not in rooms_list:
            rooms_list.append(room_id)
        direct_data[other] = rooms_list
        requests.put(
            f"{SYNAPSE_URL}/_matrix/client/v3/user/{uid}/account_data/m.direct",
            json=direct_data,
            headers=h,
        )

    # Post messages
    for sender_username, msg_body in messages:
        sender_token = tokens_by_user.get(sender_username)
        if sender_token:
            post_message(sender_token, room_id, msg_body)
            time.sleep(0.05)  # small delay for ordering

    return room_id


# ===========================================================================
# Main
# ===========================================================================


def main():
    print("=" * 60)
    print("Initializing Matrix server with SCREENSHOT data")
    print("=" * 60)
    print()

    if not wait_for_server():
        sys.exit(1)

    # -----------------------------------------------------------------------
    # 1. Register users
    # -----------------------------------------------------------------------
    print("\n--- Creating users ---")
    users: Dict[str, Dict[str, Any]] = {}
    for u in TEST_USERS:
        if u["username"] == "testadmin":
            data = register_admin_user(u["username"], u["password"], u["display_name"])
        else:
            data = register_user(u["username"], u["password"], u["display_name"])
        if data:
            users[u["username"]] = {
                "user_id": data.get("user_id", f"@{u['username']}:test.matrix.local"),
                "password": u["password"],
                "display_name": u["display_name"],
                "avatar_color": u.get("avatar_color"),
            }

    # -----------------------------------------------------------------------
    # 2. Login all users and set profiles
    # -----------------------------------------------------------------------
    print("\n--- Logging in users and setting profiles ---")
    tokens: Dict[str, str] = {}
    for username, info in users.items():
        token = login_user(info["user_id"], info["password"])
        if token:
            tokens[username] = token
            # Set display name
            set_display_name(token, info["user_id"], info["display_name"])
            # Upload and set avatar
            if info.get("avatar_color"):
                avatar_png = _make_png(64, 64, info["avatar_color"])
                mxc = upload_media(
                    token, avatar_png, "image/png", f"avatar_{username}.png"
                )
                if mxc:
                    set_avatar_url(token, info["user_id"], mxc)
                    print(f"  Set avatar for {username}")

    if "testuser1" not in tokens:
        print("FATAL: Could not login testuser1")
        sys.exit(1)

    creator_token = tokens["testuser1"]
    creator_id = users["testuser1"]["user_id"]

    # -----------------------------------------------------------------------
    # 3. Create rooms, invite users, post messages
    # -----------------------------------------------------------------------
    print("\n--- Creating rooms ---")
    rooms: Dict[str, str] = {}

    for room_cfg in TEST_ROOMS:
        room_id = create_room(
            creator_token,
            room_cfg["name"],
            room_cfg["display_name"],
            room_cfg["topic"],
        )
        if not room_id:
            continue

        rooms[room_cfg["name"]] = room_id

        # Mark as substitution room for testuser1
        mark_room_as_substitution(creator_token, room_id, creator_id)

        # Publish to directory
        publish_room(creator_token, room_id)

        # Invite and join other users
        if room_cfg.get("invite_users", True):
            for username, info in users.items():
                if info["user_id"] != creator_id and username in tokens:
                    requests.post(
                        f"{SYNAPSE_URL}/_matrix/client/v3/rooms/{room_id}/invite",
                        json={"user_id": info["user_id"]},
                        headers={"Authorization": f"Bearer {creator_token}"},
                    )
                    join_room(tokens[username], room_id)
                    # Also mark as substitution room for this user
                    mark_room_as_substitution(
                        tokens[username], room_id, info["user_id"]
                    )

        # Set room avatar
        if room_cfg.get("has_avatar") and room_cfg.get("avatar_color"):
            avatar_png = _make_png(64, 64, room_cfg["avatar_color"])
            mxc = upload_media(
                creator_token, avatar_png, "image/png", f"room_{room_cfg['name']}.png"
            )
            if mxc:
                set_room_avatar(creator_token, room_id, mxc)

        # Post messages from the appropriate users
        for msg in room_cfg.get("messages", []):
            sender = msg["user"]
            sender_token = tokens.get(sender, creator_token)
            post_message(sender_token, room_id, msg["body"], msg.get("html"))
            time.sleep(0.05)

        # Seed image posts for rooms that want media
        if room_cfg.get("seed_media"):
            # Create a gradient image that looks more interesting than a solid colour
            base_color = room_cfg.get("avatar_color", (100, 150, 200))
            lighter = tuple(min(255, c + 60) for c in base_color)
            img_data = _make_gradient_png(320, 240, base_color, lighter)
            mxc = upload_media(creator_token, img_data, "image/png", "sample_photo.png")
            if mxc:
                post_image(creator_token, room_id, mxc, 320, 240, len(img_data))
                print(f"  Posted sample image to {room_cfg['display_name']}")

        print(f"  Finished setting up room: {room_cfg['display_name']}")

    # -----------------------------------------------------------------------
    # 4. Create DM conversations
    # -----------------------------------------------------------------------
    print("\n--- Creating DM conversations ---")
    for dm in DM_CONVERSATIONS:
        user_a, user_b = dm["between"]
        if user_a in tokens and user_b in tokens:
            create_dm(
                tokens[user_a],
                users[user_a]["user_id"],
                tokens[user_b],
                users[user_b]["user_id"],
                dm["messages"],
                tokens,
            )

    # -----------------------------------------------------------------------
    # Done
    # -----------------------------------------------------------------------
    print()
    print("=" * 60)
    print("Screenshot data initialized successfully!")
    print("=" * 60)
    print()
    print("Users:")
    for username, info in users.items():
        print(f"  {info['display_name']} (@{username})")
    print()
    print("Rooms:")
    for room_cfg in TEST_ROOMS:
        name = room_cfg["display_name"]
        n_msgs = len(room_cfg.get("messages", []))
        print(f"  {name} ({n_msgs} messages)")
    print()
    print(f"DM conversations: {len(DM_CONVERSATIONS)}")
    print()
    print("Login credentials:")
    print(f"  Server:   {SYNAPSE_URL}")
    print(f"  User:     testuser1")
    print(f"  Password: testpass123")


if __name__ == "__main__":
    main()
