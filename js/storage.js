/* Browser-local JSON store. Never seeds operational/demo records. */
(function(){
  'use strict';
  const PREFIX='madrasah_';
  const initialClasses=['তাকমীল ফিল হাদিস','ফযিলত ২য় বর্ষ','ফযিলত ১ম বর্ষ','সানোবিয়্যাহ উলয়া ২য় বর্ষ','সানোবিয়্যাহ উলয়া ১ম বর্ষ','সানোবিয়্যাহ আম্মাহ ২য় বর্ষ','সানোবিয়্যাহ আম্মাহ ১ম বর্ষ','মুতাওয়াসসিতাহ ৩য় বর্ষ','মুতাওয়াসসিতাহ ২য় বর্ষ','ইবতিদায়ী ৫ম বর্ষ'];
  const tables=['academic_years','classes','students','teachers','staff','subjects','attendance','teacher_attendance','staff_attendance','exams','marks','fees','homework','notices','books','library_transactions','expenses','income','accounts'];
  const empty=Object.fromEntries(tables.map(x=>[x,[]])); empty.settings={}; empty.marks=[];
  function read(key,fallback){try{const raw=localStorage.getItem(PREFIX+key);if(raw===null)return fallback;const value=JSON.parse(raw);return value===null?fallback:value;}catch(e){console.warn('Storage read recovered:',key,e);return fallback;}}
  function write(key,value){try{localStorage.setItem(PREFIX+key,JSON.stringify(value));return true;}catch(e){throw new Error('ব্রাউজারের জায়গা পূর্ণ বা সংরক্ষণ অনুমোদিত নয়। ব্যাকআপ নিয়ে কিছু ছবি সরিয়ে আবার চেষ্টা করুন।');}}
  function initialize(){for(const key of tables){const current=read(key,null);if(!Array.isArray(current)){write(key,key==='classes'?initialClasses.map((name,i)=>({id:'class-'+(i+1),name,predefined:true})):[]);}}if(!read('settings',null)||Array.isArray(read('settings',null)))write('settings',{});}
  function getData(key){if(key===undefined)return Object.fromEntries(['settings',...tables].map(k=>[k,read(k,k==='settings'?{}:[])]));return read(key, key==='settings'?{}:[]);}
  function setData(key,value){write(key,value);return value;}
  function generateId(prefix){return (prefix||'rec')+'-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2,9);}
  function findById(key,id){return getData(key).find(row=>row&&String(row.id)===String(id))||null;}
  function addData(key,record){const rows=getData(key);if(!Array.isArray(rows))throw new Error('এই তথ্যের তালিকা পাওয়া যায়নি।');const item={...record,id:record.id||generateId(key)};rows.push(item);setData(key,rows);return item;}
  function updateData(key,id,changes){const rows=getData(key),index=rows.findIndex(x=>String(x.id)===String(id));if(index<0)throw new Error('তথ্যটি আর পাওয়া যাচ্ছে না।');rows[index]={...rows[index],...changes,id:rows[index].id};setData(key,rows);return rows[index];}
  function deleteData(key,id){const rows=getData(key),next=rows.filter(x=>String(x.id)!==String(id));setData(key,next);return next.length!==rows.length;}
  function resetUserData(){for(const key of tables)if(key!=='classes')setData(key,[]);setData('classes',initialClasses.map((name,i)=>({id:'class-'+(i+1),name,predefined:true})));}
  window.Store={tables,initialClasses,getData,setData,addData,updateData,deleteData,findById,generateId,resetUserData};initialize();
})();
