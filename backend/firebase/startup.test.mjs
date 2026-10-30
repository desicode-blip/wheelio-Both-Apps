import test from 'node:test';
import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';

test('availability starts without loading PDF or ZIP codecs, which remain usable on demand',async()=>{
  // Isolate the module cache: other tests intentionally generate real documents.
  const script=`
    import {createRequire} from 'node:module';
    const require=createRequire(import.meta.url);
    const api=await import('./functions/src/index.mjs');
    const codecs=()=>Object.keys(require.cache).filter(p=>/[\\\\/]node_modules[\\\\/](pdf-lib|yazl)[\\\\/]/.test(p));
    const initial=codecs();
    const {receiptPdf}=await import('./functions/src/documents.mjs');
    const receipt=await receiptPdf({ref:'STARTUP-CHECK',paymentMode:'test'});
    const {ZipFile}=await import('./functions/node_modules/yazl/index.js');
    const zip=new ZipFile(),chunks=[];
    zip.outputStream.on('data',chunk=>chunks.push(chunk));
    const finished=new Promise((resolve,reject)=>{zip.outputStream.once('end',resolve);zip.outputStream.once('error',reject);zip.once('error',reject);});
    zip.addBuffer(receipt,'receipt.pdf');zip.end();await finished;
    console.log(JSON.stringify({availability:typeof api.getAvailability,download:typeof api.downloadBookingDocument,initial,pdf:receipt.subarray(0,5).toString(),zip:Buffer.concat(chunks).subarray(0,2).toString(),loaded:codecs().length}));
    process.exit(0);
  `;
  const {stdout}=await promisify(execFile)(process.execPath,['--input-type=module','-e',script],{
    cwd:new URL('.',import.meta.url),env:{...process.env,GCLOUD_PROJECT:'demo-wheelio'},timeout:30000,
  });
  const result=JSON.parse(stdout.trim());
  assert.equal(result.availability,'function');
  assert.equal(result.download,'function');
  assert.deepEqual(result.initial,[],'Slot requests must not pay document codec initialization cost.');
  assert.equal(result.pdf,'%PDF-');
  assert.equal(result.zip,'PK');
  assert.ok(result.loaded>0);
});
