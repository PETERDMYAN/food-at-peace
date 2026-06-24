// CloudFront Function (viewer-request, cloudfront-js-2.0) for foodatpeace.app
// (E2M22G0LAT1HKW).
//
// 1) S3-origin CloudFront doesn't resolve directory URLs, so append index.html
//    to any URI ending in "/" (e.g. /dashboard/ -> /dashboard/index.html).
// 2) Shareable recharge deep-link: /recharge/<handle> serves the recharge page
//    (the page JS reads the handle from the path). A single bare segment only —
//    never /recharge itself, the index file, deeper paths, or asset files.
// Both deliberately leave extensionless paths like /i/<handle> (invite links)
// alone, so the 404.html smart-router still powers them.
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
    return request;
  }
  if (uri.startsWith('/recharge/') && uri !== '/recharge/index.html') {
    var rest = uri.substring(10); // after "/recharge/"
    if (rest.length > 0 && rest.indexOf('/') === -1 && rest.indexOf('.') === -1) {
      request.uri = '/recharge/index.html';
    }
  }
  return request;
}
