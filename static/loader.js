"use strict";
/*
 *  Include this (preferably compressed with SJCL) in the top of the head of your doc.  
 *  It will load and verify any subsequent elements with sha & (src|href) data attributes.
 *  The sha attribute needs to be the base64 encoded sha256 sum of whatever file you're loading.
 * 
 *  Beware: I do not currently enforce load order.
 *
 *  Example: <script data-type="text/javascript"
 *                   data-src="//cdnjs.cloudflare.com/ajax/libs/jquery/2.0.3/jquery.min.js"
 *                   data-sha="pXtSQrmprcTB74RsNlFHuJxHK5zXcPrOMx78uWU0ayU="></script>
 */
(function(){
    function xhrLoader(el){
        var xhr = new XMLHttpRequest(),
            b64 = sjcl.codec.base64,
            sha = sjcl.hash.sha256,
            bytes = sjcl.codec.bytes,
            str = sjcl.codec.utf8String;

        xhr.open('GET', el.dataset.src || el.dataset.href, true);
        xhr.responseType = 'arraybuffer';
        xhr.onreadystatechange = function _handle_ready(){
            if(xhr.readyState == 4 && xhr.status == 200){ // todo: handle non-200s.
                var b = sjcl.codec.bytes.toBits(new Uint8Array(xhr.response)),
                    b_hsh = b64.fromBits(sha.hash(b));
                if(b_hsh == el.dataset.sha){
                    var blob = new Blob([xhr.response], {type : el.dataset.type}),
                        url = URL.createObjectURL(blob),
                        template_url;
                    if(el.dataset.src){
                        el.src = url;
                    }else{
                        if(el.dataset.template){
                            // the template attr lets you load fonts.
                            var target = el.dataset.template.replace(/blob:/, url),
                                array = new Uint8Array(bytes.fromBits(str.toBits(target))),
                                blob = new Blob([array.buffer], {type:'text/css'});
                            template_url = URL.createObjectURL(blob);
                            el.href = template_url;
                        }else{
                            el.href = url;
                        }
                    }
                    el.onload = function(){
                        window.setTimeout(function(){
                            URL.revokeObjectURL(url);
                            if (template_url)  URL.revokeObjectURL(template_url);
                        },300);
                        console.log(performance.now())
                    }
                }else{
                    throw new Error("Bad sha: "+b_hsh+" != "+el.dataset.sha);
                }
            }
        }
        xhr.send();
    }
    var observer = new MutationObserver(function(mutations){
        mutations.forEach(function(mutation){
            for (var i = 0; i < mutation.addedNodes.length; i++){
                var node = mutation.addedNodes[i];
                if(node.dataset && node.dataset.sha){
                    xhrLoader(node);
                }else{
                    if(node.querySelectorAll){
                        var others = node.querySelectorAll('[data-sha]');
                        [].slice.apply(others).forEach(xhrLoader);
                    }
                }
            }
        });
    });
    observer.observe(document,{childList:true, subtree:true });
})();
