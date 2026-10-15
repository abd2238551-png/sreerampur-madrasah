/* Record-level two-way sync. Each account owns its rows; conflicting edits are never auto-overwritten. */
(function(){
  'use strict';
  const {tables,Query,Permission,Role}=window.MadrasahAppwrite;
  const {databaseId,tableId}=window.MadrasahAppwriteConfig;
  const known=()=>['settings',...Store.tables];
  const stable=value=>JSON.stringify(value,(_k,v)=>v&&typeof v==='object'&&!Array.isArray(v)?Object.fromEntries(Object.keys(v).sort().map(k=>[k,v[k]])):v);
  const snake=key=>key.replace(/[A-Z]/g,m=>'_'+m.toLowerCase());
  const camel=key=>key.replace(/_([a-z])/g,(_m,c)=>c.toUpperCase());
  const canonical=(collection,value)=>{
    if(collection==='settings'){
      const s=value||{};
      return {id:'_settings',school_name:s.school_name??s.name??'Sreerampur Madrasah',school_address:s.school_address??s.address??'',school_phone:s.school_phone??s.phone??'',school_email:s.school_email??s.email??'',head_name:s.head_name??s.headmaster??'',academic_year:s.academic_year??s.year??'',logo_data:s.logo_data??s.logo??'',currency:s.currency??'৳'};
    }
    const out={};
    for(const [key,val] of Object.entries(value||{})){
      const field=snake(key);
      if(['created_at','sort_order','predefined'].includes(field))continue;
      if(field==='active'&&Number(val)===1)continue;
      if(field==='photo'){out.photo_data=val;continue;}
      if(field==='photo_path'&&typeof val==='string'&&!val.startsWith('data:')){continue;}
      if(val===null||val===undefined||val==='')continue;
      out[field]=val;
    }
    return out;
  };
  const toLocal=(collection,value)=>{
    if(collection==='settings')return {...Store.getData('settings'),name:value.school_name||'',address:value.school_address||'',phone:value.school_phone||'',email:value.school_email||'',headmaster:value.head_name||'',year:value.academic_year||'',logo:value.logo_data||'',currency:value.currency||'৳',theme:value.theme||Store.getData('settings').theme||'light'};
    return Object.fromEntries(Object.entries(value||{}).map(([k,v])=>[k==='photo_data'?'photo':camel(k),v]));
  };
  const keyOf=(collection,id)=>`${collection}\u0000${id}`;
  const digest=async text=>{
    const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text));
    return [...new Uint8Array(bytes)].map(x=>x.toString(16).padStart(2,'0')).join('').slice(0,36);
  };
  const baselineKey=userId=>`madrasah_appwrite_baseline_${userId}`;
  function readBaseline(userId){try{return JSON.parse(localStorage.getItem(baselineKey(userId))||'{}')}catch{return {}}}
  async function localRecords(){
    const out=new Map();
    for(const collection of known()){
      const rows=collection==='settings'?[{id:'_settings',...Store.getData('settings')}]:Store.getData(collection);
      for(const item of rows||[]){
        const id=String(item?.id??'').trim();if(!id)continue;
        const value=canonical(collection,item);
        out.set(keyOf(collection,id),{collection,id,value,deleted:false});
      }
    }
    return out;
  }
  async function cloudRecords(userId){
    const out=new Map();let offset=0;
    for(;;){
      const page=await tables.listRows({databaseId,tableId,queries:[Query.equal('owner_id',[userId]),Query.limit(100),Query.offset(offset)]});
      for(const row of page.rows||[]){
        if(!known().includes(row.collection)||!row.record_id)continue;
        let value={};try{value=JSON.parse(row.payload||'{}')}catch{throw new Error('Cloud record-এর JSON পড়া যাচ্ছে না; কোনো data overwrite করা হয়নি।')}
        const item={collection:row.collection,id:String(row.record_id),value,deleted:!!row.is_deleted,rowId:row.$id};
        out.set(keyOf(item.collection,item.id),item);
      }
      if((page.rows||[]).length<100)break;offset+=page.rows.length;
    }
    return out;
  }
  const equal=(a,b)=>stable(a??null)===stable(b??null);
  async function prepare(userId){
    const [local,cloud]=await Promise.all([localRecords(),cloudRecords(userId)]),base=readBaseline(userId),keys=new Set([...local.keys(),...cloud.keys(),...Object.keys(base)]),plan=new Map(),conflicts=[];
    for(const key of keys){
      const L=local.get(key)||{deleted:true},R=cloud.get(key)||{deleted:true},B=base[key]||null;
      const localState=L.deleted?{deleted:true}:{deleted:false,value:L.value};
      const cloudState=R.deleted?{deleted:true}:{deleted:false,value:R.value};
      const baseState=B?{deleted:!!B.deleted,value:B.value}:null;
      const meta=L.collection?L:R.collection?R:(B?{collection:B.collection,id:B.id}:null);
      if(!meta)continue;
      if(!B){
        const localExists=!L.deleted,cloudExists=!R.deleted;
        if(localExists&&cloudExists&&!equal(localState,cloudState)){
          conflicts.push({key,collection:meta.collection,id:meta.id,local:localState,cloud:cloudState});
          plan.set(key,{choiceRequired:true,local:L,cloud:R,collection:meta.collection,id:meta.id});
        }else{
          const chosen=localExists?L:cloudExists?R:{...meta,deleted:true};
          plan.set(key,{...chosen,collection:meta.collection,id:meta.id});
        }
        continue;
      }
      const lc=!equal(localState,baseState),rc=!equal(cloudState,baseState);
      if(lc&&rc&&!equal(localState,cloudState)){
        conflicts.push({key,collection:meta.collection,id:meta.id,local:localState,cloud:cloudState});
        plan.set(key,{choiceRequired:true,local:L,cloud:R,collection:meta.collection,id:meta.id});
      }else{
        const chosen=lc?L:rc?R:(B?{...B}:L);
        plan.set(key,{...chosen,collection:meta.collection,id:meta.id});
      }
    }
    return {userId,local,cloud,base,plan,conflicts};
  }
  async function commit(prepared,choices){
    const {userId,local,cloud,plan}=prepared,final=new Map();
    for(const [key,item] of plan){
      if(item.choiceRequired){const choice=choices[key];if(!choice)throw new Error('সব conflict-এর সিদ্ধান্ত না নিয়ে sync করা যাবে না।');const picked=choice==='local'?item.local:item.cloud;final.set(key,{...picked,collection:item.collection,id:item.id,deleted:!!picked.deleted,value:picked.deleted?null:picked.value,rowId:picked.rowId||item.cloud?.rowId});}
      else final.set(key,item);
    }
    const baseline={};
    for(const [key,item] of final){
      if(!item?.collection)continue;
      const chosen=item.deleted?{deleted:true}:{deleted:false,value:item.value};
      baseline[key]={collection:item.collection,id:item.id,deleted:!!item.deleted,value:item.value??null};
      const current=cloud.get(key),localCurrent=local.get(key);
      if(!current||!equal(current.deleted?{deleted:true}:{deleted:false,value:current.value},chosen)){
        const rowId=current?.rowId||await digest(`${userId}\u0000${item.collection}\u0000${item.id}`);
        const data={owner_id:userId,collection:item.collection,record_id:item.id,payload:JSON.stringify(item.value??{}),updated_at:new Date().toISOString(),is_deleted:!!item.deleted};
        const permissions=[Permission.read(Role.user(userId)),Permission.update(Role.user(userId)),Permission.delete(Role.user(userId))];
        try{await tables.updateRow({databaseId,tableId,rowId,data});}
        catch(error){if(error.code!==404&&error.code!==409)throw error;try{await tables.createRow({databaseId,tableId,rowId,data,permissions})}catch(createError){if(createError.code!==409)throw createError;await tables.updateRow({databaseId,tableId,rowId,data});}}
      }
      if(!equal(localCurrent?.deleted?{deleted:true}:{deleted:false,value:localCurrent?.value},chosen)){
        if(item.collection==='settings')Store.setData('settings',toLocal('settings',item.value||{}));
        else{
          const rows=Store.getData(item.collection)||[],next=rows.filter(x=>String(x.id)!==String(item.id));
          if(!item.deleted)next.push(toLocal(item.collection,item.value));
          Store.setData(item.collection,next);
        }
      }
    }
    localStorage.setItem(baselineKey(userId),JSON.stringify(baseline));
    return {records:final.size,cloud:cloud.size,conflicts:prepared.conflicts.length};
  }
  async function sync(userId,askChoice){
    const prepared=await prepare(userId),choices={};
    for(const conflict of prepared.conflicts){
      const label=conflict.collection==='settings'?'মাদরাসার সেটিংস':conflict.collection+' / '+conflict.id;
      const answer=await askChoice(label,conflict);
      if(!answer)return {cancelled:true,conflicts:prepared.conflicts.length};
      choices[conflict.key]=answer;
    }
    return commit(prepared,choices);
  }
  window.MadrasahCloudSync={sync};
})();
