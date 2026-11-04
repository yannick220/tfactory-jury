const TF_URL='https://vglqemyzhmsmbjzkrgdh.supabase.co';
const TF_KEY='sb_publishable_QnJxLELcE9D9Y_Uct-C85w_3vFfWAm7';
const TF_HEADERS={apikey:TF_KEY,'Content-Type':'application/json'};
async function tfRequest(path,options={},token=null){
 const headers={...TF_HEADERS,...(token?{Authorization:'Bearer '+token}:{}),...(options.headers||{})};
 const response=await fetch(TF_URL+path,{...options,headers,cache:'no-store'});
 if(!response.ok)throw new Error((await response.text()).slice(0,400));
 const text=await response.text();return text?JSON.parse(text):null;
}
