#!/usr/bin/env python3.3
# sudo apt-get instal libpcre3-dev libaio-dev zlib1g-dev
# sudo apt-get install imagemagick libmagickcore4 libmagickwand-dev libmagickwand4
# curl -o magick.lua https://raw.github.com/leafo/magick/e58a0b3becfac35bfbbff5fca71af119fbdd1474/magick/init.lua

try:
    from urllib.parse import urlparse
except:
    from urlparse import urlparse
import subprocess
import os

PREFIX = '/opt/openresty'
OPENSSL_DIR = os.path.join(os.getcwd(), 'openssl-1.0.1e')
OPENRESTY_DIR = os.path.join(os.getcwd(), 'ngx_openresty-1.4.3.3')
PCRE_DIR = os.path.join(os.getcwd(), 'pcre-8.33')
FILES = (
  ('http://openresty.org/download/ngx_openresty-1.4.3.3.tar.gz', '58438f999ec5f2f484b2ac43a29950a512fab361'),
  ('http://www.openssl.org/source/openssl-1.0.1e.tar.gz', '3f1b1223c9e8189bfe4e186d86449775bd903460'),
  ('ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.33.tar.gz', 'bceafb53553219dad2593bb8af06da4d07fd3828'),
  # ('http://nginx.org/download/nginx-1.4.4.tar.gz', '304d5991ccde398af2002c0da980ae240cea9356'),
)

# download files.
for url,sha in FILES:
    filename = (os.path.split(urlparse(url).path)[-1])
    if not os.path.exists(filename):
        subprocess.check_call(['curl', '-o', filename, url])
    filesha = subprocess.check_output(['sha1sum', filename]).strip()[:40].decode()
    if filesha != sha:
        raise Exception("integrity check failed")
    subprocess.check_call(['tar','-xzf', filename])

os.chdir(OPENRESTY_DIR)
subprocess.check_call((
    './configure',
    '--prefix=%s' % PREFIX,
    '--with-luajit',
    '--user=nginx',
    '--group=nginx',
    '--with-http_ssl_module',
    '--with-openssl-opt=enable-ec_nistp_64_gcc_128',
    '--with-openssl=%s' % OPENSSL_DIR,
    '--with-pcre=%s' % PCRE_DIR,
    '--with-http_spdy_module',
    '--with-http_gzip_static_module',
    '--with-http_stub_status_module',
    '--with-libatomic',
    #'--with-file-aio',
    ))

subprocess.check_call(['make',]) # openssl doesn't like to make -jN?
subprocess.check_call(['make','install']) 