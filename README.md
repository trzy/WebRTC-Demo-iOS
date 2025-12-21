# WebRTC iOS Demo

# HTML5 Chat Client

Start the Python signaling server:

```
python -m server
```

Then navigate (in two separate tabs) to [http://localhost:8000](http://localhost:8000). 

How it works:

- Will only work with the first two connections, a third connection or more will never receive the required offer.
- First peer to connect is assigned the `initiator` role by the server.
- The second peer is assigned the `responder` role. A message is also then sent to the `initiator` indicating that a peer has connected.
- This kicks off the WebRTC connection flow. The `initiator` creates an offer once it knows that another peer is waiting.