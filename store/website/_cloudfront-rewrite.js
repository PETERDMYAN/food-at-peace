// CloudFront Function (viewer-request, runtime cloudfront-js-2.0) for the
// foodatpeace.app distribution (E2M22G0LAT1HKW).
//
// S3-origin CloudFront doesn't resolve directory URLs to index.html, so
// `/dashboard/` 404s while `/dashboard` works. This appends `index.html` to any
// URI ending in `/` (so `/dashboard/` -> `/dashboard/index.html`, `/` ->
// `/index.html`). It deliberately does NOT touch extensionless paths like
// `/i/<handle>` — those keep falling through to the 404.html smart-router that
// powers invite links, so the live invite flow is unchanged.
//
// Deploy: aws cloudfront create-function / test-function / publish-function,
// then associate as the default behavior's viewer-request function.
function handler(event) {
  var request = event.request;
  if (request.uri.endsWith('/')) {
    request.uri += 'index.html';
  }
  return request;
}
