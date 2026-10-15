/* Appwrite email/password login. The SDK keeps its session in the browser cookie jar. */
(function(){
 'use strict';
 const {account,ID}=window.MadrasahAppwrite;
 const $=id=>document.getElementById(id),screen=$('loginScreen'),app=$('appShell'),form=$('loginForm'),error=$('loginError'),submit=$('loginSubmit'),email=$('loginEmail'),password=$('loginPassword'),emailLabel=$('loginEmailLabel'),passwordLabel=$('loginPasswordLabel');
 let startApp=null,currentUser=null,mode='login';
 const msg=t=>{error.textContent=t||''};
 function showLogin(){app.hidden=true;screen.hidden=false;currentUser=null}
 function enter(user){currentUser=user||{};screen.hidden=true;app.hidden=false;$('authUser').textContent=currentUser.email||'';startApp?.()}
 function setMode(next){mode=next;msg('');const reset=next==='reset',create=next==='signup',recover=next==='recover';$('loginTitle').textContent=create?'নতুন Appwrite account তৈরি করুন':recover?'পাসওয়ার্ড রিসেট করুন':reset?'নতুন পাসওয়ার্ড দিন':'আপনার account-এ প্রবেশ করুন';$('loginDescription').textContent=create?'ইমেইল ও অন্তত ৮ অক্ষরের পাসওয়ার্ড দিয়ে account খুলুন।':recover?'আপনার ইমেইলে password reset link পাঠানো হবে।':reset?'নতুন পাসওয়ার্ড লিখুন।':'একই Appwrite account Web ও Windows app-এ ব্যবহার করুন।';emailLabel.hidden=reset;email.hidden=reset;email.required=!reset;passwordLabel.hidden=recover;password.hidden=recover;password.required=!recover;passwordLabel.textContent=reset?'নতুন পাসওয়ার্ড':'পাসওয়ার্ড';password.autocomplete=create||reset?'new-password':'current-password';submit.textContent=create?'অ্যাকাউন্ট তৈরি করুন':recover?'Reset link পাঠান':reset?'পাসওয়ার্ড বদলান':'লগইন করুন';$('authModeLine').hidden=recover||reset;$('recoverPassword').hidden=create||recover||reset;$('authModeToggle').textContent=create?'লগইন করুন':'অ্যাকাউন্ট তৈরি করুন';}
 function explain(e){const code=e?.code||e?.type||0;if(code===401)return 'ইমেইল বা পাসওয়ার্ড সঠিক নয়।';if(code===409)return 'এই ইমেইলে account আগে থেকেই আছে—লগইন করুন।';if(code===400)return 'ইমেইল ও পাসওয়ার্ড যাচাই করে আবার চেষ্টা করুন।';return 'Appwrite-এ যোগাযোগ করা যায়নি। Internet ও Appwrite platform/domain সেটিংস পরীক্ষা করুন।'}
 async function submitForm(e){
  e.preventDefault();msg('');submit.disabled=true;const action=mode;
  try{
   if(action==='signup'){
    if(password.value.length<8)throw new Error('পাসওয়ার্ড অন্তত ৮ অক্ষরের হতে হবে।');
    await account.create({userId:ID.unique(),email:email.value.trim(),password:password.value,name:email.value.trim().split('@')[0]});
    await account.createEmailPasswordSession({email:email.value.trim(),password:password.value});
    form.reset();enter(await account.get());
   }else if(action==='login'){
    await account.createEmailPasswordSession({email:email.value.trim(),password:password.value});
    form.reset();enter(await account.get());
   }else if(action==='recover'){
    await account.createRecovery({email:email.value.trim(),url:location.origin+location.pathname});
    setMode('login');msg('Password reset link আপনার ইমেইলে পাঠানো হয়েছে।');
   }else if(action==='reset'){
    const params=new URLSearchParams(location.search),userId=params.get('userId'),secret=params.get('secret');
    if(!userId||!secret)throw new Error('Reset link-টি অসম্পূর্ণ বা মেয়াদোত্তীর্ণ। নতুন link নিন।');
    if(password.value.length<8)throw new Error('পাসওয়ার্ড অন্তত ৮ অক্ষরের হতে হবে।');
    await account.updateRecovery({userId,secret,password:password.value});history.replaceState(null,'',location.pathname);setMode('login');msg('পাসওয়ার্ড বদলানো হয়েছে। এখন নতুন পাসওয়ার্ড দিয়ে লগইন করুন।');
   }
  }catch(ex){msg(ex.message?.startsWith('পাসওয়ার্ড')||ex.message?.startsWith('Reset link')?ex.message:ex.message?.includes('User already exists')?'এই ইমেইলে account আগে থেকেই আছে—লগইন করুন।':ex.message?.includes('Invalid credentials')?'ইমেইল বা পাসওয়ার্ড সঠিক নয়।':ex.message?.includes('Invalid `email`')?'সঠিক ইমেইল লিখুন।':ex.message?.includes('password')?'পাসওয়ার্ড Appwrite-এর নিয়ম অনুযায়ী লিখুন।':ex.code?explain(ex):'অনুরোধ সম্পন্ন হয়নি। '+(ex.message||''));}
  finally{submit.disabled=false;}
 }
 async function logout(){try{await account.deleteSession({sessionId:'current'})}catch{}showLogin();setMode('login');msg('আপনি লগ আউট করেছেন।')}
 function protect(callback){startApp=callback;form.addEventListener('submit',submitForm);$('authModeToggle').onclick=()=>setMode(mode==='signup'?'login':'signup');$('recoverPassword').onclick=()=>setMode('recover');$('logoutButton').onclick=logout;const reset=new URLSearchParams(location.search);if(reset.has('userId')&&reset.has('secret'))setMode('reset');else setMode('login');showLogin();account.get().then(enter).catch(()=>showLogin())}
 window.MadrasahAuth={protect,getUser:()=>currentUser};
})();
