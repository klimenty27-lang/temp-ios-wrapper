import WebKit

final class TempWeakScriptHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target; super.init() }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

enum TempMobileScripts {
    static let loginMemory = #"""
if (location.protocol === "https:" && location.hostname === "temp-kz.pages.dev") {
/* TEMP — remember only the last successful login; passwords stay with the system password manager. */
(function(root){
 'use strict';
 if(root.TempLoginMemory)return;
 const PREFIX='TEMP_LOGIN_MEMORY_V8';
 const handled=new WeakSet();let subscribed=false,pending=false;
 function slot(){try{return localStorage.getItem('TEMP_ACTIVE_AUTH_SLOT_V1253')==='bot'?'bot':'main';}catch(_){return 'main';}}
 function key(){return PREFIX+':'+slot();}
 function isEnabled(){try{return localStorage.getItem(PREFIX+':enabled')!=='false';}catch(_){return false;}}
 function remembered(){try{return isEnabled()?localStorage.getItem(key())||'':'';}catch(_){return '';}}
 function saveEmail(email){
   if(!isEnabled()||typeof email!=='string'||!email.trim()||email.length>320)return;
   try{localStorage.setItem(key(),email.trim());}catch(_){}
 }
 function forget(){
   try{localStorage.removeItem(key());}catch(_){}
   const field=document.querySelector('#authEmail');if(field)field.value='';
 }
 function enable(value){
   try{localStorage.setItem(PREFIX+':enabled',value?'true':'false');if(!value){localStorage.removeItem(PREFIX+':main');localStorage.removeItem(PREFIX+':bot');}}catch(_){}
   const check=document.querySelector('#temp-remember-login-v8');if(check)check.checked=!!value;
 }
 function credentialsSucceeded(session){if(session?.user?.email)saveEmail(session.user.email);}
 function subscribe(){
   if(subscribed||typeof sb==='undefined'||!sb?.auth?.onAuthStateChange)return;
   subscribed=true;
   // No Supabase requests in the auth callback. Never intercept logout or mutate tokens.
   sb.auth.onAuthStateChange((event,s)=>{if(['INITIAL_SESSION','SIGNED_IN','TOKEN_REFRESHED'].includes(event))credentialsSucceeded(s);});
   Promise.resolve(sb.auth.getSession()).then(r=>credentialsSucceeded(r.data?.session)).catch(()=>{});
 }
 function enhance(){
   subscribe();
   const input=document.getElementById('authEmail'),password=document.getElementById('authPassword');
   if(!input||!password)return;
   const form=input.closest('form');if(!form)return;
   // Signup and password recovery retain their own autocomplete semantics.
   const submit=form.getAttribute('onsubmit')||'';
   if(!/\blogin\s*\(/.test(submit)||password.getAttribute('autocomplete')==='new-password')return;
   if(handled.has(form))return;handled.add(form);
   input.setAttribute('autocomplete','username');input.setAttribute('autocapitalize','none');input.setAttribute('autocorrect','off');input.spellcheck=false;
   if(!input.name)input.name='username';
   password.setAttribute('autocomplete','current-password');if(!password.name)password.name='password';
   form.setAttribute('autocomplete','on');
   if(!input.value&&document.activeElement!==input)input.value=remembered();
   const row=document.createElement('div');row.id='temp-login-options-v8';
   row.style.cssText='display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;font-size:13px;margin:4px 0 8px;color:inherit';
   const label=document.createElement('label');label.style.cssText='display:flex;align-items:center;gap:8px;cursor:pointer';
   const checkbox=document.createElement('input');checkbox.type='checkbox';checkbox.id='temp-remember-login-v8';checkbox.checked=isEnabled();
   checkbox.style.cssText='width:18px!important;height:18px!important;min-height:0!important;margin:0;accent-color:#ff941e;appearance:auto;-webkit-appearance:auto';
   checkbox.addEventListener('change',()=>enable(checkbox.checked));
   label.append(checkbox,document.createTextNode('Запомнить логин'));
   const clear=document.createElement('button');clear.type='button';clear.textContent='Другой логин';
   clear.style.cssText='padding:6px 0;border:0;background:transparent;color:#ffb15a;font:inherit;cursor:pointer;box-shadow:none';
   clear.addEventListener('click',()=>{input.value='';input.focus();});
   row.append(label,clear);
   const button=form.querySelector('button[type="submit"]');if(button)button.before(row);else form.append(row);
 }
 function schedule(){if(pending)return;pending=true;requestAnimationFrame(()=>{pending=false;enhance();});}
 root.TempLoginMemory=Object.freeze({forget,setEnabled:enable,isEnabled,getSavedLogin:remembered});
 new MutationObserver(records=>{
   if(records.some(r=>r.target.nodeType===1&&(r.target.id==='app'||r.target.closest?.('.auth-wrap,.auth-card')||[...r.addedNodes].some(n=>n.nodeType===1&&(n.id==='app'||n.querySelector?.('#authEmail'))))))schedule();
 }).observe(document.documentElement,{childList:true,subtree:true});
 enhance();
})(window);

}
"""#
    static let settingsEntry = #"""
/* TEMP iOS 8 — one native settings entry on the actual More page (also works with unchanged 12.68.4). */
(function(root){
 'use strict';
 if(location.protocol!=='https:'||location.hostname!=='temp-kz.pages.dev'||root.TempMobileSettingsEntryV8)return;
 root.TempMobileSettingsEntryV8=true;
 const ID='temp-native-settings-entry-v8';let scheduled=false;
 function isMore(main){
   const active=document.querySelector('.navbtn.active');
   const action=active?.getAttribute('onclick')||'';
   if(!/\bgo\(['"]settings['"]\)/.test(action)&&active?.dataset?.t36!=='settings')return false;
   // Do not inject into internal forms that happen to retain the active More tab.
   return !!main.querySelector('[onclick="logout()"]')&&[...main.querySelectorAll('.section-title')].some(x=>x.textContent.trim()==='Организация');
 }
 function install(){
   const main=document.getElementById('main');
   if(!main||!isMore(main)||main.querySelector('#'+ID))return;
   const native=root.webkit?.messageHandlers?.tempNativeSettings;if(!native)return;
   const section=document.createElement('section');section.id=ID;
   section.style.cssText='margin:0 0 16px;';
   const button=document.createElement('button');button.type='button';button.className='btn btn-soft btn-block';
   button.style.cssText='display:flex;width:100%;align-items:center;justify-content:space-between;gap:12px;padding:15px 16px;text-align:left;min-height:52px';
   const text=document.createElement('span');
   const title=document.createElement('b');title.textContent='Настройки';title.style.display='block';
   const sub=document.createElement('small');sub.textContent='Вход и безопасность · О приложении';sub.style.cssText='display:block;margin-top:4px;font-size:12px;opacity:.85';
   text.append(title,sub);const arrow=document.createElement('span');arrow.textContent='›';arrow.setAttribute('aria-hidden','true');
   button.append(text,arrow);
   button.addEventListener('click',event=>{
     if(!event.isTrusted)return;
     const webVersion=root.TempRelease?.version||document.documentElement.dataset.tempVersion||root.TEMP_VERSION||'';
     native.postMessage({action:'open',webVersion:String(webVersion).slice(0,40),savedLogin:root.TempLoginMemory?.getSavedLogin()||'',rememberLogin:root.TempLoginMemory?.isEnabled()!==false});
   });
   section.append(button);main.prepend(section);
 }
 function schedule(){if(scheduled)return;scheduled=true;requestAnimationFrame(()=>{scheduled=false;install();});}
 new MutationObserver(records=>{
   if(records.some(r=>r.target.nodeType===1&&(r.target.id==='app'||r.target.id==='main'||r.target.closest?.('#main')||[...r.addedNodes].some(n=>n.nodeType===1&&(n.id==='main'||n.querySelector?.('#main'))))))schedule();
 }).observe(document.documentElement,{subtree:true,childList:true});
 install();
})(window);

"""#
}
