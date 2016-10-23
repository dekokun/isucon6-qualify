#
# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and https://www.varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

import directors;

# Default backend definition. Set this to point to your content server.
backend localhost {
    .host = "127.0.0.1";
    .port = "5000";
}

sub vcl_init {
    new backend = directors.round_robin();

    backend.add_backend(localhost);
}

sub vcl_recv {
  set req.backend_hint = backend.backend();

  if (req.method == "INVALIDATE") {
     # ban("obj.http.Hoge ~ ^.*" + req.http.X-Invalidated-Hoge + ".*$");
     ban("obj.response ~ ^.*" + req.http.X-Invalidated-Hoge + ".*$");
    return(synth(200, req.http.X-Invalidated-Hoge + " Purged. Success !!"));
  }


  # if (req.http.Cookie) {
  #     return(pass);
  # }

  if (req.method != "GET" && req.method != "HEAD") {
      return(pass);
  }

  return(hash);
}

sub vcl_hash {
  hash_data(req.url);
  if (req.http.host) {
    hash_data(req.http.host);
  } else {
    hash_data(server.ip);
  }
  return (lookup);
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    return(deliver);
}

sub vcl_backend_response {

  # this is same as builtin vcl_backend_response
  # https://www.varnish-cache.org/trac/browser/bin/varnishd/builtin.vcl?rev=ae548683b8f91d0a92799f6c746b80773a4c9f05
  if (beresp.ttl <= 0s ||
    beresp.http.Set-Cookie ||
    beresp.http.Surrogate-control ~ "no-store" ||
    beresp.http.Cache-Control ~ "no-cache" ||
    (!beresp.http.Surrogate-Control &&
      beresp.http.Cache-Control ~ "no-cache|no-store|private") ||
    beresp.http.Vary == "*") {
      /*
      * Mark as "Hit-For-Pass" for the next 2 minutes
      */
      set beresp.uncacheable = true;
  }

  # this is hatena original config
  if (beresp.ttl > 0s && ! beresp.uncacheable) {
      set beresp.grace = 1m;
  }
  return (deliver);
}

sub vcl_synth {
    set resp.http.Content-Type = "text/html; charset=utf-8";
    set resp.http.Retry-After = "5";
    synthetic( {"<!DOCTYPE html>
<html>
  <head>
    <title>"} + resp.status + " " + resp.reason + {"</title>
  </head>
  <body>
    <h1>"} + resp.status + " " + resp.reason + {"</h1>
    <p>"} + resp.reason + {"</p>
    <p>XID: "} + req.xid + {"</p>
  </body>
</html>
"} );
    return (deliver);
}

