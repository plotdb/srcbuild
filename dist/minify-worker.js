// plain js on purpose: `worker_threads` needs a real file path, and this has to resolve
// identically from `src/` ( tests, which load .ls through the livescript hook ) and from
// `dist/` ( published ). `build` copies it across the way it copies lib.pug.
//
// it does nothing but call the same `minify` the main thread would have called. all the
// policy - what counts as failure, what to fall back to - stays in minify.ls, so the
// worker path and the in-process path cannot drift apart.
const {parentPort} = require('worker_threads');
require('livescript');
const minify = require('./minify');

parentPort.on('message', function (job) {
  let ret;
  try {
    ret = minify(job.type, job.code, job.opt || {});
  } catch (e) {
    // minify() is not supposed to throw. if it ever does, say so rather than hanging
    // the caller's promise.
    ret = {code: job.code, failed: true, error: {message: e.message}};
  }
  parentPort.postMessage({
    id: job.id,
    code: ret.code,
    failed: !!ret.failed,
    // an Error does not survive structured clone with its message intact in every node
    // version. send what the log line needs.
    error: ret.error ? {message: String(ret.error.message || ret.error)} : null,
  });
});
