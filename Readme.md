Dropth.at
================================

Or how js-crypto can be an important part of this complete breakfast.

(When used in conjunction with https and other security measures)

TODO: fill in the details:

###This [demo] service:
* Encryption key is stored in #document-fragment and not sent to server.
* Granting access to a protected chat room is as easy as sharing the url.
* The host (me) is somewhat protected from the user data (think sharks, copyright, etc).
* The host can't be tempted to passively snoop. (Takes active script injection!)
* If this was used as an API, consumers could host their own JS.

###Other things you could do with JS crypto:
* You can offload expensive password hashing functions like bcrypt/scrypt to the client. (Salt with hash(username,site), hash again before storing). [link to gist? or rewrite?]
* This could be used (with CORS) to build a public CDN that checks assets before use.
* Peer to peer / webrtc...

###Cool server shit:
* Server sent events using Nginx and Lua. It's pretty neat.

###Things to fix:
* iPhone canvas problem? Meh. Don't have one to test with. Works on iPad.
* Needs responsive layout. Sucks on a small screen.
* Add disclaimer about old and/or shitty browsers.
* Some misc fixups. Maybe CSRF (less important since rooms are secret) & CSP + asset domains?
* Add fonts.

###Some ways you'll get boned:
* Someone will try to run this without https and you'll get boned.
* Someone will intercept the key when you send the room link...
* You'll share the link#key with the wrong person...
* Someone will dig through your history and get your key...
* Someone will pwn my server or find an xss hold and inject js to steal the key....
* Someone will get a "trusted" CA to issue a cert then mitm you. Then you'll get boned.
* http://xkcd.com/538/ (Though, the wrench would be faster/more effective if I had keys)

###And then:
* Hey Matasano, client JS Crypto isn't doomed; it's just useful against a different class of attacks.
* re: https^H://www.matasano.com/articles/javascript-cryptography/

###Don't trust my minized version of SJCL, build your own:
* https://github.com/bitwiseshiftleft/sjcl.git

