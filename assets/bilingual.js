/* Pairing is presentation metadata stored in existing JSON blocks; no SQL migration. */
'use strict';
window.P127_BILINGUAL = (() => {
  function keyed(zh=[],en=[]) {
    const legacy=zh.length===en.length && zh.every((b,i)=>b.type===en[i].type) && [...zh,...en].every(b=>!b.pairKey);
    const map=(blocks,language)=>blocks.map((b,i)=>({...b,pairKey:String(b.pairKey|| (legacy?`legacy-${i+1}`:`${language}-${i+1}`))}));
    return {zh:map(zh,'zh'),en:map(en,'en')};
  }
  function pairs(zh=[],en=[]) {
    const k=keyed(zh,en), used=new Set(), rows=[];
    for(const z of k.zh){const i=k.en.findIndex((e,j)=>!used.has(j)&&e.pairKey===z.pairKey&&e.type===z.type);if(i>=0)used.add(i);rows.push({zh:z,en:i>=0?k.en[i]:null});}
    k.en.forEach((e,i)=>{if(!used.has(i))rows.push({zh:null,en:e});});
    return rows;
  }
  return {keyed,pairs};
})();
