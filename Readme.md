https://Dropth.at
================================

Or how js-crypto can be an important part of this complete breakfast.

TODO: fill in the details:

###First, the server.
* Server Sent Events using Nginx and Lua. It's pretty neat. No, really.
* This is a standard html5 replacement for Comet / long polling.
* Sends a stream of type text/event-stream with chunked content-transfer.
* The server is basically a pub-sub engine. Clients subscribe to a channel.
* Simple, non-chatty protocol => supports scads of concurrent clients.
* Messages aren't stored. Photos are, but they're resized & encrypted client side.

###Front end
* The front end lets SJCL handle all of the the crypto.
* On a keyless page-load, it stores a random symmetric key in the #document-fragment.
* Document-fragment is not passed in http requests.
* You can share the key/room by sharing the url.
* Pub/sub channel derived as a sha256 hash of the random encryption key.
* There's lots of room to expand on this.

###Why is this interesting:
* The host (me) is somewhat protected from the user data (think copyright, sharks, etc).
* The host can't casually/passively snoop. Takes active script injection to steal the key.
* Hosted data is encrypted & I don't have keys => Passive attacks on my server are less interesting.
* If I let 3rd parties use this as an API, they can host their own JS. Then my server can't even inject key-stealing js.

###Other things you could do with JS crypto:
* You can offload expensive password hashing functions like bcrypt/scrypt to the client. You need to hash it once more on the server and might want to use a salt based on a hash(username, sitename). Here's an old gist with Emscripten+scrypt: https://gist.github.com/cagerton/5485241#file-1crazy-md [todo: redo with pbkdf2 & bcrypt]
* Client JS can be used (with CORS) to build a public CDN that checks assets before use. Here's a demo: https://dropth.at/cors-cdn-demo
* Use public key crypto & key exchange.
* Peer to peer / webrtc...

###Things to fix:
* iPhone canvas problem? Meh. Don't have one to test with; works on iPad.
* Needs responsive layout. Sucks on a small screen.
* Add disclaimer about old and/or shitty browsers.
* Some misc fixups. Maybe CSRF (less important since rooms are secret) + asset domains?

###Some ways you'll get boned:
* Someone will try to run this without https and you'll get boned.
* Someone will intercept the key when you send the room link...
* You'll share the link#key with the wrong person...
* Someone will dig through your history and get your key...
* Someone will pwn my server or find an xss hold and inject js to steal the key....
* Someone will get a "trusted" CA to issue a cert then mitm you. Then you'll get boned.
* http://xkcd.com/538/ (Could be me + a court order to inject js to steal keys).

###And then:
* Hey Matasano, client JS Crypto isn't doomed; it's just useful against a different class of attacks.
* re: https^H://www.matasano.com/articles/javascript-cryptography/
