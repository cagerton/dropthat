"use strict";
(function _main(){
	sjcl.random.startCollectors();

	var b64 = sjcl.codec.base64url,
		sha2 = sjcl.hash.sha256,
		room = getRoom(),
		channel = channelForRoom(room),
		urls = urlsForChannel(channel),
		chatbox = document.querySelector('.chatbox'),
		msgEl = document.querySelector('.chatbox ul'),
		btnEl = document.querySelector('button.submit-text'),
		input = document.querySelector('input[name="textinput"]'),
		prefix = document.querySelector('input[name="prefixinput"]'),
		countEl = document.querySelector('.users'),
		statusEl = document.querySelector('.status');


	document.addEventListener('input.img.datauri', function _handle_uri_img(e){
		var imgUrl = e.detail,
	        encrypted = sjcl.encrypt(room, imgUrl),
	        formData = new FormData();
		formData.append('encrypted-file', encrypted);
	    sendForm(formData);
	});

	input.addEventListener('keydown', function(e){
		if(e.keyCode == 13){

			sendMsg(readTextInput());
			input.value="";
		}
	});

	btnEl.addEventListener('click', function(){
		sendMsg(readTextInput());
		input.value="";
	});

	var events = new EventSource(urls.sub);
	events.onopen = function(e){ statusEl.classList.add('online'); console.log("online"); };
	events.onerror = function(e){ statusEl.classList.remove('online'); console.log("online"); };
	events.addEventListener('count',function(c){
		console.log("updated count:", c.data);
		countEl.textContent = c.data.split('=')[1];
	});
	events.addEventListener('image',function(c){
		log("Got image data. Loc:" + c.data);
		showImage(c.data);
	});

	events.onmessage = function(e){
		var encoded = e.data,
			msg;
		try{
			msg = sjcl.decrypt(room,JSON.parse(e.data));
			log(msg);
		}catch(err){
			console.log("Fail:",e.data)
			log("Failed to decode data.");
		}
	};

	function showImage(url){
		var el = document.createElement('li'),
			im = document.createElement('img');
	    var xhr = new XMLHttpRequest();
	    xhr.open('GET', url, true);
	    xhr.onreadystatechange = function(){
	    	console.log("readystatechange.");
	    	if(xhr.readyState == 4 && xhr.status==200){
	    		var dataURI = sjcl.decrypt(room, xhr.responseText),
	    		    mime = dataUrlMimeType(dataURI);
	    		if(mime=='image/jpeg'){
	    			im.src=dataURI;

	    			el.appendChild(im);
					msgEl.appendChild(el);
					msgEl.scrollTop = msgEl.scrollHeight;
	    		}else{
	    			console.log('wat: data-uri mime:',mime);
	    		}
	    		console.log("xhr!");
	    	}else if(xhr.state == 4){
	    		el.textContent("ERROR DOWNLOADING IMAGE.")
	    	}
	    }
	    xhr.send();
	    window.xhr=xhr;

	}

	function log(msg){
		var el = document.createElement('li');
		el.textContent = msg;
		msgEl.appendChild(el);
		msgEl.scrollTop = msgEl.scrollHeight;
	}

	function getRoom(){
		var room = document.location.hash;
		if(room.length != 23){
			room = newRoom();
			window.history.pushState({},'',room);
		}
		return room;
	}

	function newRoom(){
		return '#'+b64.fromBits(sjcl.random.randomWords(4));
	}

	function channelForRoom(key){
		return b64.fromBits(sha2.hash(key.toString()).slice(4));
	}

	function urlsForChannel(channel){
		var eventKey = channel.slice(1);
		return {
			'sub': '/sub/'+eventKey,
			'pub': '/pub/'+eventKey,
			'upload': '/upload/'+eventKey
		};
	}

	function readTextInput(){
		var nick = prefix.value;
		if(nick.length){
		    return nick + ': ' + input.value;
		}
		return input.value;
	}

	function sendMsg(plaintext){
	    var xhr = new XMLHttpRequest();
	    xhr.open("POST", urls.pub, true);
	    xhr.onreadystatechange = function(){
	        if(xhr.readyState == 4){
	            //f.dispatchEvent(new CustomEvent('sendform.done', {'detail':xhr}));
	        }
	    };
	    xhr.send(sjcl.encrypt(room,plaintext));
	}

	function sendForm(f){
	    var xhr = new XMLHttpRequest();
	    xhr.open('POST', urls.upload, true);
	    xhr.send(f);
	}

	function dataUrlMimeType(imageUrl){
		if(imageUrl.slice(0,5)!='data:'){
			throw new Error("wat; bad datauri?");
		}
		return imageUrl.slice(5,imageUrl.indexOf(';'));
	}

})();


