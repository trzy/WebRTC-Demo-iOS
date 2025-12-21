// WebRTC P2P Chat with WebSocket Signaling

let pc = null;
let dataChannel = null;
let ws = null;
let myRole = null;
let iceCandidateQueue = [];

// ICE servers for NAT traversal
const config = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' }
    ]
};

// UI Elements
const connectBtn = document.getElementById('connectBtn');
const sendBtn = document.getElementById('sendBtn');
const messageInput = document.getElementById('messageInput');
const messagesDiv = document.getElementById('messages');
const statusDiv = document.getElementById('status');

function enqueueICECandidate(candidate) {
    iceCandidateQueue.push(candidate);
}

async function processEnqueuedICECandidates() {
    for (const candidate of iceCandidateQueue) {
        await pc.addIceCandidate(candidate);
    }
    iceCandidateQueue = [];
}

// Connect to signaling server
connectBtn.onclick = () => {
    ws = new WebSocket('ws://localhost:8000/ws');
    
    ws.onopen = () => {
        updateStatus('Connected to signaling server, waiting for role assignment...');
        connectBtn.disabled = true;
    };
    
    ws.onmessage = async (event) => {
        const data = JSON.parse(event.data);
        console.log('Signaling message:', data.type);
        
        if (data.type === 'role') {
            // Server assigned us a role
            myRole = data.role;
            updateStatus(`Role: ${myRole}`);
            
            if (myRole === 'initiator') {
                // We're the first peer, wait for responder
                updateStatus('Waiting for peer to connect...');
            } else {
                // We're the responder, wait for offer
                updateStatus('Connected as responder, waiting for offer...');
            }
            
        } else if (data.type === 'offer') {
            // Responder receives offer
            if (!pc) {
                initPeerConnection();
            }
            await pc.setRemoteDescription(data);
            await processEnqueuedICECandidates();
            
            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            ws.send(JSON.stringify(pc.localDescription));
            updateStatus('Sent answer, establishing connection...');
            
        } else if (data.type === 'answer') {
            // Initiator receives answer
            await pc.setRemoteDescription(data);
            await processEnqueuedICECandidates();
            updateStatus('Received answer, establishing connection...');
            
        } else if (data.type === 'ice-candidate' && data.candidate) {
            try {
                if (pc && pc.remoteDescription) {
                    await pc.addIceCandidate(data.candidate);
                } else {
                    enqueueICECandidate(data.candidate);
                }
            } catch (err) {
                console.error('Error adding ICE candidate:', err);
            }
        } else if (data.type === 'peer-connected') {
            // Server notifies initiator that responder connected
            if (myRole === 'initiator') {
                updateStatus('Peer connected, creating offer...');
                initPeerConnection();
                createOffer();
            }
        }
    };
    
    ws.onerror = (err) => {
        updateStatus('WebSocket error - is server running?');
        console.error('WebSocket error:', err);
    };
    
    ws.onclose = () => {
        updateStatus('Disconnected from signaling server');
        connectBtn.disabled = false;
    };
};

// Initialize peer connection
function initPeerConnection() {
    pc = new RTCPeerConnection(config);
    
    // ICE candidate handling
    pc.onicecandidate = (e) => {
        if (e.candidate) {
            ws.send(JSON.stringify({
                type: 'ice-candidate',
                candidate: e.candidate
            }));
        }
    };
    
    // Connection state
    pc.onconnectionstatechange = () => {
        updateStatus('Connection: ' + pc.connectionState);
        if (pc.connectionState === 'connected') {
            updateStatus('WebRTC Connected! You can now chat.');
        }
    };
    
    // Data channel from remote peer
    pc.ondatachannel = (e) => {
        dataChannel = e.channel;
        setupDataChannel();
    };
    
    // If we're initiator, create data channel
    if (myRole === 'initiator') {
        dataChannel = pc.createDataChannel('chat');
        setupDataChannel();
    }
}

// Setup data channel handlers
function setupDataChannel() {
    dataChannel.onopen = () => {
        updateStatus('Data channel open! You can now chat.');
        sendBtn.disabled = false;
    };
    
    dataChannel.onclose = () => {
        updateStatus('Data channel closed');
        sendBtn.disabled = true;
    };
    
    dataChannel.onmessage = (e) => {
        addMessage('Peer: ' + e.data, 'received');
    };
}

// Create offer (initiator only)
async function createOffer() {
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    ws.send(JSON.stringify(pc.localDescription));
    updateStatus('Sent offer, waiting for answer...');
}

// Send message
sendBtn.onclick = () => {
    const msg = messageInput.value.trim();
    if (msg && dataChannel && dataChannel.readyState === 'open') {
        dataChannel.send(msg);
        addMessage('You: ' + msg, 'sent');
        messageInput.value = '';
    }
};

// Send on Enter key
messageInput.onkeypress = (e) => {
    if (e.key === 'Enter') {
        sendBtn.onclick();
    }
};

// UI helpers
function addMessage(text, className) {
    const div = document.createElement('div');
    div.className = 'msg ' + className;
    div.textContent = text;
    messagesDiv.appendChild(div);
    messagesDiv.scrollTop = messagesDiv.scrollHeight;
}

function updateStatus(text) {
    statusDiv.textContent = 'Status: ' + text;
}

// Disable send initially
sendBtn.disabled = true;