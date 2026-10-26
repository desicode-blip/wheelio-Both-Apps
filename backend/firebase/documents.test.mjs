import {test} from 'node:test';
import assert from 'node:assert/strict';
import pdfLib from './functions/node_modules/pdf-lib/cjs/index.js';
const {PDFDocument}=pdfLib;
import {receiptPdf,evidenceFiles} from './functions/src/documents.mjs';
test('receipts are real PDF files derived from the verified stored amounts',async()=>{
 const bytes=await receiptPdf({ref:'WH-TEST',plate:'TS09AB1234',day:'2026-11-01',startHour:8,endHour:10,paymentStatus:'captured',pricePaise:14900,paymentMode:'test'});
 assert.equal(bytes.subarray(0,4).toString(),'%PDF');assert.equal((await PDFDocument.load(bytes)).getPageCount(),1);
});
test('evidence packs can include only original files from the requested booking',()=>{
 assert.equal(evidenceFiles('job',{customerPhotos:{front:'orders/job/customer/front.jpg'}}).length,1);
 assert.throws(()=>evidenceFiles('job',{customerPhotos:{front:'kyc/private/selfie.jpg'}}));
 assert.throws(()=>evidenceFiles('job',{customerPhotos:{front:'orders/job/../another/front.jpg'}}));
});