(function _qr_code(){
	var qrEl = document.querySelector('.qr');
	var qrcode = new QRCode(qrEl, {	
						width:  128,
						height: 128,
						text: location.toString(),
						correctLevel: QRCode.CorrectLevel.L
					});
})();

(function _image_handlers(){

	var canvas = document.createElement('canvas'),
		ctx = canvas.getContext("2d");

	var dropZone = document.querySelector('.drop-target'),
		imgIn = document.querySelector('input[name="fileinput"]'),
		imgBtn = document.querySelector('button.submit-image');

	imgIn.addEventListener("change", handleImageInput);
	imgBtn.addEventListener("click", function (e) {
	    imgIn.click();
	    e.preventDefault();
	}, false);

	dropZone.addEventListener('dragenter', handleDragEnter);
	dropZone.addEventListener('dragleave', handleDragLeave);
	dropZone.addEventListener('dragend', handleDragStop);
	dropZone.addEventListener('drop', handleDragStop);
	dropZone.addEventListener('dragover', handleDragOver);
	dropZone.addEventListener('drop', handleImageInput);
	document.addEventListener('dragover', preventNav);
	document.addEventListener('drop', preventNav);


	function dataUrlToArrayBuffer(imageUrl){
	    var mimetype = imageUrl.slice(imageUrl.indexOf(':')+1,imageUrl.indexOf(';')),
	        raw = atob(imageUrl.slice(imageUrl.indexOf(',')+1)),
	        bytes = new Uint8Array(Array(raw.length)),
	        idx;
	    for(idx=0;idx<raw.length;++idx){
	        bytes[idx]=raw.charCodeAt(idx);
	    }
	    return new Blob([bytes.buffer],{type:mimetype});
	}

	// image crap.
	function handleImageInput(e) {
	    var reader = new FileReader(),
	    	file;

	    reader.onload = function (event) {
	        var img = new Image();
	        img.src = reader.result;
	        img.onload = function () {

	        	/*var pxScale = 1;
	        	if ('devicePixelRatio' in window && window.devicePixelRatio > 1){
	        		pxScale = 1/window.devicePixelRatio;
	        		console.log('pixel ratio:', window.devicePixelRatio);
	        	}*/

	        	var maxdim = 480,
	        	    scale = Math.min(1, maxdim / Math.max(img.width, img.height)),
	        	    canWidth  = (img.width * scale )|0,
	        	    canHeight = (img.height * scale )|0;

	        	canvas.width = canWidth,
	        	canvas.height = canHeight;
	            ctx.drawImage(this, 0, 0, canWidth, canHeight);

	            var imageUrl = canvas.toDataURL("image/jpeg",0.95),
					duriEvent = new CustomEvent('input.img.datauri', {'detail': imageUrl});
				document.dispatchEvent(duriEvent);
	        }
	    }

	    if(e.target && e.target.files){
	    	file = e.target.files[0];
	    }else if(e.dataTransfer && e.dataTransfer.files){
	    	file = e.dataTransfer.files[0];
	    }else{
	    	console.log("Error?, event didn't have any files? ",e);
	    }
	    if (!file.type.match('image/*')){
	    	console.log("ERR: wat? type: ",f.type);
	    }else{
		    reader.readAsDataURL(file);
	    }
	}

	function handleDragOver(e) {
		dropZone.classList.add('over');
		e.stopPropagation();
		e.preventDefault();
		e.dataTransfer.dropEffect = 'copy'; // Explicitly show this is a copy.
	}

	function handleDragEnter(e){
		dropZone.classList.add('over');
		e.stopPropagation();
		e.preventDefault();
	}

	function isParent(pEl, cEl){
		while(cEl.parentNode){
			if(pEl == cEl.parentNode) return true;
			cEl = cEl.parentNode;
		}
		return false;
	}

	function handleDragLeave(e){
		if(e.toElement==null|| e.fromElement ==null || (!isParent(dropZone, e.toElement))){
			dropZone.classList.remove('over');
			e.stopPropagation();
			e.preventDefault();
		}
	}

	function handleDragStop(e){
		dropZone.classList.remove('over');
		e.stopPropagation();
		e.preventDefault();
	}

	function preventNav(e){
		e.preventDefault();
		e.stopPropagation();
	}
})();
