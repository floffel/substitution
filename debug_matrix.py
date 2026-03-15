
import requests
import json

SYNAPSE_URL = "http://localhost:8008"

def main():
    # Login as testuser1
    payload = {
        "type": "m.login.password",
        "user": "testuser1",
        "password": "testpass123",
    }
    resp = requests.post(f"{SYNAPSE_URL}/_matrix/client/r0/login", json=payload)
    if resp.status_code != 200:
        print(f"Login failed: {resp.text}")
        return
    
    token = resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # Query public rooms
    print("Querying public rooms...")
    resp = requests.post(f"{SYNAPSE_URL}/_matrix/client/r0/publicRooms", json={}, headers=headers)
    if resp.status_code == 200:
        data = resp.json()
        print(f"Found {len(data.get('chunk', []))} rooms.")
        for room in data.get('chunk', []):
            print(f" - {room.get('name')} ({room.get('room_id')})")
    else:
        print(f"Query failed: {resp.text}")

if __name__ == "__main__":
    main()
