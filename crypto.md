On Javascript Cryptography
==========================
JS Crypto isn't [doomed](http://www.matasano.com/articles/javascript-cryptography/), it just solves different problems.

### Preface

[DropTh.at](https://dropth.at/) uses JS crypto in addition to SSL to encrypt your messages.  The key for a chat room is randomly generated and stored in the #fragment-identifier.  You can share access to the room simply by sharing the URL.  The client coordinates with the server using a channel id which is derived from the room key using a sha2 hash. The key itself should never touch the dropthat server.  

There is lots of room for improvement in the DropTh.at demo.  For example, clients could use public key cryptography and key exchange algorithms so that the encryption keys for your data aren't shared along with the URL #fragment-idenitfier.  Remember that none of this is secure unless you can safely deliver the javascript and html to the users (over SSL) in the first place.

### Client Crypto is an implicit contract:

If clients encrypt files/messages/images/etc before sending to a web service, it lays out a contract of trust between customers and the hosting service.  
* We won't read your stuff.
* We won't target ads based on your content.
* We won't [de-duplicate](http://paranoia.dubfire.net/2011/04/how-dropbox-sacrifices-user-privacy-for.html) your data.
* You won't delete your private media because of a bogus DMCA takedown on another user with the same files.
* Our backups will never contain your plaintext.
* Our cross-data-center links will never expose your unencrypted data.
* We won't report your private data [to the police](http://sacramento.cbslocal.com/2013/11/21/googles-role-in-woodland-child-pornography-arrest-raises-privacy-concerns/)(Okay this time, but how about leaked NSA docs?)

### As a legal protection for the host from the client data:

Lets take [Mega](https://mega.co.nz/) as an example (I haven't verified this completely): they use client encryption and never see media files that are uploaded to them.  Since they're insulated from the data, it'll be hard to argue that they are complicity in copyright violations.

### Untrusted Public CDNs:

We like Public CDNs (bootstrapcdn, cdnjs, googlecdn, etc), but we shouldn't have to trust them.  I'm sure they've all got great security, but an attack on a big public cdn could have wide reaching implications.  You can use Javascript to verify assets (both shared and private) before using/running them. Proof of concept: https://dropth.at/cors-cdn-demo

### Password Hashing:

You all use BCrypt/SCrypt/PBKDF2, right?  These take up lots of CPU time by design and can be targeted for a DoS attack on your server.  Rate limiting can help, but it's not a silver bullet - especially if you're chewing through 100ms+ of cpu time for each attempt.  They also make RasPi servers cry.  With the careful application of client-side js crypto, you can offload some of the expensive work from your server to the client during heavy load (or all the time).  I'd reccomend wrapping the result again with a SHA and random salt on the server. [Previously](https://gist.github.com/cagerton/5485241#file-1crazy-md)

PBKDF2 Sha256 with 25000 iterations:
```javascript
var b64 = sjcl.codec.base64, sha2 = sjcl.hash.sha256, kdf = sjcl.misc.pbkdf2;
function preHash(site, username, password){
	var salt = b64.fromBits(sha2.hash(site + username)).slice(0,10);
	return = b64.fromBits(kdf(password, salt, 25000));
}
var username='cda', password='password', start = Date.now(),
	output = preHash('dropth.at', username, password);
console.log("Hashing took approx ",Date.now()-start, "ms");
```
> Chrome: 168ms, Firefox: 150ms, Safari: 1260ms, Chrome on my Galaxy Nexus: 1343ms, Android browser: 1628ms.

> django.utils.crypto.pbkdf2: 105ms on my laptop.

### Conclusion

Client JS crypto has lots of [problems](http://www.matasano.com/articles/javascript-cryptography/) and can't work without the support of SSL. On the other hand, it can be used to supplement places that traditional crypography tools can't reach (like CDNs). 

