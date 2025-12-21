from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles 

import json

app = FastAPI()

# Enable CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store connected clients with their roles
clients = []

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    
    # Assign role based on connection order
    role = "initiator" if len(clients) == 0 else "responder"
    clients.append(websocket)
    
    print(f"Client connected as {role}. Total clients: {len(clients)}")
    
    # Send role assignment to the client
    await websocket.send_text(json.dumps({
        "type": "role",
        "role": role
    }))

    # If this is the responder (second peer), notify the initiator
    if role == "responder" and len(clients) == 2:
        # Find the initiator (first client in the list)
        initiator = clients[0]
        try:
            await initiator.send_text(json.dumps({"type": "peer-connected"}))
        except:
            pass
    
    try:
        while True:
            # Receive message from this client
            data = await websocket.receive_text()
            print(f"Received from {role}: {data[:100]}...")
            
            # Broadcast to all other clients
            for client in clients:
                if client != websocket:
                    try:
                        await client.send_text(data)
                    except:
                        pass
                        
    except WebSocketDisconnect:
        clients.remove(websocket)
        print(f"Client disconnected ({role}). Total clients: {len(clients)}")

# Must be added after WebSocket route
app.mount("/", StaticFiles(directory="server/static", html=True), name="static")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)