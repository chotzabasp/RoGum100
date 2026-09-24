/* ============================================================
   JavaScript ทั้งหมดของ index.html (ย้ายออกมาจากแท็ก <script> เดิมแบบคำต่อคำ 2026-09-24)
   โหลดแบบ script ธรรมดาต่อจาก supabase-js ที่ท้าย index.html — ลำดับการทำงานเหมือนตอนอยู่ในหน้าเดิมทุกอย่าง
   ที่อยู่ไฟล์ใน import() อ้างจากโฟลเดอร์ assets/ นี้ (เช่น ./custom-boss-api.js)
   ส่วนที่อยู่รูป/ลิงก์ในโค้ด (เช่น assets/Poring.gif ใน innerHTML) ยังอ้างจากหน้าเว็บตามเดิม ไม่ต้องแก้
   แก้ไฟล์นี้แล้วต้องเปลี่ยนเลข ?v= ที่แท็ก <script src> ใน index.html ทุกครั้ง ไม่งั้นผู้ใช้บางคนจะได้ไฟล์เก่าค้างในเครื่อง
   ============================================================ */
(async function(){
  "use strict";

  var supa = window.supabase.createClient(
    'https://jnwckkcjurchnppekhpc.supabase.co',
    'sb_publishable_Z_xnoeSTMY2t-VqaDfPmKg_FfOCjTOf'
  );
  var CustomAPI = (await import('./custom-boss-api.js')).createCustomBossAPI(supa);

  // ---------- บันทึกการใช้งานเว็บ (ส่งเข้า log_events → แดชบอร์ดแอดมิน admin.html) ----------
  // เก็บแค่: เข้าเว็บ, เปิดหน้าไหน/อยู่นานเท่าไหร่, ขั้นตอนการซื้อแพ็กเกจ, สมัครสมาชิก
  // แต่ละเครื่องมีรหัสสุ่ม (ไม่ใช่ข้อมูลส่วนตัว) · ส่งเป็นชุดทุก 10 วินาที/ตอนสลับแท็บ · ส่งไม่ผ่านก็ทิ้ง ไม่กระทบการใช้งาน
  // ชื่อเหตุการณ์/หน้าต้องอยู่ในรายการที่ log_events อนุญาต (supabase/migrations/20260924000400_app_events.sql)
  var Track = (function(){
    var vid, queue = [], timer = null, curPage = null, acc = 0;
    var visibleSince = document.hidden ? 0 : Date.now();
    try{
      vid = localStorage.getItem('gum100_vid');
      if(!vid || !/^[A-Za-z0-9-]{8,40}$/.test(vid)){
        vid = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : (Date.now().toString(36)+'-'+Math.random().toString(36).slice(2,12));
        localStorage.setItem('gum100_vid', vid);
      }
    }catch(e){ vid = 'tmp-'+Math.random().toString(36).slice(2,12); }
    function flush(){
      if(!queue.length) return;
      var batch = queue.splice(0, 30);
      supa.rpc('log_events', { p_visitor: vid, p_events: batch }).then(function(){}, function(){});
      if(queue.length) flush();
    }
    function push(e, page, value, meta){
      queue.push({ e:e, p:page||null, v:value==null ? null : Math.max(0, Math.round(value)), m:meta||null });
      if(queue.length >= 25){ flush(); return; }
      if(!timer) timer = setTimeout(function(){ timer = null; flush(); }, 10000);
    }
    // เวลาที่อยู่ในหน้าเดิม: นับเฉพาะตอนแท็บเปิดดูอยู่ ส่งทีละช่วง (ตอนเปลี่ยนหน้า/ซ่อนแท็บ) ช่วงละไม่เกิน 30 นาที
    function sendPageTime(){
      if(visibleSince){ acc += Date.now() - visibleSince; visibleSince = document.hidden ? 0 : Date.now(); }
      var s = Math.min(1800, Math.round(acc/1000));
      acc = 0;
      if(curPage && s >= 2) push('page_time', curPage, s);
    }
    function page(p){
      if(!p || p === curPage) return;
      sendPageTime();
      curPage = p;
      push('page_view', p);
    }
    document.addEventListener('visibilitychange', function(){
      if(document.hidden){ sendPageTime(); visibleSince = 0; flush(); }
      else visibleSince = Date.now();
    });
    // ประเภทอุปกรณ์ (แนบไปกับ 'visit'): จอสัมผัส + ด้านสั้นของจอ < 600px = มือถือ, จอสัมผัสที่ใหญ่กว่านั้น = แท็บเล็ต
    function deviceType(){
      var coarse = !!(window.matchMedia && matchMedia('(pointer: coarse)').matches);
      var shortSide = Math.min(screen.width || 0, screen.height || 0) || Math.min(window.innerWidth, window.innerHeight);
      if(coarse && shortSide < 600) return 'mobile';
      return coarse ? 'tablet' : 'desktop';
    }
    try{
      if(!sessionStorage.getItem('gum100_visit')){ sessionStorage.setItem('gum100_visit', '1'); push('visit', null, null, deviceType()); }
    }catch(e){ push('visit', null, null, deviceType()); }
    // error ที่ผู้ใช้เจอ: error เดิมส่งครั้งเดียวต่อการเปิดเว็บ และไม่เกิน 10 เรื่อง (ฐานข้อมูลกันซ้ำอีกชั้น)
    // kind: 'js' โค้ดพัง · 'promise' งานเบื้องหลังล้มเหลว · 'sync' ซิงก์ขึ้นคลาวด์ไม่ได้ · 'load' โหลดจากคลาวด์ไม่ได้
    var errSent = {}, errCount = 0;
    function error(kind, msg){
      msg = String(msg == null ? '' : msg).replace(/\s+/g, ' ').trim().slice(0, 200);
      var key = kind + '|' + msg;
      if(!msg || errSent[key] || errCount >= 10) return;
      errSent[key] = true; errCount++;
      queue.push({ e:'client_error', p:curPage, v:null, m:kind, d:msg });
      if(!timer) timer = setTimeout(function(){ timer = null; flush(); }, 10000);
    }
    function errText(x){
      if(!x) return '';
      if(typeof x === 'string') return x;
      return x.message || x.error_description || x.msg || (x.code ? 'code ' + x.code : '') || String(x);
    }
    window.addEventListener('error', function(ev){
      if(!ev || !ev.message) return; // ไม่ใช่ error ของโค้ด (เช่นรูปโหลดไม่ขึ้น) ไม่นับ
      var at = ev.filename ? ' @' + String(ev.filename).split('/').pop().split('?')[0] + ':' + (ev.lineno || 0) : '';
      error('js', ev.message + at);
    });
    window.addEventListener('unhandledrejection', function(ev){ error('promise', errText(ev && ev.reason)); });
    return { push:push, page:page, flush:flush, error:function(kind, x){ error(kind, errText(x)); } };
  })();

  var pad2 = function(n){ return String(n).padStart(2,'0'); };
  var todayKey = function(ts){ return new Date(ts).toDateString(); };
  var dayShift = function(ts, days){ return new Date(new Date(ts).setDate(new Date(ts).getDate()+days)); };
  var fmtDate = function(ts){ return new Date(ts).toLocaleDateString('th-TH', {day:'numeric',month:'short',year:'numeric'}); };
  var fmtDateTime = function(ts){ return new Date(ts).toLocaleString('th-TH', {day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'}); };
  var fmtClock = function(ts){ return new Date(ts).toLocaleTimeString('th-TH', {hour12:false}); };

  // Parses "the clock time the boss died" from the นาที field, accepting either
  // "14.35" (hour.minute — minute taken literally, so ".5" means :05) or a bare "1435"/
  // "935" (HHMM/HMM, last 2 digits are minutes). Returns a timestamp for today at that
  // time, rolled back one day if it would otherwise land in the future (a boss can't die
  // later than "now") — or null if the text doesn't parse into a valid time at all.
  function parseDeathTimeInput(raw){
    raw = String(raw||'').trim();
    if(!raw) return null;
    var hh, mm;
    if(raw.indexOf('.')!==-1 || raw.indexOf(':')!==-1){
      var parts = raw.split(/[.:]/);
      if(parts.length!==2 || !/^\d+$/.test(parts[0]) || !/^\d+$/.test(parts[1])) return null;
      hh = parseInt(parts[0], 10); mm = parseInt(parts[1], 10);
    } else if(/^\d{3,4}$/.test(raw)){
      hh = parseInt(raw.slice(0, raw.length-2), 10);
      mm = parseInt(raw.slice(-2), 10);
    } else {
      return null;
    }
    if(!(hh>=0 && hh<=23) || !(mm>=0 && mm<=59)) return null;
    var d = new Date();
    d.setHours(hh, mm, 0, 0);
    if(d.getTime() > Date.now()) d.setDate(d.getDate()-1);
    return d.getTime();
  }

  function fmtDuration(ms){
    var neg = ms < 0;
    ms = Math.abs(ms);
    var h = Math.floor(ms/3600000);
    var m = Math.floor((ms%3600000)/60000);
    var s = Math.floor((ms%60000)/1000);
    return (neg?'+':'') + h+':'+pad2(m)+':'+pad2(s);
  }

  function store(key, fallback){
    try{ var v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; }
    catch(e){ return fallback; }
  }
  // เขียนไม่ลงเมื่อไหร่ (พื้นที่เบราว์เซอร์เต็ม) จำไว้ — ตัวซิงก์คลาวด์จะเลิกเชื่อแคชในเครื่องแล้วดึงใหม่ทั้งหมด
  var cachePersistFailed = false;
  function persist(key, val){
    try{ localStorage.setItem(key, JSON.stringify(val)); }catch(e){ cachePersistFailed = true; }
  }

  // Simulates the backend boss catalog — the full list an admin maintains,
  // which the user searches to build their own roster.
  // แคตตาล็อกบอสกลาง — โหลดจากตาราง `bosses` ใน Supabase แทนของคงที่ในโค้ด
  // เพื่อให้แอดมินเพิ่ม/แก้บอสได้ผ่าน Table Editor โดยไม่ต้องแก้ไฟล์นี้อีก
  var CATALOG = [];
  function loadCatalog(){
    return supa.from('bosses').select('*').then(function(res){
      if(res.error){ console.error('loadCatalog', res.error); return; }
      CATALOG = (res.data||[]).map(function(b){
        return { id:b.id, name:b.name, glyph:b.glyph, imageUrl:b.image_url, map:b.map, mapImageUrl:b.map_image_url, loc:b.map_location, minutes:b.respawn_minutes, items:b.items||[] };
      });
      if(App.isGuest) renderRoster(); // ผู้เยี่ยมชม: แคตตาล็อกมาถึงแล้วค่อยวางการ์ดตัวอย่าง
    });
  }
  // รูปไอเทมจากตาราง items (ชื่อ → ลิงก์รูป) แอดมินใส่ผ่าน Table Editor เหมือนรูปบอส/แมพ
  var ITEM_IMAGES = {};
  function itemImageUrl(name){ var key=(name||'').trim().toLowerCase(); return Object.prototype.hasOwnProperty.call(ITEM_IMAGES,key) ? ITEM_IMAGES[key] : null; }
  function itemIconHtml(name, cls){
    var url = itemImageUrl(name);
    return url ? '<img class="'+cls+'" src="'+url.replace(/"/g,'&quot;')+'" alt="">' : '';
  }
  function loadItemImages(){
    return supa.from('items').select('name, image_url').then(function(res){
      if(res.error){ console.error('loadItemImages', res.error); return; }
      ITEM_IMAGES = {};
      (res.data||[]).forEach(function(r){ if(r.image_url) ITEM_IMAGES[(r.name||'').trim().toLowerCase()] = r.image_url; });
      if(App.session){ renderRoster(); renderStats(); } else if(App.isGuest) renderRoster();
    });
  }
  function bossAvatarHtml(boss){
    return boss.imageUrl ? '<img src="'+boss.imageUrl+'" alt="">' : (boss.glyph||'');
  }
  function bossMapHtml(boss){
    return boss.mapImageUrl ? '<img src="'+boss.mapImageUrl+'" alt="">' : mapSVG(boss.map);
  }

  // รายชื่อ + เรทตั้งต้นของแต่ละเซิร์ฟเวอร์ — โหลดจากตาราง `servers` ใน Supabase
  // แทนของคงที่ในโค้ด แอดมินเพิ่ม/ลบ/แก้ได้ผ่าน Table Editor ผู้ใช้เลือกได้เท่าที่มีจริง
  var SERVER_RATES = [];
  function loadServers(){
    return supa.from('servers').select('*').order('sort_order').then(function(res){
      if(res.error){ console.error('loadServers', res.error); return; }
      SERVER_RATES = (res.data||[]).map(function(s){
        return { id:s.id, name:s.name, buy:s.buy, sell:s.sell, active:s.active!==false, sortOrder:s.sort_order||0 };
      });
    });
  }
  // ---------- "เซิร์ฟเวอร์ที่เล่น" (profiles.servers) เป็นตัวกรองกลางของทุก dropdown เลือกเซิร์ฟ ----------
  // ยกเว้นที่เกี่ยวกับประวัติ ซึ่งต้องโชว์เซิร์ฟที่เคยมีข้อมูลบันทึกไว้ต่อไป แม้จะพักอยู่
  // (ดู historyServerIds สำหรับประวัติซื้อ-ขาย, farmServerIds สำหรับหน้าฟาม, populateItemsServerSelect สำหรับคลังไอเทม)
  function myServerIds(){
    var picked = (App.profile && App.profile.servers) || [];
    var live = SERVER_RATES.filter(function(s){ return picked.indexOf(s.id)!==-1; }).map(function(s){ return s.id; });
    // ผู้เยี่ยมชม / โปรไฟล์ยังโหลดไม่เสร็จ / เซิร์ฟที่เลือกไว้ถูกลบออกจากระบบหมด → ใช้ทุกเซิร์ฟไปก่อน
    // ไม่งั้น dropdown จะว่างเปล่าและกดอะไรไม่ได้เลย
    return live.length ? live : SERVER_RATES.map(function(s){ return s.id; });
  }
  function isRetiredServer(id){ return id!=null && myServerIds().indexOf(id)===-1; }
  // เซิร์ฟพัก (ไม่ได้เล่นแล้ว) ที่เคยมีประวัติ ค่าเริ่มต้น "ซ่อน" ทั้งหมด — ผู้ใช้ต้องมาติ๊กเปิดเองที่
  // หน้าตั้งค่า (การ์ด "เซิร์ฟเวอร์เก่า (พัก) ที่มีประวัติ") ถึงจะโผล่กลับมาใน dropdown ประวัติ/กราฟ
  // เก็บในเครื่อง (localStorage) ไม่ผูกกับบัญชี ไม่ต้องรัน SQL — เปลี่ยนเครื่อง/ล้างเบราว์เซอร์แล้วรีเซ็ตกลับเป็นซ่อนหมด
  function visibleRetiredServerIds(){
    if(!App.keys) return [];
    var v = store(App.keys.retiredServerVisible, []);
    return Array.isArray(v) ? v : [];
  }
  function isRetiredServerVisible(id){ return visibleRetiredServerIds().indexOf(id)!==-1; }
  function setRetiredServerVisible(id, show){
    var v = visibleRetiredServerIds();
    var idx = v.indexOf(id);
    if(show && idx===-1) v.push(id);
    else if(!show && idx!==-1) v.splice(idx, 1);
    persist(App.keys.retiredServerVisible, v);
  }
  // เซิร์ฟที่ "จะโชว์" ใน dropdown ประวัติ/กราฟ = ไม่พัก หรือ พักแต่ติ๊กเปิดไว้
  function isHistoryServerShown(id){ return !isRetiredServer(id) || isRetiredServerVisible(id); }
  // โควต้าจำนวนเซิร์ฟเวอร์ต่อบัญชี — ฟรี 1 เซิร์ฟ ซื้อเพิ่มครั้งละ 30 แต้ม (สล็อตถาวร)
  // ตัวจริงบังคับที่ฝั่งฐานข้อมูล (set_my_servers/buy_server_slot) ตรงนี้แค่ใช้วาดหน้าจอ
  var SERVER_SLOT_COST = 30;
  function serverQuota(){
    var q = App.profile && App.profile.server_quota;
    return (typeof q === 'number' && q > 0) ? q : 1;
  }
  // ซื้อ "ช่องเซิร์ฟเวอร์" เพิ่ม 1 ช่อง — ซื้อแล้วได้แค่โควต้า ยังไม่ผูกกับเซิร์ฟไหน
  // การ์ดใหม่จะซ้ำกับเซิร์ฟแรกไปก่อน จนกว่าผู้ใช้จะไปเลือกเซิร์ฟที่ 2 เองที่หน้าตั้งค่า
  // (แต้มหักที่ฝั่งเซิร์ฟเวอร์เท่านั้น ตรงนี้เช็คก่อนแค่เพื่อไม่ต้องยิง RPC ทิ้ง)
  function buyServerSlotFlow(){
    // เพดานช่องเท่ากับจำนวนการ์ดเรทสูงสุด — ซื้อเกินนี้ไม่มีที่ใช้ (ฐานข้อมูลก็บล็อกซ้ำใน buy_server_slot)
    if(serverQuota() >= MAX_RATE_CHIP_SLOTS){
      toast('มีช่องเซิร์ฟเวอร์ครบ '+MAX_RATE_CHIP_SLOTS+' ช่องแล้ว (สูงสุด)');
      return;
    }
    var have = (App.profile && App.profile.points) || 0;
    if(have < SERVER_SLOT_COST){
      toast('แต้มไม่พอ (ต้องการ '+SERVER_SLOT_COST+' แต้ม · มีอยู่ '+fmtNum(have)+')');
      return;
    }
    // ถ้าโควต้าที่มีอยู่ครอบคลุมทุกเซิร์ฟในระบบแล้ว ช่องใหม่จะยังไม่มีเซิร์ฟให้ใส่
    // ไม่ห้ามซื้อ (เผื่อมีเซิร์ฟใหม่เข้าระบบ) แต่ต้องบอกให้รู้ตัวก่อนเสียแต้ม
    var wasteWarn = serverQuota() >= SERVER_RATES.length
      ? '<br><br><b>หมายเหตุ:</b> ตอนนี้ระบบมี '+SERVER_RATES.length+' เซิร์ฟเวอร์ และคุณมีโควต้า '+serverQuota()+' ช่องแล้ว ช่องที่ซื้อเพิ่มจะยังใช้ไม่ได้จนกว่าจะมีเซิร์ฟเวอร์ใหม่เข้าระบบ'
      : '';
    // showConfirm ใช้ innerHTML เลยต้องขึ้นบรรทัดด้วย <br>
    showConfirm('เพิ่มช่องเซิร์ฟเวอร์อีก 1 ช่อง ใช้ <b>'+SERVER_SLOT_COST+' แต้ม</b> (เหลือ '+fmtNum(have-SERVER_SLOT_COST)+' แต้ม)<br><br>'+
      'ช่องใหม่จะซ้ำกับเซิร์ฟแรกไปก่อน — ไปเลือกว่าช่องใหม่เป็นเซิร์ฟไหนได้ที่หน้า <b>ตั้งค่า</b><br>'+
      'ช่องที่ซื้อเป็นของถาวร ลบการ์ดทิ้งแล้วเพิ่มใหม่ได้ฟรี'+wasteWarn, function(){
      supa.rpc('buy_server_slot').then(function(res){
        if(res.error){ toast(res.error.message || 'ซื้อโควต้าไม่สำเร็จ'); return; }
        return refreshProfile().then(function(){
          addRateSlot();
          renderAll();
          // เผื่อกดจากปุ่มในหน้าตั้งค่าเอง (การ์ด "เซิร์ฟเวอร์ที่เล่น") ให้ "เล่นอยู่ X/Y" และชิปที่ล็อกไว้
          // อัปเดตตามโควต้าใหม่ทันที ไม่ต้องออกจากหน้าแล้วกลับเข้ามาใหม่
          if(document.getElementById('view-settings') && !document.getElementById('view-settings').hidden) renderSettingsPage();
          toast('ได้ช่องเซิร์ฟเวอร์เพิ่มแล้ว — เลือกเซิร์ฟที่หน้า "ตั้งค่า"');
        });
      }, function(err){ console.warn('buy_server_slot', err); toast('ซื้อโควต้าไม่สำเร็จ ลองใหม่อีกครั้ง'); });
    });
  }
  // เพิ่มการ์ดราคา 1 ใบ: ถ้ายังมีเซิร์ฟที่เลือกไว้แต่ยังไม่มีการ์ด ใช้ตัวนั้นก่อน
  // ถ้าไม่มี (เช่นเพิ่งซื้อช่องแต่ยังไม่ได้เลือกเซิร์ฟที่ 2) ก็ซ้ำกับการ์ดแรกไปก่อน
  function addRateSlot(){
    var mine = myServerIds();
    if(!mine.length) return;
    var unused = mine.filter(function(id){ return App.rateSlots.indexOf(id)===-1; });
    App.rateSlots.push(unused.length ? unused[0] : (App.rateSlots[0] || mine[0]));
    saveRateSlots();
    syncMerchantServersWithRateSlots();
    syncTickerServersWithRateSlots();
  }
  // เรียกหลังล็อกอิน และหลังกด "บันทึกเซิร์ฟเวอร์" ในหน้าตั้งค่า —
  // ตัดเซิร์ฟที่ไม่ได้เล่นแล้วออกจากการ์ดราคา/ชิปประกาศ/กล่องซื้อ-ขาย ให้ตรงกับที่เลือกไว้
  // (ประวัติ คลังไอเทม และหน้าฟาม ไม่โดนตัด — จัดการแยกด้วย *ServerIds() ของตัวเอง)
  // addNew = true เฉพาะตอนกดบันทึกในหน้าตั้งค่า: เซิร์ฟที่เพิ่งเพิ่มเข้ามาจะได้การ์ดราคา
  // และชิปกรองประกาศให้เลยโดยไม่ต้องไปกดเพิ่มเองอีกรอบ ส่วนตอนล็อกอินจะแค่ "ตัดออก"
  // ไม่ใช่ "เติมกลับ" ไม่งั้นการ์ดที่ผู้ใช้ตั้งใจลบทิ้งจะโผล่กลับมาทุกครั้งที่เข้าเว็บ
  function pruneServerSelections(addNew){
    var mine = myServerIds();
    App.rateSlots = App.rateSlots.filter(function(id){ return mine.indexOf(id)!==-1; });
    if(addNew){
      mine.forEach(function(id){
        if(App.rateSlots.indexOf(id)!==-1) return;
        // เซิร์ฟที่เพิ่งเลือกเพิ่ม ให้ไปแทนที่ "ช่องที่ซ้ำ" (ช่องที่เพิ่งซื้อมาแล้วยังไม่ได้กำหนดเซิร์ฟ) ก่อน
        // ถ้าไม่มีช่องซ้ำเหลือ ค่อยเพิ่มการ์ดใหม่ — ไม่งั้นการ์ดจะงอกเกินจำนวนช่องที่ซื้อไว้
        var dupIdx = -1;
        for(var i=App.rateSlots.length-1; i>=0; i--){
          if(App.rateSlots.indexOf(App.rateSlots[i]) !== i){ dupIdx = i; break; }
        }
        if(dupIdx !== -1) App.rateSlots[dupIdx] = id;
        else if(App.rateSlots.length < Math.min(serverQuota(), MAX_RATE_CHIP_SLOTS)) App.rateSlots.push(id);
      });
    }
    // จำนวนการ์ดห้ามเกินจำนวนช่องที่ซื้อไว้ — กันกรณีโควต้าลดลง หรือมีคนไปแก้ค่าใน
    // localStorage เพื่อให้ตัวเองมีการ์ดเกินที่จ่ายมา (ตัดท้ายทิ้งให้พอดีโควต้า)
    var cap = Math.min(serverQuota(), MAX_RATE_CHIP_SLOTS);
    if(App.rateSlots.length > cap) App.rateSlots = App.rateSlots.slice(0, cap);
    if(!App.rateSlots.length) App.rateSlots = defaultRateSlots().slice(0, cap);
    saveRateSlots();
    syncMerchantServersWithRateSlots();
    syncTickerServersWithRateSlots();
  }
  function serverLabel(id){
    var sv = serverRateById(id);
    return (sv ? sv.name : id) + (isRetiredServer(id) ? ' (พัก)' : '');
  }
  function defaultRateSlots(){ return myServerIds().slice(0,3); }
  function defaultRateChipSlots(){ return myServerIds().slice(0,1); }
  var MAX_RATE_CHIP_SLOTS = 12;
  var RATE_MAX_DEVIATION = 0.30; // block a posted price more than ±30% away from the current rate (typo guard)
  // ลงประกาศใหม่เสียแต้มตามระยะเวลา (แก้ไขประกาศเดิมยังฟรีเหมือนเดิม — ดู postAnnounceSubmitBtn)
  // ค่า cost ต้องตรงกับที่ฟังก์ชัน post_announcement() ฝั่ง DB คำนวณเป๊ะๆ (เทียบจาก value เป็น ms)
  var ANNOUNCE_DURATION_OPTIONS = [
    { value:600000,   label:'10 นาที', cost:1 },
    { value:1800000,  label:'30 นาที', cost:2 },
    { value:3600000,  label:'1 ชม.',   cost:3 },
    { value:10800000, label:'3 ชม.',   cost:6 }
  ];
  function serverRateById(id){
    for(var i=0;i<SERVER_RATES.length;i++){ if(SERVER_RATES[i].id===id) return SERVER_RATES[i]; }
    return null;
  }

  var DataKeys = function(email){
    return {
      db:'mvpwatch_db_'+email, active:'mvpwatch_active_'+email,
      lastPage:'mvpwatch_lastpage_'+email,
      expiryWarn:'mvpwatch_expirywarn_'+email, pkgWarn:'mvpwatch_pkgwarn_'+email, pkgExpiredSeen:'mvpwatch_pkgexpired_'+email,
      rateSlots:'mvpwatch_rateslots_'+email, rateSlotsVer:'mvpwatch_rateslotsver_'+email, merchantLog:'mvpwatch_merchantlog_'+email,
      merchantServers:'mvpwatch_merchantservers_'+email, merchantItems:'mvpwatch_merchantitems_'+email,
      merchantExRate:'mvpwatch_merchantexrate_'+email,
      itemWarehouseStock:'mvpwatch_itemwarehousestock_'+email, itemsServer:'mvpwatch_itemsserver_'+email,
      itemLineClaimedQty:'mvpwatch_itemlineclaimedqty_'+email,
      currentServer:'mvpwatch_currentserver_'+email,
      farmCostItems:'mvpwatch_farmcost_'+email, farmLog:'mvpwatch_farmlog_'+email, farmServer:'mvpwatch_farmserver_'+email,
      farmOcHint:'mvpwatch_farmochint_'+email, farmExRate:'mvpwatch_farmexrate_'+email, farmMapNames:'mvpwatch_farmmapnames_'+email,
      tickerServers:'mvpwatch_tickerservers_'+email, tickerSelectedServers:'mvpwatch_tickerselectedservers_'+email,
      lastRateUpdateTs:'mvpwatch_lastrateupdatets_'+email,
      retiredServerVisible:'mvpwatch_retiredserversvisible_'+email,
      recentNewTx:'mvpwatch_recentnewtx_'+email, recentNewGroup:'mvpwatch_recentnewgroup_'+email
    };
  };

  // M only ever means "Zeny counted in units of 1,000,000" — the name is fixed and the
  // field that shows it is locked (readonly), so it can never end up mismatched, typo'd,
  // or accidentally entered in some other unit.
  var ZENY_LABEL = 'Zeny (หน่วย:M)';
  var App = { session:null, profile:null, isGuest:false, viewingHostId:null, viewingHostName:null, db:[], active:{}, markers:{}, kills:[], myLifetimeShare:{zeny:0,baht:0,count:0}, partyRoster:[], departedSharerNames:{}, keys:null, historyTab:'kills', pendingItems:{}, rateSlots:[], merchantLog:[], merchantServers:[], merchantItems:{zeny:[],item:[],other:[]}, merchantExchangeRates:{}, itemWarehouseStock:{}, itemLineClaimedQty:{}, itemsServerId:null, itemsSelectedTier:null, currentServerId:null, itemRows:[], zenyRows:[], otherRows:[], merchantType:'buy', merchantCategory:'zeny', farmCostItems:{}, farmExchangeRates:{}, farmMapNames:{}, farmLog:[], farmServerId:null, tickerServers:[], tickerSelectedServers:[], rateAnnouncements:[], lastRateUpdateTs:null };
  var fired = { warn:{}, threeMin:{} };
  var uid = function(){ return 'id'+Date.now().toString(36)+Math.random().toString(36).slice(2,7); };

  var RATE_SLOTS_VERSION = 2; // bump to force a one-time reset to the new 1-card default
  // cloudValues (ไม่บังคับ) = ค่าที่รวมกับคลาวด์แล้ว ชื่อตาม DataKeys — มีค่าไหนใช้ค่านั้นแทน localStorage
  function loadUserData(email, cloudValues){
    var keys = DataKeys(email);
    App.keys = keys;
    // ป้าย "New" ต้องอยู่ข้ามการรีเฟรชหน้า จนกว่าจะถูกกดเปิดดูจริง — เก็บใน localStorage แยกต่อบัญชี
    recentNewTxIds = store(keys.recentNewTx, {});
    recentNewGroupIds = store(keys.recentNewGroup, {});
    function read(name, fallback){
      if(cloudValues && Object.prototype.hasOwnProperty.call(cloudValues, name)){
        var v = cloudValues[name];
        return v==null ? fallback : JSON.parse(JSON.stringify(v));
      }
      return store(keys[name], fallback);
    }
    // App.db/App.active (รายการบอส+เวลาที่จับ) โหลดแยกจาก Supabase ใน loadUserBosses()
    App.pendingItems = {};
    if(read('rateSlotsVer', 0) !== RATE_SLOTS_VERSION){
      App.rateSlots = defaultRateChipSlots();
      persist(keys.rateSlots, App.rateSlots);
      persist(keys.rateSlotsVer, RATE_SLOTS_VERSION);
    } else {
      App.rateSlots = read('rateSlots', null) || defaultRateChipSlots();
    }
    if(App.rateSlots.length > MAX_RATE_CHIP_SLOTS){
      App.rateSlots = App.rateSlots.slice(0, MAX_RATE_CHIP_SLOTS);
      persist(keys.rateSlots, App.rateSlots);
    }
    App.merchantLog = read('merchantLog', []);
    var merchantLogNeedsIdFix = false;
    App.merchantLog.forEach(function(entry){
      if(!entry.id){ entry.id = uid(); merchantLogNeedsIdFix = true; }
      // legacy single-timestamp edit marker — carry it over as the first (detail-less) history entry
      if(entry.editedAt && !entry.editHistory){
        entry.editHistory = [{ ts: entry.editedAt, diff: null }];
        merchantLogNeedsIdFix = true;
      }
      // every line needs a stable id so the คลังไอเทม warehouse can track which lines
      // have already been dragged into a warehouse across edits/reloads
      (entry.lines||[]).forEach(function(l){
        if(!l.id){ l.id = uid(); merchantLogNeedsIdFix = true; }
      });
    });
    if(merchantLogNeedsIdFix) persist(keys.merchantLog, App.merchantLog);
    App.merchantServers = read('merchantServers', null) || myServerIds().slice();
    var storedMerchantItems = read('merchantItems', null);
    if(Array.isArray(storedMerchantItems)){
      // legacy flat list (pre category-split) — carry it over as "item" suggestions
      App.merchantItems = { zeny:[], item:storedMerchantItems, other:[] };
      persist(keys.merchantItems, App.merchantItems);
    } else {
      App.merchantItems = storedMerchantItems || { zeny:[], item:[], other:[] };
      if(!App.merchantItems.other) App.merchantItems.other = [];
    }
    App.merchantExchangeRates = read('merchantExRate', null) || {};
    App.itemWarehouseStock = read('itemWarehouseStock', null) || {};
    // Tracks, per server+purchase-line, how much has EVER been dropped into a
    // warehouse tier (increases on drop, decreases only on explicit "undo → back to
    // pending"). This is deliberately separate from live stock qty so that a later
    // SALE deduction — which reduces a record's qty in place — never makes the
    // pending list think the purchase was never warehoused. `null` (key never saved)
    // means a pre-upgrade install: bootstrap it once from whatever is currently
    // sitting in the warehouse so existing users' pending lists don't jump.
    var claimedQtyLoaded = read('itemLineClaimedQty', null);
    if(claimedQtyLoaded == null){
      claimedQtyLoaded = {};
      Object.keys(App.itemWarehouseStock).forEach(function(serverId){
        var w = App.itemWarehouseStock[serverId] || {};
        ITEM_WAREHOUSE_TIERS.forEach(function(tier){
          (w[tier]||[]).forEach(function(it){
            if(!it.lineId) return;
            if(!claimedQtyLoaded[serverId]) claimedQtyLoaded[serverId] = {};
            claimedQtyLoaded[serverId][it.lineId] = (claimedQtyLoaded[serverId][it.lineId]||0) + (parseFloat(it.qty)||0);
          });
        });
      });
      persist(keys.itemLineClaimedQty, claimedQtyLoaded);
    }
    App.itemLineClaimedQty = claimedQtyLoaded;
    App.itemsServerId = read('itemsServer', null);
    App.currentServerId = read('currentServer', null);
    if(App.merchantServers.indexOf(App.currentServerId)===-1) App.currentServerId = App.merchantServers[0] || null;
    App.farmCostItems = read('farmCostItems', {});
    App.farmExchangeRates = read('farmExRate', null) || {};
    App.farmMapNames = read('farmMapNames', null) || {};
    App.farmLog = read('farmLog', []);
    var farmLogNeedsIdFix = false;
    App.farmLog.forEach(function(entry){ if(entry && !entry.id){ entry.id = uid(); farmLogNeedsIdFix = true; } });
    if(farmLogNeedsIdFix) persist(keys.farmLog, App.farmLog);
    App.farmServerId = read('farmServer', null) || (SERVER_RATES[0] && SERVER_RATES[0].id) || null;
    App.tickerServers = read('tickerServers', null) || defaultRateSlots();
    App.tickerSelectedServers = read('tickerSelectedServers', null) || App.tickerServers.slice();
    App.tickerSelectedServers = App.tickerSelectedServers.filter(function(id){ return App.tickerServers.indexOf(id)!==-1; });
    App.lastRateUpdateTs = read('lastRateUpdateTs', null);
    // ประกาศ "รับ M" ไม่ได้อยู่ใน localStorage แล้ว — ย้ายไปเก็บใน Supabase ตาราง announcements
    // (กระดานร่วม ทุกคนเห็นประกาศของกันและกัน) เริ่มจากว่างไว้ก่อน แล้ว loadAnnouncements() เติมให้
    App.rateAnnouncements = [];
  }
  // ---------- ซิงก์ข้อมูลขึ้นคลาวด์ (Supabase) ----------
  // เดิม ประวัติซื้อ-ขาย / ยอดนักฟาม / คลังไอเทม / การตั้งค่า อยู่ใน localStorage อย่างเดียว → เปิดคนละเครื่อง
  // ไม่เห็น ล้างเบราว์เซอร์แล้วหายถาวร ตอนนี้คลาวด์เป็นตัวจริง ส่วน localStorage เหลือเป็นแคชในเครื่อง
  //   ประวัติ (ยาวขึ้นเรื่อยๆ) → ตาราง merchant_entries / farm_entries แถวละรายการ ส่งเฉพาะที่เปลี่ยน
  //   คลัง + การตั้งค่า (ก้อนเล็ก) → ตาราง user_app_data แถวละหัวข้อ
  // ทุกการเปลี่ยนแปลงลงคิวรอส่ง (outbox ใน localStorage เก็บแค่ id/ชื่อหัวข้อ) ก่อนยิงขึ้นคลาวด์ —
  // เน็ตหลุด/ปิดแท็บกลางคัน ของยังอยู่ในเครื่อง รอบหน้าส่งต่อเอง
  // ข้อควรรู้: คลัง/การตั้งค่าเป็นแบบ "บันทึกทีหลังชนะ" ถ้าสองเครื่องแก้หัวข้อเดียวกันในเวลาใกล้กันมาก
  // เลยคอยเช็คของใหม่บนคลาวด์ทุกนาที + ทุกครั้งที่กลับมาที่แท็บ ให้ช่วงที่ข้อมูลค้างสั้นที่สุด
  var CLOUD_ENTRY_SETS = {
    merchant: { table:'merchant_entries', name:'merchantLog', stateKey:'m', get:function(){ return App.merchantLog; } },
    farm:     { table:'farm_entries',     name:'farmLog',     stateKey:'f', get:function(){ return App.farmLog; } }
  };
  // ชื่อหัวข้อ = ชื่อใน DataKeys (ใช้เป็นทั้ง key บนคลาวด์และ key แคชใน localStorage)
  var CLOUD_KV = {
    rateSlots:             function(){ return App.rateSlots; },
    rateSlotsVer:          function(){ return RATE_SLOTS_VERSION; },
    merchantServers:       function(){ return App.merchantServers; },
    merchantItems:         function(){ return App.merchantItems; },
    merchantExRate:        function(){ return App.merchantExchangeRates; },
    itemWarehouseStock:    function(){ return App.itemWarehouseStock; },
    itemLineClaimedQty:    function(){ return App.itemLineClaimedQty; },
    itemsServer:           function(){ return App.itemsServerId; },
    currentServer:         function(){ return App.currentServerId; },
    farmCostItems:         function(){ return App.farmCostItems; },
    farmServer:            function(){ return App.farmServerId; },
    farmExRate:            function(){ return App.farmExchangeRates; },
    farmMapNames:          function(){ return App.farmMapNames; },
    tickerServers:         function(){ return App.tickerServers; },
    tickerSelectedServers: function(){ return App.tickerSelectedServers; }
  };
  // ย้ายข้อมูลครั้งแรกของเครื่องนี้ แต่คลาวด์มีของอยู่แล้ว (เคยย้ายจากอีกเครื่อง): หัวข้อเหล่านี้รวมของสองฝั่ง
  // ไม่ให้ของในคลัง/ชื่อไอเทมที่จำไว้ของเครื่องนี้หาย — หัวข้ออื่น (เรท เซิร์ฟที่เลือก ฯลฯ) ใช้ของบนคลาวด์
  var CLOUD_KV_MERGE_FIRST_SYNC = {
    merchantItems: function(cloud, local){
      var out = { zeny:[], item:[], other:[] };
      ['zeny','item','other'].forEach(function(cat){
        ((cloud && cloud[cat]) || []).concat((local && local[cat]) || []).forEach(function(n){
          if(out[cat].indexOf(n)===-1) out[cat].push(n);
        });
      });
      return out;
    },
    itemWarehouseStock: function(cloud, local){
      var out = cloudClone(cloud || {});
      Object.keys(local || {}).forEach(function(serverId){
        if(!out[serverId]) out[serverId] = {};
        Object.keys(local[serverId] || {}).forEach(function(tier){
          var arr = out[serverId][tier] = out[serverId][tier] || [];
          var have = {};
          arr.forEach(function(it){ if(it && it.id) have[it.id] = true; });
          (local[serverId][tier] || []).forEach(function(it){ if(it && !have[it.id]) arr.push(it); });
        });
      });
      return out;
    },
    itemLineClaimedQty: function(cloud, local){
      var out = cloudClone(cloud || {});
      Object.keys(local || {}).forEach(function(serverId){
        if(!out[serverId]) out[serverId] = {};
        Object.keys(local[serverId] || {}).forEach(function(lineId){
          out[serverId][lineId] = Math.max(out[serverId][lineId] || 0, local[serverId][lineId] || 0);
        });
      });
      return out;
    }
  };
  var cloudSync = {
    userId:null, email:null,
    ready:false,       // โหลด+รวมข้อมูลจากคลาวด์สำเร็จแล้วในรอบล็อกอินนี้ (ก่อนหน้านั้นเก็บคิวไว้เฉยๆ ยังไม่ส่ง)
    outbox:null,       // { merchant:{up:{id:1},del:{id:1}}, farm:{...}, kv:{name:1} }
    snap:{}, kvSnap:{},// JSON ตอนบันทึกครั้งล่าสุด — ไว้หาว่าอะไรเปลี่ยน
    knownState:null,   // ผลของ my_app_data_state() ล่าสุดที่รู้ ไว้เช็คว่ามีเครื่องอื่นแก้อะไรไหม
    chain:Promise.resolve(), flushTimer:null, retryDelay:0, failNotified:false, lastCheck:0
  };

  function cloudClone(v){ return v===undefined ? undefined : JSON.parse(JSON.stringify(v)); }
  function cloudOutboxKey(){ return 'mvpwatch_cloudoutbox_'+cloudSync.email; }
  function cloudSyncedKey(){ return 'mvpwatch_cloudsynced_'+cloudSync.email; }
  function cloudReadOutbox(){
    var saved = store(cloudOutboxKey(), null) || {};
    var out = { kv: saved.kv || {} };
    Object.keys(CLOUD_ENTRY_SETS).forEach(function(set){
      out[set] = { up: (saved[set] && saved[set].up) || {}, del: (saved[set] && saved[set].del) || {} };
    });
    return out;
  }
  function cloudSaveOutbox(){ if(cloudSync.userId && cloudSync.outbox) persist(cloudOutboxKey(), cloudSync.outbox); }
  function cloudHasFlushableWork(){
    var ob = cloudSync.outbox;
    if(!ob) return false;
    if(Object.keys(ob.kv).length) return true;
    if(isExpiredAccount()) return false; // บัญชีหมดอายุเขียนประวัติไม่ได้ — คิวค้างไว้จนต่ออายุ
    return Object.keys(CLOUD_ENTRY_SETS).some(function(set){
      return Object.keys(ob[set].up).length || Object.keys(ob[set].del).length;
    });
  }
  function cloudJsonIndex(arr){
    var idx = {};
    (arr || []).forEach(function(e){ if(e && e.id) idx[e.id] = JSON.stringify(e); });
    return idx;
  }
  function cloudResetSnapshots(){
    cloudSync.snap = {};
    Object.keys(CLOUD_ENTRY_SETS).forEach(function(set){ cloudSync.snap[set] = cloudJsonIndex(CLOUD_ENTRY_SETS[set].get()); });
    cloudSync.kvSnap = {};
    Object.keys(CLOUD_KV).forEach(function(name){ cloudSync.kvSnap[name] = JSON.stringify(CLOUD_KV[name]()); });
  }
  function cloudFingerprint(){
    var parts = [];
    Object.keys(CLOUD_ENTRY_SETS).forEach(function(set){ parts.push(JSON.stringify(CLOUD_ENTRY_SETS[set].get())); });
    Object.keys(CLOUD_KV).forEach(function(name){ parts.push(JSON.stringify(CLOUD_KV[name]())); });
    return parts.join('|#|');
  }

  // เรียกจาก saveMerchantLog / saveFarmLog: หาว่ารายการไหนเพิ่ม/แก้/ถูกลบ แล้วลงคิว
  function cloudQueueEntries(set){
    if(!cloudSync.userId || !cloudSync.outbox) return;
    var snap = cloudSync.snap[set] || {}, next = {}, ob = cloudSync.outbox[set];
    (CLOUD_ENTRY_SETS[set].get() || []).forEach(function(e){
      if(!e || !e.id) return;
      var json = JSON.stringify(e);
      next[e.id] = json;
      if(snap[e.id] !== json){ ob.up[e.id] = true; delete ob.del[e.id]; }
    });
    Object.keys(snap).forEach(function(id){
      if(!Object.prototype.hasOwnProperty.call(next, id)){ ob.del[id] = true; delete ob.up[id]; }
    });
    cloudSync.snap[set] = next;
    cloudSaveOutbox();
    cloudScheduleFlush();
  }
  // เรียกจาก save* ของคลัง/การตั้งค่า
  function cloudQueueKV(name){
    if(!cloudSync.userId || !cloudSync.outbox || !CLOUD_KV[name]) return;
    var json = JSON.stringify(CLOUD_KV[name]());
    if(cloudSync.kvSnap[name] === json) return;
    cloudSync.kvSnap[name] = json;
    cloudSync.outbox.kv[name] = true;
    cloudSaveOutbox();
    cloudScheduleFlush();
  }

  // งานซิงก์ทำทีละอย่างตามคิว (ส่ง/ดึง ไม่ทับกัน) และทิ้งงานของบัญชีที่ล็อกเอาต์ไปแล้ว
  function cloudRun(fn){
    var userAtStart = cloudSync.userId;
    var run = cloudSync.chain.then(function(){
      if(!cloudSync.userId || cloudSync.userId !== userAtStart) return;
      return fn();
    });
    cloudSync.chain = run.catch(function(){});
    return run;
  }
  function cloudScheduleFlush(delay){
    if(!cloudSync.userId) return;
    clearTimeout(cloudSync.flushTimer);
    cloudSync.flushTimer = setTimeout(function(){
      cloudRun(cloudFlush).catch(function(err){ console.warn('cloudFlush', err); });
    }, delay==null ? 700 : delay);
  }
  function cloudChunks(arr, size){
    var out = [];
    for(var i=0;i<arr.length;i+=size) out.push(arr.slice(i, i+size));
    return out;
  }
  function cloudIndexById(arr){
    var idx = {};
    (arr || []).forEach(function(e){ if(e && e.id) idx[e.id] = e; });
    return idx;
  }

  function cloudFlush(){
    if(!cloudSync.ready || !App.session) return; // ยังไม่ได้รวมข้อมูลกับคลาวด์ — คิวรอไว้ก่อน
    var userId = cloudSync.userId, ob = cloudSync.outbox, jobs = [];
    var entriesAllowed = !isExpiredAccount();
    Object.keys(CLOUD_ENTRY_SETS).forEach(function(set){
      if(!entriesAllowed) return;
      var cfg = CLOUD_ENTRY_SETS[set];
      var current = cloudIndexById(cfg.get());
      var rows = [], sent = {};
      Object.keys(ob[set].up).forEach(function(id){
        var e = current[id];
        if(!e){ delete ob[set].up[id]; ob[set].del[id] = true; return; }
        sent[id] = JSON.stringify(e);
        rows.push({ user_id:userId, id:id, ts:Math.round(Number(e.ts)||0), server_id:e.serverId || null, data:e });
      });
      cloudChunks(rows, 200).forEach(function(part){
        jobs.push(supa.from(cfg.table).upsert(part, { onConflict:'user_id,id' }).then(function(res){
          if(res.error) throw res.error;
          var now = cloudIndexById(cfg.get());
          part.forEach(function(r){
            // ระหว่างรอส่งถูกแก้ซ้ำ (JSON ไม่ตรงกับที่ส่งไป) → คงไว้ในคิว รอบหน้าส่งตัวล่าสุด
            if(!now[r.id] || JSON.stringify(now[r.id]) === sent[r.id]) delete ob[set].up[r.id];
          });
        }));
      });
      cloudChunks(Object.keys(ob[set].del), 200).forEach(function(ids){
        jobs.push(supa.from(cfg.table).delete().eq('user_id', userId).in('id', ids).then(function(res){
          if(res.error) throw res.error;
          ids.forEach(function(id){ if(!ob[set].up[id]) delete ob[set].del[id]; });
        }));
      });
    });
    var kvNames = Object.keys(ob.kv).filter(function(name){
      if(CLOUD_KV[name]) return true;
      delete ob.kv[name];
      return false;
    });
    if(kvNames.length){
      var sentKv = {};
      var kvRows = kvNames.map(function(name){
        var v = CLOUD_KV[name]();
        sentKv[name] = JSON.stringify(v);
        return { user_id:userId, key:name, value: v===undefined ? null : v };
      });
      jobs.push(supa.from('user_app_data').upsert(kvRows, { onConflict:'user_id,key' }).then(function(res){
        if(res.error) throw res.error;
        kvNames.forEach(function(name){ if(JSON.stringify(CLOUD_KV[name]()) === sentKv[name]) delete ob.kv[name]; });
      }));
    }
    if(!jobs.length){ cloudSaveOutbox(); return; }
    return Promise.all(jobs.map(function(p){
      return p.then(function(){ return null; }, function(err){ return err || new Error('sync failed'); });
    })).then(function(errors){
      if(cloudSync.userId !== userId) return;
      cloudSaveOutbox();
      var failed = errors.filter(function(x){ return x; });
      if(failed.length){ cloudOnFlushError(failed[0]); return; }
      cloudOnFlushOk();
      if(cloudHasFlushableWork()) cloudScheduleFlush(0);
      // จำสถานะล่าสุดหลังเราส่งเอง จะได้ไม่นับว่าเป็น "ของใหม่จากเครื่องอื่น"
      return cloudFetchState().then(function(state){ cloudSync.knownState = state; }, function(){});
    });
  }
  function cloudOnFlushError(err){
    console.warn('cloud sync failed', err);
    Track.error('sync', err);
    cloudSync.retryDelay = Math.min(60000, cloudSync.retryDelay ? cloudSync.retryDelay*2 : 5000);
    cloudScheduleFlush(cloudSync.retryDelay);
    if(!cloudSync.failNotified){
      cloudSync.failNotified = true;
      toast('ยังบันทึกขึ้นคลาวด์ไม่ได้ — ข้อมูลยังอยู่ในเครื่องนี้ ระบบจะลองส่งใหม่เอง');
    }
  }
  function cloudOnFlushOk(){
    cloudSync.retryDelay = 0;
    if(cloudSync.failNotified){
      cloudSync.failNotified = false;
      toast('ส่งข้อมูลที่ค้างขึ้นคลาวด์เรียบร้อยแล้ว');
    }
  }

  function cloudFetchState(){
    return supa.rpc('my_app_data_state').then(function(res){
      if(res.error) throw res.error;
      return JSON.stringify(res.data);
    });
  }
  // ---- ดึงข้อมูลจากคลาวด์แบบ "เฉพาะที่เปลี่ยน" ----
  // เครื่องจำ cursor = เวลาแก้ล่าสุดบนคลาวด์ ณ รอบที่รวมข้อมูลลงเครื่องครั้งล่าสุด (เก็บคู่กับแคชใน localStorage)
  // รอบถัดไปขอแค่แถวที่ updated_at ใหม่กว่านั้น ส่วนแถวเก่าใช้ของในเครื่อง แล้วเทียบ "จำนวนแถว" กับคลาวด์:
  // ไม่ตรง (มีคนลบ/มีแถวตกหล่น) หรือมีคิวค้าง → ขอรายชื่อ id ทั้งหมด (เล็กมาก) มาเทียบ ลบของที่หายไป + ดึงแถวที่ขาด
  // ครั้งแรกของเครื่อง / ไม่มี cursor / แคชในเครื่องเคยเขียนไม่ลง → ดึงทั้งหมดเหมือนเดิม
  var CLOUD_EPOCH = '1970-01-01T00:00:00Z';
  var CLOUD_CURSOR_OVERLAP_MS = 120000; // ขอย้อนเผื่อ 2 นาที กันแถวที่บันทึกเสร็จช้ากว่าเวลาที่ประทับไว้
  function cloudMetaKey(){ return 'mvpwatch_cloudmeta_'+cloudSync.email; }
  function cloudReadCursor(){
    var meta = store(cloudMetaKey(), null);
    return (meta && meta.cursor) || {};
  }
  function cloudWriteCursor(stateObj){
    // แคชในเครื่องเคยเขียนไม่ลง (พื้นที่เบราว์เซอร์เต็ม) → ห้ามเชื่อแคช ลบ cursor ให้รอบหน้าดึงทั้งหมด
    if(cachePersistFailed){
      try{ localStorage.removeItem(cloudMetaKey()); }catch(e){}
      return;
    }
    stateObj = stateObj || {};
    function maxOf(k){ return (stateObj[k] && stateObj[k][1]) || CLOUD_EPOCH; }
    persist(cloudMetaKey(), { cursor: { merchant: maxOf('m'), farm: maxOf('f'), kv: maxOf('k') } });
  }
  function cloudSince(cursor){
    var t = Date.parse(cursor);
    return new Date((isNaN(t) ? 0 : t) - CLOUD_CURSOR_OVERLAP_MS).toISOString();
  }
  // PostgREST คืนทีละไม่เกิน 1000 แถว — ไล่ขอทีละหน้า (buildQuery ต้องสร้าง query ใหม่ทุกหน้า)
  function cloudPaged(buildQuery){
    var all = [];
    function page(from){
      return buildQuery().range(from, from+999).then(function(res){
        if(res.error) throw res.error;
        var rows = res.data || [];
        all = all.concat(rows);
        return rows.length===1000 ? page(from+1000) : all;
      });
    }
    return page(0);
  }
  function cloudFetchEntries(table){
    var userId = cloudSync.userId;
    return cloudPaged(function(){
      return supa.from(table).select('id, data').eq('user_id', userId)
        .order('ts', { ascending:true }).order('id', { ascending:true });
    });
  }
  function cloudFetchEntriesSince(table, cursor){
    var userId = cloudSync.userId;
    return cloudPaged(function(){
      return supa.from(table).select('id, data').eq('user_id', userId).gte('updated_at', cloudSince(cursor))
        .order('updated_at', { ascending:true }).order('id', { ascending:true });
    });
  }
  function cloudFetchIds(table){
    var userId = cloudSync.userId;
    return cloudPaged(function(){
      return supa.from(table).select('id').eq('user_id', userId).order('id', { ascending:true });
    }).then(function(rows){ return rows.map(function(r){ return r.id; }); });
  }
  function cloudFetchByIds(table, ids){
    var userId = cloudSync.userId;
    return Promise.all(cloudChunks(ids, 100).map(function(part){
      return supa.from(table).select('id, data').eq('user_id', userId).in('id', part).then(function(res){
        if(res.error) throw res.error;
        return res.data || [];
      });
    })).then(function(parts){ return [].concat.apply([], parts); });
  }
  function cloudRowsFromMap(map){
    return Object.keys(map).map(function(id){ return { id:id, data:map[id] }; });
  }
  // คืนค่า "ข้อมูลบนคลาวด์ทั้งหมด" ในรูปแบบเดียวกับการดึงเต็ม (แถวที่ไม่เปลี่ยนใช้ของในเครื่องแทน)
  // cloudApply จึงรวมข้อมูลด้วยกฎเดิมได้โดยไม่ต้องรู้ว่าดึงมาแบบไหน
  function cloudFetchAll(){
    var userId = cloudSync.userId;
    var firstSync = !store(cloudSyncedKey(), false);
    var cursor = cloudReadCursor();
    // อ่านสถานะก่อนตัวข้อมูล: ถ้ามีเครื่องอื่นเขียนแทรกระหว่างดึง รอบเช็คถัดไปจะเห็นว่าเปลี่ยนแล้วดึงใหม่
    return cloudFetchState().then(function(stateJson){
      var state = {};
      try{ state = JSON.parse(stateJson) || {}; }catch(e){}
      var setJobs = Object.keys(CLOUD_ENTRY_SETS).map(function(set){
        var cfg = CLOUD_ENTRY_SETS[set];
        if(firstSync || !cursor[set]) return cloudFetchEntries(cfg.table);
        var serverCount = state[cfg.stateKey] ? (Number(state[cfg.stateKey][0]) || 0) : 0;
        return cloudFetchEntriesSince(cfg.table, cursor[set]).then(function(changed){
          var ob = cloudSync.outbox[set];
          var map = cloudIndexById(cfg.get());
          changed.forEach(function(r){ if(r && r.id && r.data) map[r.id] = r.data; });
          var pending = Object.keys(ob.up).length + Object.keys(ob.del).length;
          if(!pending && Object.keys(map).length === serverCount) return cloudRowsFromMap(map);
          return cloudFetchIds(cfg.table).then(function(ids){
            var onServer = {};
            ids.forEach(function(id){ onServer[id] = true; });
            Object.keys(map).forEach(function(id){ if(!onServer[id] && !ob.up[id]) delete map[id]; });
            var missing = ids.filter(function(id){ return !map[id] && !ob.del[id]; });
            return cloudFetchByIds(cfg.table, missing).then(function(rows){
              rows.forEach(function(r){ if(r && r.id && r.data) map[r.id] = r.data; });
              return cloudRowsFromMap(map);
            });
          });
        });
      });
      var kvNames = Object.keys(CLOUD_KV);
      var kvCount = state.k ? (Number(state.k[0]) || 0) : 0;
      var kvJob;
      if(firstSync || !cursor.kv || kvCount < kvNames.length){
        kvJob = supa.from('user_app_data').select('key, value').eq('user_id', userId).then(function(res){
          if(res.error) throw res.error;
          return res.data || [];
        });
      } else {
        kvJob = supa.from('user_app_data').select('key, value').eq('user_id', userId).gte('updated_at', cloudSince(cursor.kv)).then(function(res){
          if(res.error) throw res.error;
          var changed = {};
          (res.data || []).forEach(function(r){ if(r && r.key) changed[r.key] = r; });
          // หัวข้อที่ไม่ได้เปลี่ยน = ค่าในเครื่องตอนนี้ตรงกับคลาวด์อยู่แล้ว
          return kvNames.map(function(name){ return changed[name] || { key:name, value: cloudClone(CLOUD_KV[name]()) }; });
        });
      }
      return Promise.all(setJobs.concat([kvJob])).then(function(r){
        return { state:stateJson, stateObj:state, merchant:r[0], farm:r[1], kv:r[2] };
      });
    });
  }

  // รวมข้อมูลคลาวด์กับของในเครื่อง: คลาวด์เป็นหลัก ยกเว้นของที่ยังค้างในคิวรอส่ง (ใช้ของในเครื่อง)
  // และถ้าเป็นการย้ายครั้งแรกของเครื่องนี้ รายการที่มีแต่ในเครื่องจะถูกเพิ่มขึ้นคลาวด์ด้วย
  function cloudApply(cloud){
    var ob = cloudSync.outbox;
    var firstSync = !store(cloudSyncedKey(), false);
    var values = {}, cloudJson = {}, migrated = 0;
    Object.keys(CLOUD_ENTRY_SETS).forEach(function(set){
      var cfg = CLOUD_ENTRY_SETS[set];
      var byId = {};
      cloudJson[set] = {};
      (cloud[set] || []).forEach(function(r){
        if(!r || !r.id || !r.data || typeof r.data!=='object') return;
        r.data.id = r.id;
        byId[r.id] = r.data;
        cloudJson[set][r.id] = JSON.stringify(r.data);
      });
      var local = cloudIndexById(cfg.get());
      if(firstSync){
        Object.keys(local).forEach(function(id){
          if(!byId[id]){ byId[id] = local[id]; ob[set].up[id] = true; migrated++; }
        });
      }
      Object.keys(ob[set].up).forEach(function(id){
        if(local[id]) byId[id] = local[id];
        else delete ob[set].up[id];
      });
      Object.keys(ob[set].del).forEach(function(id){ delete byId[id]; });
      values[cfg.name] = Object.keys(byId).map(function(id){ return byId[id]; })
        .sort(function(a, b){ return (Number(a.ts)||0) - (Number(b.ts)||0); });
    });
    var cloudKv = {};
    (cloud.kv || []).forEach(function(r){ if(r && r.key) cloudKv[r.key] = r.value; });
    Object.keys(CLOUD_KV).forEach(function(name){
      var inCloud = Object.prototype.hasOwnProperty.call(cloudKv, name);
      if(ob.kv[name] || !inCloud){
        values[name] = cloudClone(CLOUD_KV[name]());
        ob.kv[name] = true;
      } else if(firstSync && CLOUD_KV_MERGE_FIRST_SYNC[name]){
        values[name] = CLOUD_KV_MERGE_FIRST_SYNC[name](cloudKv[name], cloudClone(CLOUD_KV[name]()));
        if(JSON.stringify(values[name]) !== JSON.stringify(cloudKv[name])) ob.kv[name] = true;
      } else {
        values[name] = cloudKv[name];
      }
    });

    // โหลดผ่าน loadUserData ตัวเดิม เพื่อใช้กฎแปลงข้อมูลเก่า/ค่าเริ่มต้นชุดเดียวกันทั้งหมด
    var keepAnnouncements = App.rateAnnouncements, keepPendingItems = App.pendingItems;
    loadUserData(cloudSync.email, values);
    App.rateAnnouncements = keepAnnouncements;
    App.pendingItems = keepPendingItems;

    // loadUserData อาจแปลง/เติมค่าบางอย่าง → ส่งตัวที่แปลงแล้วขึ้นไปด้วย
    Object.keys(CLOUD_ENTRY_SETS).forEach(function(set){
      (CLOUD_ENTRY_SETS[set].get() || []).forEach(function(e){
        var cj = e && e.id ? cloudJson[set][e.id] : undefined;
        if(cj !== undefined && cj !== JSON.stringify(e)) ob[set].up[e.id] = true;
      });
    });
    Object.keys(CLOUD_KV).forEach(function(name){
      if(JSON.stringify(CLOUD_KV[name]()) !== JSON.stringify(values[name])) ob.kv[name] = true;
    });

    Object.keys(CLOUD_ENTRY_SETS).forEach(function(set){
      var cfg = CLOUD_ENTRY_SETS[set];
      persist(App.keys[cfg.name], cfg.get());
    });
    Object.keys(CLOUD_KV).forEach(function(name){ if(App.keys[name]) persist(App.keys[name], CLOUD_KV[name]()); });
    cloudResetSnapshots();
    persist(cloudSyncedKey(), true);
    cloudSaveOutbox();
    cloudSync.knownState = cloud.state;
    cloudSync.ready = true;
    return { firstSync:firstSync, migrated:migrated };
  }

  function cloudRefresh(opts){
    opts = opts || {};
    return cloudRun(function(){
      var userId = cloudSync.userId;
      return cloudFetchAll().then(function(cloud){
        if(cloudSync.userId !== userId) return;
        var before = opts.initial ? null : cloudFingerprint();
        var result = cloudApply(cloud);
        cloudWriteCursor(cloud.stateObj);
        if(result.migrated){
          toast(isExpiredAccount()
            ? 'พบประวัติเดิมในเครื่องนี้ '+fmtNum(result.migrated)+' รายการ — จะย้ายขึ้นคลาวด์ให้เมื่อต่ออายุแพ็กเกจ'
            : 'กำลังย้ายประวัติเดิมในเครื่องนี้ขึ้นคลาวด์ '+fmtNum(result.migrated)+' รายการ — ต่อไปเปิดจากเครื่องไหนก็เห็น');
        }
        if(!opts.initial && cloudFingerprint() !== before) renderAfterCloudRefresh();
        if(cloudHasFlushableWork()) cloudScheduleFlush(0);
      });
    });
  }
  // เช็คเบาๆ ว่ามีเครื่องอื่นแก้อะไรไหม (จำนวนแถว+เวลาแก้ล่าสุด) ถ้ามีค่อยดึงทั้งก้อน
  function cloudCheckForChanges(){
    if(!cloudSync.userId || App.isGuest) return;
    var now = Date.now();
    if(now - cloudSync.lastCheck < 10000) return;
    cloudSync.lastCheck = now;
    if(!cloudSync.ready){
      cloudRefresh({}).catch(function(err){ console.warn('cloud load retry', err); });
      return;
    }
    cloudRun(function(){
      return cloudFetchState().then(function(state){ return state !== cloudSync.knownState; });
    }).then(function(changed){
      if(changed) return cloudRefresh({});
    }).catch(function(err){ console.warn('cloud check', err); });
  }
  function renderAfterCloudRefresh(){
    var active = document.activeElement;
    function typingIn(sel){
      return !!(active && active.closest && /^(INPUT|SELECT|TEXTAREA)$/.test(active.tagName) && active.closest(sel));
    }
    if(!typingIn('#rateChips')) renderRateChips();
    renderTickerServerChips();
    renderTicker();
    renderMerchantServers();
    if(!typingIn('#mrExRateInput')) renderMrExchangeRate();
    if(!typingIn('#mrItemRows')) renderItemRows();
    renderMerchantHistory();
    renderMerchantSummary();
    renderMrChart();
    updateItemsRailBadge();
    if(!document.getElementById('view-items').hidden) renderItemsPage();
    if(!document.getElementById('view-farm').hidden){
      if(typingIn('#view-farm')){ renderFarmChart(); renderFarmHistory(); }
      else renderFarmPage();
    }
  }
  // เริ่มตอนล็อกอิน: โหลด+รวมข้อมูลจากคลาวด์ รอไม่เกิน 8 วิ — ช้า/ล่ม ใช้ของในเครื่องไปก่อน แล้วลองใหม่ทีหลัง
  function cloudBegin(user){
    cloudEnd();
    cloudSync.userId = user.id;
    cloudSync.email = user.email;
    cloudSync.outbox = cloudReadOutbox();
    cloudResetSnapshots();
    cloudSync.lastCheck = Date.now();
    var opts = { initial:true };
    var load = cloudRefresh(opts);
    return new Promise(function(resolve){
      var settled = false;
      var timer = setTimeout(function(){
        if(settled) return;
        settled = true;
        opts.initial = false; // โหลดเสร็จทีหลังเมื่อไหร่ ให้วาดหน้าใหม่เอง
        console.warn('cloud load slow — showing local data for now');
        resolve();
      }, 8000);
      load.then(function(){
        if(settled) return;
        settled = true; clearTimeout(timer); resolve();
      }, function(err){
        console.warn('cloud load failed — showing local data for now', err);
        Track.error('load', err);
        if(settled) return;
        settled = true; clearTimeout(timer); resolve();
      });
    });
  }
  function cloudEnd(){
    clearTimeout(cloudSync.flushTimer);
    cloudSync.userId = null;
    cloudSync.email = null;
    cloudSync.ready = false;
    cloudSync.outbox = null;
    cloudSync.snap = {};
    cloudSync.kvSnap = {};
    cloudSync.knownState = null;
    cloudSync.retryDelay = 0;
    cloudSync.failNotified = false;
  }
  document.addEventListener('visibilitychange', function(){ if(!document.hidden) cloudCheckForChanges(); });
  window.addEventListener('focus', cloudCheckForChanges);
  window.addEventListener('online', function(){
    cloudSync.lastCheck = 0;
    cloudCheckForChanges();
    if(cloudSync.ready) cloudScheduleFlush(0);
  });
  setInterval(function(){ if(!document.hidden) cloudCheckForChanges(); }, 60000);

  function saveTickerServers(){ persist(App.keys.tickerServers, App.tickerServers); cloudQueueKV('tickerServers'); }
  function saveTickerSelectedServers(){ persist(App.keys.tickerSelectedServers, App.tickerSelectedServers); cloudQueueKV('tickerSelectedServers'); }
  function saveLastRateUpdateTs(){ persist(App.keys.lastRateUpdateTs, App.lastRateUpdateTs); }

  // ---------- ประกาศ "รับ M" : กระดานร่วม เก็บใน Supabase ตาราง announcements ----------
  // RLS: สมาชิกที่ล็อกอินอ่านได้ทุกแถว แต่เขียน/แก้/ลบได้เฉพาะของตัวเอง
  // แปลงเป็นรูปทรงเดิมที่ทั้งไฟล์ใช้อยู่ ({serverId, buy, userName, userId, ts, expiresAt})
  // เพื่อไม่ต้องรื้อโค้ด render ทั้งหมด
  function mapAnnouncement(r){
    return {
      id: r.id,
      serverId: r.server_id,
      buy: r.buy==null ? null : Number(r.buy),
      userName: r.user_name,
      userId: r.user_id,
      facebookUrl: r.facebook_url || null,
      ts: new Date(r.created_at).getTime(),
      expiresAt: new Date(r.expires_at).getTime(),
      // ใช้แค่โชว์ในช่อง "ระยะเวลา" (ปิดแก้ไว้) ตอนกดแก้ไขประกาศ
      durationMs: new Date(r.expires_at).getTime() - new Date(r.created_at).getTime()
    };
  }
  function loadAnnouncements(){
    if(!App.session){ App.rateAnnouncements = []; return Promise.resolve(); }
    return supa.from('announcements').select('*')
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending:false })
      .then(function(res){
        // ตารางยังไม่ถูกสร้าง / เน็ตหลุด → ปล่อยกระดานว่างไว้ ไม่ทำให้หน้าพัง
        if(res.error){ console.warn('loadAnnouncements', res.error); return false; }
        App.rateAnnouncements = (res.data||[]).map(mapAnnouncement);
        return true;
      });
  }
  // โหลดใหม่แล้ววาดใหม่ทั้งแถบ — ใช้หลังลง/แก้/ลบประกาศ และตอน poll ตามรอบ
  function refreshAnnouncements(){
    return loadAnnouncements().then(function(ok){
      recomputeServerRatesFromAnnouncements();
      renderRateChips();
      renderTicker();
      return ok;
    });
  }
  // เช็คก่อนค่อยดึง: ถามแค่ "ประกาศที่ยังไม่หมดอายุมีกี่อัน + แก้ล่าสุดเมื่อไหร่" (announcements_state)
  // ถ้าเหมือนรอบก่อนก็ไม่ต้องโหลดทั้งกระดาน — และปกติเช็คเฉพาะตอนอยู่หน้าบัญชีนักลงทุน
  // (กระดาน + การ์ดราคารับ M อยู่หน้านี้หน้าเดียว) force = ข้ามทั้งสองเงื่อนไข ใช้หลังลง/แก้/ลบประกาศเอง
  var announcementsKnownState = null;
  var announcementsCheckRun = null;
  function refreshAnnouncementsIfChanged(force){
    if(!App.session) return Promise.resolve();
    if(!force && document.getElementById('view-home').hidden) return Promise.resolve();
    if(announcementsCheckRun){
      // กำลังเช็คอยู่: ปกติใช้ผลรอบนั้นเลย / แบบ force ต้องรอให้จบแล้วเช็คใหม่ (รอบเดิมอาจอ่านก่อนเราลงประกาศ)
      return force ? announcementsCheckRun.then(function(){ return refreshAnnouncementsIfChanged(true); }) : announcementsCheckRun;
    }
    var run = supa.rpc('announcements_state').then(function(res){
      if(res.error) return refreshAnnouncements(); // ยังไม่มีตัวเช็คบนคลาวด์ → ดึงทั้งกระดานแบบเดิม
      var state = JSON.stringify(res.data);
      if(!force && state === announcementsKnownState) return;
      return refreshAnnouncements().then(function(ok){ if(ok) announcementsKnownState = state; });
    }, function(){ return refreshAnnouncements(); });
    announcementsCheckRun = run.then(function(){ announcementsCheckRun = null; }, function(){ announcementsCheckRun = null; });
    return announcementsCheckRun;
  }

  // The "current buy price" per server tracks what players are actually posting
  // in the ประกาศ รับ M board, refreshed the moment an announcement changes —
  // average of each still-active announcement's รับ price. A server with no
  // active announcements keeps whatever price it last had (its admin-set default).
  function recomputeServerRatesFromAnnouncements(){
    var now = Date.now();
    SERVER_RATES.forEach(function(sv){
      var live = App.rateAnnouncements.filter(function(a){ return a.serverId===sv.id && a.buy!=null && (a.expiresAt==null || a.expiresAt>now); });
      if(live.length){
        var latest = live.reduce(function(a,b){ return b.ts>a.ts ? b : a; });
        sv.buy = latest.buy;
      }
    });
    App.lastRateUpdateTs = now;
    saveLastRateUpdateTs();
  }
  function saveMerchantServers(){ persist(App.keys.merchantServers, App.merchantServers); cloudQueueKV('merchantServers'); }
  function saveMerchantItems(){ persist(App.keys.merchantItems, App.merchantItems); cloudQueueKV('merchantItems'); }
  function saveCurrentServer(){ persist(App.keys.currentServer, App.currentServerId); cloudQueueKV('currentServer'); }
  function saveRateSlots(){ persist(App.keys.rateSlots, App.rateSlots); cloudQueueKV('rateSlots'); }

  // Keeps the "รายการซื้อ-ขาย" server list mirroring whatever servers are pinned as
  // rate-ticker chips — chips are now the only place servers get added/removed from.
  function syncMerchantServersWithRateSlots(){
    App.rateSlots.forEach(function(id){
      if(App.merchantServers.indexOf(id)===-1) App.merchantServers.push(id);
    });
    App.merchantServers = App.merchantServers.filter(function(id){ return App.rateSlots.indexOf(id)!==-1; });
    if(App.merchantServers.indexOf(App.currentServerId)===-1) App.currentServerId = App.merchantServers[0] || null;
    saveMerchantServers();
    saveCurrentServer();
  }

  // Keeps the "ประกาศ รับ M" server filter chips as an exact mirror of the pinned
  // rate-ticker chips (duplicates in rateSlots collapse to one filter chip).
  function syncTickerServersWithRateSlots(){
    var unique = [];
    App.rateSlots.forEach(function(id){ if(unique.indexOf(id)===-1) unique.push(id); });
    App.tickerServers = unique;
    saveTickerServers();
    // newly pinned servers start selected; ones no longer pinned drop out of the filter too
    unique.forEach(function(id){
      if(App.tickerSelectedServers.indexOf(id)===-1) App.tickerSelectedServers.push(id);
    });
    App.tickerSelectedServers = App.tickerSelectedServers.filter(function(id){ return unique.indexOf(id)!==-1; });
    saveTickerSelectedServers();
  }
  function saveMerchantLog(){ persist(App.keys.merchantLog, App.merchantLog); cloudQueueEntries('merchant'); }
  function saveMerchantExchangeRates(){ persist(App.keys.merchantExRate, App.merchantExchangeRates); cloudQueueKV('merchantExRate'); }
  function saveItemWarehouseStock(){ persist(App.keys.itemWarehouseStock, App.itemWarehouseStock); cloudQueueKV('itemWarehouseStock'); }
  function saveItemLineClaimedQty(){ persist(App.keys.itemLineClaimedQty, App.itemLineClaimedQty); cloudQueueKV('itemLineClaimedQty'); }
  // delta>0 when a line is dropped into a warehouse tier, delta<0 when explicitly
  // undone back to pending. Selling from stock (or restoring a sale) never calls this
  // — that only moves physical qty, it doesn't change what's "claimed" off pending.
  function addClaimedQty(serverId, lineId, delta){
    if(!lineId || !delta) return;
    if(!App.itemLineClaimedQty[serverId]) App.itemLineClaimedQty[serverId] = {};
    var next = (App.itemLineClaimedQty[serverId][lineId]||0) + delta;
    if(next <= 0.0000001) delete App.itemLineClaimedQty[serverId][lineId];
    else App.itemLineClaimedQty[serverId][lineId] = next;
  }

  function saveItemsServer(){ persist(App.keys.itemsServer, App.itemsServerId); cloudQueueKV('itemsServer'); }
  // หน้าจับเวลาบอสไม่แยกตามเซิร์ฟเวอร์อีกต่อไป — บอส/ประวัติทั้งหมดของบัญชี (หรือของหัวปาร์ตี้ที่กำลังดู)
  // รวมเป็นรายการเดียว ใช้ค่าคงที่นี้แทนการให้ผู้ใช้เลือกเซิร์ฟเวอร์ ส่ง RPC/query ที่ยังต้องการ server_id
  // อยู่ (schema เดิมไม่ได้แก้) เพื่อไม่ต้องแตะ RPC ฝั่ง Supabase เลย
  var TIMERS_SERVER = '-';
  // รายการบอสของผู้ใช้ + เวลาที่จับอยู่ (App.db/App.active) sync กับตาราง user_bosses
  // ใน Supabase โดยตรง แทนการเซฟเป็น blob เดียวใน localStorage แบบเดิม เพื่อให้ข้าม
  // อุปกรณ์ได้ — ฟังก์ชันด้านล่างแทนที่ saveDB()/saveActive() เดิม
  // กำลังดูข้อมูลบอสของใครอยู่ — ของตัวเอง (null) หรือของหัวปาร์ตี้ที่เลือกไว้
  // (App.viewingHostId) ทุกฟังก์ชันด้านล่างอ่าน/เขียนผ่านตัวนี้แทน App.session.id ตรงๆ
  // เพื่อให้สลับไปดู/แก้ข้อมูลของปาร์ตี้ได้ — RLS ฝั่ง Supabase เป็นคนอนุญาต/บล็อกจริง

  // Custom Boss adapter: the existing roster, timers and styles remain the renderer.
  var customCatalog = [], customCatalogHost = null, customBusy = false;
  function visibleCustomCatalog(){return CustomAPI && App.session && !App.isGuest && customCatalogHost===activeOwnerId() ? customCatalog : [];}
  function isCustomBossId(id){ return !!CustomAPI && String(id).indexOf('custom:')===0; }
  function customRef(id){ return {custom:true, id:id, rawId:String(id).slice(7)}; }
  async function loadCustomBosses(){
    if(!CustomAPI) return;
    var host=activeOwnerId();
    try {
      var results=await Promise.all([
        CustomAPI.result(supa.from('custom_bosses').select('*').eq('owner_id',host).is('archived_at',null)),
        CustomAPI.result(supa.from('custom_boss_timers').select('*').eq('owner_id',host).eq('server_id',TIMERS_SERVER))
      ]);
      var definitions=await Promise.all(results[0].map(async function(b){
        var images=await Promise.allSettled([CustomAPI.imageUrl(b.image_path),CustomAPI.imageUrl(b.map_image_path)]);
        return {id:'custom:'+b.id,rawId:b.id,custom:true,ownerId:b.owner_id,name:b.name,minutes:b.respawn_minutes,
          loc:b.map_location||'',map:'custom',glyph:'',items:b.items||[],record:b,
          imageUrl:images[0].status==='fulfilled'?images[0].value:null,
          mapImageUrl:images[1].status==='fulfilled'?images[1].value:null};
      }));
      if(activeOwnerId()!==host) return;
      customCatalog=definitions;customCatalogHost=host;
      App.db=App.db.filter(function(b){return !b.custom;});
      results[1].forEach(function(t){
        var b=definitions.find(function(b){return b.rawId===t.custom_boss_id;}); if(!b)return;
        App.db.push(b);
        if(t.target_time)App.active[b.id]={targetTime:new Date(t.target_time).getTime(),startedBy:t.started_by};
        if(t.marker_x!=null && t.marker_y!=null)App.markers[b.id]={x:Number(t.marker_x),y:Number(t.marker_y)};
      });
    }catch(error){customCatalog=[];toast('โหลด Custom Boss ไม่สำเร็จ: '+error.message);}
  }
  async function customReload(){
    await Promise.all([loadUserBosses(),loadKills()]); renderRoster();renderStats();
    if(!document.getElementById('historyOverlay').hidden)renderHistory();
  }
  async function customResult(promise){
    try {var data=await promise;await customReload();bossNotifyChanged();return {data:data,error:null};}
    catch(error){await customReload();return {error:error};}
  }
  async function customTask(work,done){
    if(customBusy)return;customBusy=true;
    try {await work();if(done)done();await customReload();bossNotifyChanged();toast('บันทึก Custom Boss แล้ว');}
    catch(error){toast(error.message||'บันทึกไม่สำเร็จ');}
    finally{customBusy=false;}
  }
  function customNode(tag,text){var node=document.createElement(tag);if(text!=null)node.textContent=text;return node;}
  function openCustomBossModal(boss){
    if(!CustomAPI || !App.session || App.isGuest){toast('กรุณาเข้าสู่ระบบ');return;}
    if(activeOwnerId()!==App.session.id){toast('เจ้าของปาร์ตี้เท่านั้นที่เพิ่มหรือแก้ไขบอสได้');return;}
    var record=boss?boss.record:null,uploads={},saving=false;
    var dialog=customNode('dialog'),form=customNode('form');dialog.className='custom-boss-dialog';
    var title=customNode('h3',boss?'แก้ไขบอส':'เพิ่มบอส');form.append(title);
    function field(label,type,value){var wrap=customNode('label',label),input=customNode('input');input.type=type;input.value=value||'';wrap.append(input);form.append(wrap);return input;}
    var name=field('ชื่อบอส *','text',record&&record.name);name.required=true;name.maxLength=120;
    var minutes=field('Respawn (นาที) *','number',record?record.respawn_minutes:120);minutes.required=true;minutes.min=1;minutes.max=2147483647;minutes.step=1;
    var map=field('Map (ไม่บังคับ)','text',record&&record.map_location);map.maxLength=120;
    var bossImage=field('รูปบอส (ไม่บังคับ)','file'),mapImage=field('รูปแผนที่ (ไม่บังคับ)','file');
    bossImage.accept=mapImage.accept='image/png,image/jpeg,image/webp,image/gif,.png,.jpg,.jpeg,.webp,.gif';
    form.append(customNode('small','PNG / JPEG / WebP / GIF ไม่เกิน 1 MiB ต่อรูป'));
    var drops=customNode('div');form.append(customNode('label','ไอเทมที่ดรอป'),drops);
    function addDrop(value){
      if(drops.children.length>=50)return;
      var row=customNode('div'),input=customNode('input'),remove=customNode('button','×');row.className='custom-drop-row';
      input.value=value||'';input.placeholder='ชื่อไอเทม';input.maxLength=120;input.setAttribute('aria-label','ชื่อไอเทมที่ดรอป');
      remove.type='button';remove.className='btn btn-ghost btn-sm';remove.setAttribute('aria-label','ลบช่องไอเทม');remove.onclick=function(){row.remove();};row.append(input,remove);drops.append(row);
    }
    (record&&record.items.length?record.items:['']).forEach(addDrop);
    var add=customNode('button','+ เพิ่มไอเทม');add.type='button';add.className='btn btn-ghost btn-sm';add.onclick=function(){addDrop('');};form.append(add);
    var error=customNode('p');error.setAttribute('role','alert');form.append(error);
    var footer=customNode('div');footer.className='custom-modal-actions';
    var cancel=customNode('button','ยกเลิก'),submit=customNode('button',boss?'บันทึก':'เพิ่มบอส');cancel.type='button';submit.type='submit';cancel.className='btn btn-ghost';submit.className='btn btn-primary';
    cancel.onclick=function(){if(!saving)dialog.close();};footer.append(cancel,submit);form.append(footer);dialog.append(form);document.body.append(dialog);
    dialog.addEventListener('cancel',function(e){if(saving)e.preventDefault();});
    dialog.addEventListener('close',function(){dialog.remove();customReload();},{once:true});
    form.onsubmit=async function(e){
      e.preventDefault();if(saving||customBusy)return;
      var fields={name:name.value.trim(),respawn_minutes:Number(minutes.value),map_location:map.value.trim()||null,
        items:Array.from(new Set(Array.from(drops.querySelectorAll('input')).map(function(i){return i.value.trim();}).filter(Boolean)))};
      if(!fields.name||!Number.isInteger(fields.respawn_minutes)||fields.respawn_minutes<1)return;
      saving=customBusy=true;submit.disabled=cancel.disabled=true;error.textContent='';
      try {
        CustomAPI.validateImage(bossImage.files[0]);CustomAPI.validateImage(mapImage.files[0]);
        if(!record){
          var id=await CustomAPI.rpc('create_custom_boss',{p_name:fields.name,p_respawn_minutes:fields.respawn_minutes,p_server_id:TIMERS_SERVER,p_map_location:fields.map_location,p_items:fields.items});
          record={id:id};submit.textContent='บันทึก / ลองแนบรูปอีกครั้ง';title.textContent='แก้ไขบอสที่สร้างแล้ว';
          record=await CustomAPI.definition(id);
        }
        if(!record.updated_at)record=await CustomAPI.definition(record.id);
        for(var pair of [[bossImage,'image_path'],[mapImage,'map_image_path']]){
          var file=pair[0].files[0],key=pair[1];
          if(file&&(!uploads[key]||uploads[key].file!==file))uploads[key]={file:file,path:await CustomAPI.upload(activeOwnerId(),record.id,file)};
          fields[key]=uploads[key]?uploads[key].path:record[key]||null;
        }
        await CustomAPI.update(record,fields);await customReload();bossNotifyChanged();dialog.close();toast('บันทึก Custom Boss แล้ว');
      }catch(err){error.textContent=(record?'บอสยังอยู่ ไม่ต้องสร้างใหม่ — ':'')+err.message;}
      finally{saving=customBusy=false;submit.disabled=cancel.disabled=false;}
    };
    dialog.showModal();
  }

  function activeOwnerId(){ return App.viewingHostId || App.session.id; }
  // แต่ละคนเป็นสมาชิก active ได้แค่ 1 ปาร์ตี้ในเวลาเดียวกัน (บังคับด้วย unique index ฝั่ง DB)
  // ฟังก์ชันนี้เช็คจากฐานข้อมูลจริงว่าตอนนี้ฉันอยู่ปาร์ตี้ใคร แล้วอัปเดต App.viewingHostId ให้ตรงเสมอ
  function resolvePartyContext(){
    return withSkewRetry(function(){ return supa.from('party_members').select('host_id, profiles!host_id(display_name)').eq('member_id', App.session.id).is('removed_at', null).maybeSingle(); }).then(function(res){
      if(res.error){ console.error('resolvePartyContext', res.error); App.viewingHostId = null; App.viewingHostName = null; return; }
      if(res.data){
        App.viewingHostId = res.data.host_id;
        App.viewingHostName = (res.data.profiles && res.data.profiles.display_name) || '-';
      } else {
        App.viewingHostId = null;
        App.viewingHostName = null;
      }
    });
  }
  function loadUserBosses(){
    if(!App.session || !App.session.id){ App.db = []; App.active = {}; App.markers = {}; return Promise.resolve(); }
    return withSkewRetry(function(){ return supa.from('user_bosses').select('boss_id, target_time, started_by, marker_x, marker_y, bosses(*)').eq('user_id', activeOwnerId()); }).then(function(res){
      if(res.error){ console.error('loadUserBosses', res.error); return; }
      App.db = (res.data||[]).map(function(r){
        var b = r.bosses || {};
        return { id:b.id, name:b.name, glyph:b.glyph, imageUrl:b.image_url, map:b.map, mapImageUrl:b.map_image_url, loc:b.map_location, minutes:b.respawn_minutes, items:b.items||[] };
      });
      App.active = {};
      App.markers = {};
      (res.data||[]).forEach(function(r){
        if(r.marker_x!=null && r.marker_y!=null){
          App.markers[r.boss_id] = { x:r.marker_x, y:r.marker_y };
        }
        if(r.target_time){
          App.active[r.boss_id] = {
            targetTime: new Date(r.target_time).getTime(),
            startedBy: r.started_by
          };
        }
      });
      bossLiveSync();
      return loadCustomBosses();
    });
  }
  function supaAddBoss(bossId){
    if(isCustomBossId(bossId)) return customResult(CustomAPI.add(customRef(bossId), activeOwnerId(), TIMERS_SERVER));
    return supa.rpc('add_boss_capped', { p_owner: activeOwnerId(), p_boss_id: bossId, p_server_id: TIMERS_SERVER }).then(bossAfterWrite);
  }
  function supaRemoveBoss(bossId){
    if(isCustomBossId(bossId)) return customResult(CustomAPI.remove(customRef(bossId), activeOwnerId(), TIMERS_SERVER));
    return supa.from('user_bosses').delete().eq('user_id', activeOwnerId()).eq('boss_id', bossId).then(bossAfterWrite);
  }
  function supaSetBossTime(bossId, targetTime, startedBy){
    if(isCustomBossId(bossId)) return customResult(CustomAPI.setTime(customRef(bossId), activeOwnerId(), TIMERS_SERVER, targetTime==null ? null : new Date(targetTime).toISOString(), startedBy));
    // จุดปักหมุด (marker) เป็นตำแหน่งที่เจอบอสบนแมพ ไม่ผูกกับรอบจับเวลา จึงไม่ล้าง
    // ทิ้งตรงนี้ — แก้/ล้างหมุดแยกต่างหากผ่าน supaSetBossMarker เท่านั้น
    return supa.from('user_bosses').update({
      target_time: targetTime==null ? null : new Date(targetTime).toISOString(),
      started_by: targetTime==null ? null : (startedBy||null)
    }).eq('user_id', activeOwnerId()).eq('boss_id', bossId).then(bossAfterWrite);
  }
  function supaSetBossMarker(bossId, x, y){
    if(isCustomBossId(bossId)) return customResult(CustomAPI.marker(customRef(bossId), activeOwnerId(), TIMERS_SERVER, Number(x), Number(y)));
    return supa.from('user_bosses').update({ marker_x:x, marker_y:y }).eq('user_id', activeOwnerId()).eq('boss_id', bossId).then(bossAfterWrite);
  }
  // ประวัติการฆ่า+ไอเทมของปาร์ตี้ที่กำลังดูอยู่ — ผูกกับหัวปาร์ตี้เหมือน user_bosses
  function loadKills(){
    if(!App.session || !App.session.id){ App.kills = []; return Promise.resolve(); }
    return Promise.all([loadKillsForActiveOwner(), loadMyLifetimeShare()]);
  }
  var KILL_SELECT_COLS = 'id, host_id, boss_id, boss_name, killed_at, killed_by, server_id, profiles!killed_by(display_name), kill_items(id, name, shared, shared_with, sold_amount, sold_currency, sold_at, kept_at)';
  function fetchKillsFor(hostId){
    return withSkewRetry(function(){ return supa.from('kills').select(KILL_SELECT_COLS)
      .eq('host_id', hostId).order('killed_at', { ascending:false }).order('created_at', { ascending:false }); });
  }
  // ทุกก้อนที่เคยมีชื่อเราอยู่ใน "ผู้รับส่วนแบ่ง" ของไอเทมที่เคยขาย ไม่ว่าจะเป็นของปาร์ตี้ไหนก็ตาม
  // (แม้ออกจากปาร์ตี้นั้นไปแล้ว — RLS เปิดให้อ่านได้เฉพาะรายการที่มีเอี่ยว ดู migration
  // 20260922000900_kill_share_visible_after_leave.sql) ต้องดึงมารวมในประวัติด้วย ไม่ใช่แค่ไปโผล่
  // ในยอดรวม "ส่วนแบ่งของฉัน" เฉยๆ
  function fetchSharedKills(){
    if(!App.session || !App.session.id) return Promise.resolve({ data:[] });
    return supa.from('kill_items').select('kill_id').contains('shared_with', [App.session.id]).then(function(res){
      if(res.error){ console.error('fetchSharedKills lookup', res.error); return { data:[] }; }
      var ids = Array.from(new Set((res.data||[]).map(function(r){ return r.kill_id; })));
      if(!ids.length) return { data:[] };
      return withSkewRetry(function(){ return supa.from('kills').select(KILL_SELECT_COLS)
        .in('id', ids).order('killed_at', { ascending:false }).order('created_at', { ascending:false }); });
    });
  }
  // สมาชิกปาร์ตี้ (กำลังดูของหัวปาร์ตี้คนอื่นอยู่) ต้องยังเห็นประวัติส่วนตัวของตัวเอง (ก่อนเข้าปาร์ตี้)
  // รวมอยู่ในรายการเดียวกับของปาร์ตี้ด้วย เรียงตามเวลาปนกันไปเลย ไม่แยกเป็นคนละชุด — หัวปาร์ตี้เองไม่ต้อง
  // ดึงซ้ำ เพราะ activeOwnerId() ก็คือตัวเองอยู่แล้ว
  function loadKillsForActiveOwner(){
    var owner = activeOwnerId();
    var jobs = [fetchKillsFor(owner)];
    if(App.viewingHostId && App.session && App.session.id) jobs.push(fetchKillsFor(App.session.id));
    if(App.session && App.session.id) jobs.push(fetchSharedKills());
    return Promise.all(jobs).then(function(results){
      var rows = [], seen = {};
      results.forEach(function(res){
        if(res.error){ console.error('loadKills', res.error); return; }
        (res.data||[]).forEach(function(k){ if(!seen[k.id]){ seen[k.id] = true; rows.push(k); } });
      });
      rows.sort(function(a,b){ return new Date(b.killed_at) - new Date(a.killed_at); });
      App.kills = rows.map(function(k){
        return { id:k.id, bossId:k.boss_id, bossName:k.boss_name, ts:new Date(k.killed_at).getTime(), serverId:k.server_id || null,
          hostId:k.host_id || null,
          killedById:k.killed_by || null,
          killedBy:(k.profiles && k.profiles.display_name) || null,
          // เรียงชื่อไอเทมในรอบเดียวกันให้คงที่ — ไม่งั้นหลังแก้ไขแถวจะสลับที่กัน (DB ไม่รับประกันลำดับ)
          items:(k.kill_items||[]).map(function(i){
            return { id:i.id, name:i.name, sharedWith:i.shared_with||[], soldAmount:i.sold_amount==null?null:Number(i.sold_amount), soldCurrency:i.sold_currency||'zeny', soldAt:i.sold_at, keptAt:i.kept_at||null };
          }).sort(function(a,b){ return a.name.localeCompare(b.name); }) };
      });
    });
  }
  // "ส่วนแบ่งของฉัน" บนการ์ดสถิติ = ยอดสะสมตลอดชีพ ไม่ใช่แค่ของปาร์ตี้ที่กำลังดูอยู่ — ดึงจาก
  // kill_items ตรงๆ ไม่กรอง host_id เลย (RLS เป็นคนคุมว่าเห็นแถวไหนได้บ้าง: ของตัวเอง, ของปาร์ตี้
  // ที่อยู่อยู่ตอนนี้, และของปาร์ตี้เก่าที่เคยได้ส่วนแบ่งแต่ออกไปแล้ว — ดู migration
  // 20260922000900_kill_share_visible_after_leave.sql) แล้วกรองเอาเฉพาะแถวที่ตัวเองมีชื่ออยู่ใน
  // shared_with ฝั่งนี้อีกที
  function loadMyLifetimeShare(){
    if(!App.session || !App.session.id){ App.myLifetimeShare = {zeny:0,baht:0,count:0}; return Promise.resolve(); }
    return withSkewRetry(function(){ return supa.from('kill_items').select('sold_amount, sold_currency, shared_with').not('sold_amount','is',null); }).then(function(res){
      if(res.error){ console.error('loadMyLifetimeShare', res.error); return; }
      var mine = {zeny:0, baht:0}, count = 0;
      (res.data||[]).forEach(function(r){
        if((r.shared_with||[]).indexOf(App.session.id)===-1) return;
        count++;
        mine[r.sold_currency] += Number(r.sold_amount) / r.shared_with.length;
      });
      App.myLifetimeShare = { zeny:mine.zeny, baht:mine.baht, count:count };
    });
  }
  // ---------- จับเวลาบอส: อัปเดตสดระหว่างสมาชิกปาร์ตี้ / หลายเครื่อง ----------
  // ช่องทางหลัก = Supabase Realtime Broadcast ห้อง "gum100-party-<id หัวปาร์ตี้>": ใครบันทึกอะไรสำเร็จ
  // ส่งแค่สัญญาณ "changed" (ไม่มีข้อมูลในข้อความ) คนอื่นในห้องได้ยินแล้วโหลดใหม่ — จะเห็นอะไรยังคุมด้วย RLS
  // ต่อห้องเฉพาะตอนเปิดหน้าจับเวลาบอส ออกจากหน้าแล้วตัดทิ้ง (ไม่กินโควต้าคนต่อพร้อมกันของ Realtime)
  // ตัวสำรอง = boss_page_state() (จำนวนแถว + เวลาแก้ล่าสุด) เช็คทุก 30 วิ, ตอนกลับมาที่แท็บ, ตอนต่อห้องติด
  // เผื่อสายหลุดหรือพลาดสัญญาณ — ถ้าไม่เปลี่ยนก็ไม่โหลดอะไร
  var bossLive = { channel:null, hostId:null, joined:false, knownState:null, stateHost:null, reloadTimer:null, reloadWhenIdle:false, lastCheck:0 };

  function bossPageOpen(){ return !!App.session && !App.isGuest && !document.getElementById('view-timers').hidden; }
  function bossLiveSync(){
    var hostId = bossPageOpen() ? activeOwnerId() : null;
    if(bossLive.hostId === hostId) return;
    bossLiveStop();
    if(!hostId) return;
    var ch = supa.channel('gum100-party-'+hostId, { config: { broadcast: { self:false } } });
    ch.on('broadcast', { event:'changed' }, function(){ bossScheduleReload(); });
    bossLive.channel = ch;
    bossLive.hostId = hostId;
    ch.subscribe(function(status){
      if(bossLive.channel !== ch) return;
      bossLive.joined = status === 'SUBSCRIBED';
      // ต่อติด (ครั้งแรก หรือหลังสายหลุด) → เช็คว่าระหว่างที่ไม่ได้ฟังอยู่ มีใครแก้อะไรไปไหม
      if(status === 'SUBSCRIBED') bossCheckForChanges(true);
    });
  }
  function bossLiveStop(){
    clearTimeout(bossLive.reloadTimer);
    if(bossLive.channel){ try{ supa.removeChannel(bossLive.channel); }catch(e){} }
    bossLive.channel = null;
    bossLive.hostId = null;
    bossLive.joined = false;
  }
  // เรียกหลังบันทึกสำเร็จ: บอกสมาชิกคนอื่นในปาร์ตี้ (และเครื่องอื่นของเราเอง) ให้โหลดใหม่
  function bossNotifyChanged(){
    if(bossLive.channel && bossLive.joined && bossLive.hostId === activeOwnerId()){
      var sent = bossLive.channel.send({ type:'broadcast', event:'changed', payload:{} });
      if(sent && sent.then) sent.then(null, function(){});
    }
    // ของที่เราเพิ่งแก้เอง ไม่ต้องนับเป็น "ของใหม่" ตอนเช็คสำรองรอบถัดไป
    setTimeout(bossRefreshKnownState, 1500);
  }
  function bossAfterWrite(res){
    if(res && !res.error) bossNotifyChanged();
    return res;
  }
  function bossFetchState(hostId){
    if(CustomAPI) return CustomAPI.pageState(hostId);
    return supa.rpc('boss_page_state', { p_host: hostId }).then(function(res){
      if(res.error) throw res.error;
      return JSON.stringify(res.data);
    });
  }
  function bossRefreshKnownState(){
    if(!App.session || App.isGuest) return;
    var host = activeOwnerId();
    bossFetchState(host).then(function(state){
      if(activeOwnerId() !== host) return;
      bossLive.knownState = state;
      bossLive.stateHost = host;
    }, function(){});
  }
  function bossCheckForChanges(force){
    if(!bossPageOpen() || document.hidden) return;
    var now = Date.now();
    if(!force && now - bossLive.lastCheck < 10000) return;
    bossLive.lastCheck = now;
    var host = activeOwnerId();
    bossFetchState(host).then(function(state){
      if(activeOwnerId() !== host) return;
      if(bossLive.stateHost !== host || bossLive.knownState === null || state !== bossLive.knownState) bossScheduleReload();
    }, function(err){ console.warn('boss_page_state', err); });
  }
  function bossScheduleReload(){
    clearTimeout(bossLive.reloadTimer);
    bossLive.reloadTimer = setTimeout(bossReloadNow, 300);
  }
  function bossTypingInPage(){
    var a = document.activeElement;
    return !!(a && /^(INPUT|TEXTAREA|SELECT)$/.test(a.tagName) && a.closest && a.closest('#view-timers, #historyOverlay'));
  }
  function bossReloadNow(){
    if(!App.session || App.isGuest) return;
    // กำลังพิมพ์ในหน้าจับเวลาบอส (เช่นกรอกเวลาเอง) → รอพิมพ์เสร็จก่อนค่อยวาดใหม่ ไม่งั้นช่องที่พิมพ์อยู่หาย
    if(bossTypingInPage()){ bossLive.reloadWhenIdle = true; return; }
    var host = activeOwnerId();
    // อ่านสถานะก่อนตัวข้อมูล: ถ้ามีคนแก้แทรกระหว่างโหลด รอบเช็คถัดไปจะเห็นว่าไม่ตรงแล้วโหลดใหม่
    return bossFetchState(host).then(function(state){
      bossLive.knownState = state;
      bossLive.stateHost = host;
    }, function(){}).then(function(){
      return Promise.all([ loadUserBosses(), loadKills() ]);
    }).then(function(){
      if(activeOwnerId() !== host) return;
      renderRoster();
      renderStats();
      updatePartyPanelSummary();
      if(!document.getElementById('historyOverlay').hidden) renderHistory();
    });
  }
  document.addEventListener('focusout', function(){
    if(!bossLive.reloadWhenIdle) return;
    setTimeout(function(){
      if(!bossLive.reloadWhenIdle || bossTypingInPage()) return;
      bossLive.reloadWhenIdle = false;
      bossScheduleReload();
    }, 50);
  });
  document.addEventListener('visibilitychange', function(){ if(!document.hidden) bossCheckForChanges(); });
  window.addEventListener('focus', function(){ bossCheckForChanges(); });
  setInterval(function(){ if(!document.hidden) bossCheckForChanges(); }, 30000);
  function historyAvatarHtml(bossId, bossName){
    var b = CATALOG.filter(function(c){ return String(c.id)===String(bossId); })[0];
    return '<div class="log-avatar">'+(b ? bossAvatarHtml(b) : escapeHtml((bossName||'').charAt(0)))+'</div>';
  }
  function saveFarmCostItems(){ persist(App.keys.farmCostItems, App.farmCostItems); cloudQueueKV('farmCostItems'); }
  function saveFarmLog(){ persist(App.keys.farmLog, App.farmLog); cloudQueueEntries('farm'); }
  function saveFarmServer(){ persist(App.keys.farmServer, App.farmServerId); cloudQueueKV('farmServer'); }
  function saveFarmExchangeRates(){ persist(App.keys.farmExRate, App.farmExchangeRates); cloudQueueKV('farmExRate'); }
  function saveFarmMapNames(){ persist(App.keys.farmMapNames, App.farmMapNames); cloudQueueKV('farmMapNames'); }

  // ---------- audio ----------
  var actx = null;
  var BOSS_SOUND_SETTINGS_KEY = 'gum100:bossSoundSettings';
  var bossSound = (function(){
    var saved = store(BOSS_SOUND_SETTINGS_KEY, {});
    var volume = Math.max(0, Math.min(100, Number(saved.volume)));
    if(!isFinite(volume)) volume = 80;
    var lastVolume = Math.max(1, Math.min(100, Number(saved.lastVolume)));
    if(!isFinite(lastVolume)) lastVolume = volume > 0 ? volume : 80;
    return { enabled:saved.enabled !== false && volume > 0, volume:volume, lastVolume:lastVolume };
  })();
  function saveBossSound(){ persist(BOSS_SOUND_SETTINGS_KEY, bossSound); }
  function bossSoundAudible(){ return bossSound.enabled && bossSound.volume > 0; }
  function bossSoundIcon(muted){
    return muted
      ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M11 5 6 9H3v6h3l5 4z"/><path d="m19 9-6 6M13 9l6 6"/></svg>'
      : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M11 5 6 9H3v6h3l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13"/></svg>';
  }
  function renderBossSoundControl(){
    var toggle = document.getElementById('bossSoundToggle');
    var enabled = document.getElementById('bossSoundEnable');
    var volume = document.getElementById('bossSoundVolume');
    var output = document.getElementById('bossSoundVolumeOutput');
    if(!toggle || !enabled || !volume || !output) return;
    var muted = !bossSoundAudible();
    toggle.innerHTML = bossSoundIcon(muted);
    toggle.classList.toggle('is-muted', muted);
    toggle.setAttribute('aria-pressed', String(!muted));
    toggle.setAttribute('aria-label', muted ? 'เปิดเสียงแจ้งเตือน' : 'ปิดเสียงแจ้งเตือน');
    toggle.title = muted ? 'ปิดเสียงอยู่' : 'เสียงแจ้งเตือน';
    enabled.checked = !muted;
    volume.value = bossSound.volume;
    output.textContent = bossSound.volume+'%';
  }
  function closeBossSoundPopover(){
    var popover = document.getElementById('bossSoundPopover');
    var menu = document.getElementById('bossSoundMenuToggle');
    if(popover) popover.hidden = true;
    if(menu) menu.setAttribute('aria-expanded','false');
  }
  function initBossSoundControl(){
    var control = document.getElementById('bossSoundControl');
    var toggle = document.getElementById('bossSoundToggle');
    var menu = document.getElementById('bossSoundMenuToggle');
    var popover = document.getElementById('bossSoundPopover');
    var enabled = document.getElementById('bossSoundEnable');
    var volume = document.getElementById('bossSoundVolume');
    var bellPreview = document.getElementById('bossSoundBellPreview');
    if(!control || !toggle || !menu || !popover || !enabled || !volume || !bellPreview) return;
    renderBossSoundControl();
    toggle.addEventListener('click', function(){
      if(bossSoundAudible()) bossSound.enabled = false;
      else { bossSound.enabled = true; if(bossSound.volume <= 0) bossSound.volume = bossSound.lastVolume || 80; }
      saveBossSound(); renderBossSoundControl();
    });
    menu.addEventListener('click', function(){
      var opening = popover.hidden;
      popover.hidden = !opening;
      menu.setAttribute('aria-expanded', String(opening));
    });
    enabled.addEventListener('change', function(){
      bossSound.enabled = enabled.checked;
      if(bossSound.enabled && bossSound.volume <= 0) bossSound.volume = bossSound.lastVolume || 80;
      saveBossSound(); renderBossSoundControl();
    });
    volume.addEventListener('input', function(){
      bossSound.volume = Math.max(0, Math.min(100, Number(volume.value)));
      if(bossSound.volume > 0){ bossSound.lastVolume = bossSound.volume; bossSound.enabled = true; }
      else bossSound.enabled = false;
      saveBossSound(); renderBossSoundControl();
    });
    bellPreview.addEventListener('click', function(){ playBellPreview(); });
    document.addEventListener('click', function(e){ if(!e.target.closest('#bossSoundControl')) closeBossSoundPopover(); });
    document.addEventListener('keydown', function(e){ if(e.key==='Escape') closeBossSoundPopover(); });
  }
  function unlockAudio(){
    try{
      actx = actx || new (window.AudioContext||window.webkitAudioContext)();
      if(actx.state==='suspended') actx.resume().catch(function(){});
    }catch(e){}
  }
  document.addEventListener('pointerdown', unlockAudio, {once:true,passive:true});
  document.addEventListener('keydown', unlockAudio, {once:true});
  function beep(){
    try{
      if(!bossSoundAudible()) return;
      playBellSound(3);
    }catch(e){}
  }
  function playBellSound(seconds){
    try{
      var volume = Math.max(0.02, bossSound.volume/100), repeats = Math.max(1, Math.ceil(seconds/.72));
      actx = actx || new (window.AudioContext||window.webkitAudioContext)();
      if(actx.state==='suspended') actx.resume().catch(function(){});
      for(var hit=0;hit<repeats;hit++) [1318.5, 1661.2, 2093].forEach(function(freq, index){
        var o = actx.createOscillator(), g = actx.createGain(), start = actx.currentTime + hit*.72 + index*.035;
        o.type = 'sine'; o.frequency.value = freq;
        g.gain.setValueAtTime(0.0001, start);
        g.gain.exponentialRampToValueAtTime(0.075*volume/(index+1), start+.015);
        g.gain.exponentialRampToValueAtTime(0.0001, start+.62);
        o.connect(g); g.connect(actx.destination); o.start(start); o.stop(start+.67);
      });
    }catch(e){}
  }
  function playBellPreview(){ playBellSound(1); }
  initBossSoundControl();

  // ---------- map svg ----------
  function mapSVG(type){
    if(type==='grid'){
      var cells = '';
      var colors = ['#5b6a8b','#5a8b6f','#8b5a5a','#5b7c9b','#8b7c5a'];
      for(var r=0;r<3;r++){ for(var c=0;c<4;c++){
        var col = colors[(r*4+c)%colors.length];
        cells += '<rect x="'+(c*25)+'" y="'+(r*33.3)+'" width="23" height="31" rx="2" fill="'+col+'" opacity="0.55"/>';
      }}
      return '<svg viewBox="0 0 100 100" preserveAspectRatio="none"><rect width="100" height="100" fill="var(--surface-2)"/>'+cells+'<g stroke="#c34fd2" stroke-width="0.8" opacity="0.55">'+
        '<line x1="0" y1="33.3" x2="100" y2="33.3"/><line x1="0" y1="66.6" x2="100" y2="66.6"/>'+
        '<line x1="25" y1="0" x2="25" y2="100"/><line x1="50" y1="0" x2="50" y2="100"/><line x1="75" y1="0" x2="75" y2="100"/></g></svg>';
    }
    if(type==='cave'){
      return '<svg viewBox="0 0 100 100" preserveAspectRatio="none"><rect width="100" height="100" fill="var(--surface-2)"/>'+
        '<path d="M10 20 L35 20 L35 45 L65 45 L65 20 L90 20 L90 55 L55 55 L55 80 L20 80 L20 55 L10 55 Z" fill="none" stroke="#7c8aa3" stroke-width="6" stroke-linejoin="round"/></svg>';
    }
    return '<svg viewBox="0 0 100 100" preserveAspectRatio="none"><rect width="100" height="100" fill="var(--surface-2)"/>'+
      '<rect x="6" y="6" width="88" height="88" fill="none" stroke="#6b7086" stroke-width="1.2"/></svg>';
  }

  // ---------- state helpers ----------
  function timerState(remaining){
    // ใช้ targetTime จริงเสมอ: เมื่อถึงเวลาเกิดแล้วให้คงสถานะแดงจนกว่าจะฆ่าบอสใหม่
    if(remaining<=0) return 'overdue';
    if(remaining<=300000) return 'warning';
    return 'normal';
  }

  function itemChip(boss, it){
    var selected = (App.pendingItems[boss.id]||[]).indexOf(it) !== -1;
    var url = itemImageUrl(it);
    var box = url
      ? '<span class="dot has-img"><img src="'+url.replace(/"/g,'&quot;')+'" alt=""></span>'
      : '<span class="dot">'+(selected?'✓':'')+'</span>';
    return '<button type="button" class="item-chip'+(selected?' selected':'')+'" data-boss="'+boss.id+'" data-item="'+escapeHtml(it)+'">'+
      box+escapeHtml(it)+'</button>';
  }

  // ---------- rendering ----------
  function renderRoster(){
    var guestView = !App.session || !App.session.id;
    if(guestView && !App.isGuest) return;
    // ผู้เยี่ยมชม (ยังไม่ล็อกอิน): โชว์การ์ด Baphomet 1 ใบเป็นตัวอย่าง — กดอะไรก็เด้ง login (guestBlock) ไม่ใช่ข้อมูลของใครและไม่เก็บอะไรไว้
    var guestDemo = guestView ? (CATALOG.filter(function(c){ return c.id==='baphomet'; })[0] || null) : null;
    var root = document.getElementById('roster');
    if(guestView && !guestDemo){ root.innerHTML = ''; return; }
    var now = Date.now();
    var rows = guestDemo ? [{ boss:guestDemo, act:null }] : App.db.map(function(boss){ return { boss:boss, act: App.active[boss.id] || null }; });

    var activeRows = rows.filter(function(r){ return r.act; }).sort(function(a,b){ return a.act.targetTime - b.act.targetTime; });
    var idleRows = rows.filter(function(r){ return !r.act; });
    var ordered = activeRows.concat(idleRows);

    if(!ordered.length){
      root.innerHTML = '<p class="empty-note">ยังไม่มีบอสในรายการ — ค้นหาจากช่องด้านบนแล้วกด "+ เพิ่ม"</p>';
      return;
    }

    root.innerHTML = ordered.map(function(r, idx){
      var boss = r.boss, act = r.act;
      var rankHtml = act ? '<div class="bc-rank">'+(activeRows.indexOf(r)+1)+'</div>' : '<div class="bc-dot"></div>';
      var remaining = act ? act.targetTime - now : null;
      var st = act ? timerState(remaining) : null;
      var timeHtml, subHtml, delayHtml = '';
      if(act){
        timeHtml = '<div class="bc-time mono state-'+st+'" data-time>'+(st==='overdue' ? fmtDuration(remaining).replace(/^\+/,'') : fmtDuration(remaining))+'</div>';
        var approxMin = Math.max(0, Math.ceil(remaining/60000));
        subHtml = '<div class="bc-time-sub" data-sub>'+(remaining>0 ? 'อีก ~'+approxMin+' นาที' : 'เกิดมาแล้ว')+'</div>';
        // ปุ่มนี้โผล่ทุกครั้งที่มีการจับเวลาอยู่ (ไม่ใช่แค่ตอนแก้เวลาตายเอง) เพราะเป็น
        // ปุ่ม "เคลียร์เวลา" ทั่วไป ไว้ล้างรอบที่กำลังจับอยู่ กลับไปเป็นยังไม่ได้ฆ่า
        delayHtml = '<button type="button" class="bc-delay-pill" data-action="clear-time" title="ล้างเวลาที่จับอยู่ กลับไปเป็นยังไม่ได้ฆ่า">⏱ เคลียร์เวลา</button>';
      } else {
        timeHtml = '<div class="bc-time idle">—</div>';
        subHtml = '<div class="bc-time-sub">ยังไม่ได้ฆ่า</div>';
      }
      var killedByHtml = (act && act.startedBy) ? '<div class="bc-killedby">🏹 ฆ่าโดย '+escapeHtml(act.startedBy)+'</div>' : '';
      var metaLine ='เกิดใหม่ทุก '+boss.minutes+' นาที • '+escapeHtml(boss.loc) + (act ? ' • เกิดเวลา '+fmtClock(act.targetTime) : '');

      var shake = act && st==='overdue' && remaining <= 0 && remaining >= -600000;
      return '<div class="boss-card'+(st==='warning'?' state-warning':'')+(st==='overdue'?' state-spawn':'')+(shake?' state-shake':'')+'" data-boss="'+boss.id+'">'+
        '<div class="bc-row">'+
          '<div class="bc-left">'+
            rankHtml+
            '<div class="bc-avatar">'+bossAvatarHtml(boss)+'</div>'+
            '<div class="bc-main"><div class="bc-title">'+escapeHtml(boss.name)+(boss.custom ? ' <span class="custom-boss-badge">Custom</span>' : '')+'</div><div class="bc-sub">'+metaLine+'</div>'+killedByHtml+'</div>'+
          '</div>'+
          '<div class="bc-map" data-map>'+bossMapHtml(boss)+(App.markers[boss.id] ? '<div class="bc-pin" style="left:'+App.markers[boss.id].x+'%;top:'+App.markers[boss.id].y+'%"></div>' : '')+'</div>'+
          '<div class="bc-right">'+
          '<div class="bc-time-block">'+timeHtml+subHtml+'</div>'+
          '<input class="bc-input" type="text" inputmode="decimal" placeholder="เวลาตาย" data-minutes title="ระบุเวลาที่บอสตายจริง เช่น 14.35 หรือ 1435 (ถ้าไม่ตรงกับตอนนี้)">'+
          '<div>'+
          '<button type="button" class="bc-kill-btn bc-kill-btn-img" data-action="kill" title="ตายแล้ว" aria-label="ตายแล้ว"><img src="data:image/png;base64,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" alt="ตายแล้ว"></button>'+delayHtml+'</div>'+
          '<button class="bc-close" data-action="remove" title="เอาออกจากรายการ">'+
            '<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px"><path d="M18 6L6 18M6 6l12 12"/></svg></button>'+
          '</div>'+
        '</div>'+
        '<div class="bc-items"><span class="bc-items-label">ไอเทมที่ดรอป</span>'+boss.items.map(function(it){ return itemChip(boss, it); }).join('')+'</div>'+
        (boss.custom && boss.ownerId===App.session.id && activeOwnerId()===App.session.id ? '<div class="custom-boss-actions"><button class="btn btn-ghost btn-sm" data-action="custom-edit">แก้ไข</button><button class="btn btn-ghost btn-sm" data-action="custom-archive">ลบออก</button></div>' : '')+
      '</div>';
    }).join('') + (guestDemo ? '<p style="margin:.7rem 0 0;text-align:center;font-size:.82rem;color:var(--text-dim)">ตัวอย่างการ์ดบอส — เข้าสู่ระบบเพื่อเริ่มจับเวลาบอสของคุณ</p>' : '');
  }

  function tickTimers(){
    if(!App.session || !App.session.id) return;
    document.querySelectorAll('.boss-card').forEach(function(card){
      var bossId = card.dataset.boss;
      var act = App.active[bossId];
      if(!act) return;
      var remaining = act.targetTime - Date.now();
      var st = timerState(remaining);
      var timeEl = card.querySelector('[data-time]');
      var subEl = card.querySelector('[data-sub]');
      if(timeEl){ timeEl.className = 'bc-time mono state-'+st; timeEl.textContent = st==='overdue' ? fmtDuration(remaining).replace(/^\+/,'') : fmtDuration(remaining); }
      if(subEl){ subEl.textContent = remaining>0 ? 'อีก ~'+Math.max(0,Math.ceil(remaining/60000))+' นาที' : 'เกิดมาแล้ว'; }
      card.classList.toggle('state-warning', st==='warning');
      card.classList.toggle('state-spawn', st==='overdue');
      card.classList.toggle('state-shake', st==='overdue' && remaining <= 0 && remaining >= -600000);
      card.classList.remove('state-critical','state-overdue');

      if(st==='warning' && !fired.warn[bossId]){
        fired.warn[bossId] = true;
        card.classList.add('shake');
        setTimeout(function(){ card.classList.remove('shake'); }, 550);
      }
      // แจ้งเสียงหนึ่งครั้งเมื่อเข้าสู่ช่วง 3 นาทีก่อนบอสเกิด โดยไม่เปลี่ยนสี warning ของ UI
      if(remaining>0 && remaining<=180000 && !fired.threeMin[bossId]){
        fired.threeMin[bossId] = true;
        beep();
      }
      if(st==='normal'){ fired.warn[bossId]=false; fired.threeMin[bossId]=false; }
    });
  }

  function computeStats(){
    var totalKills = App.kills.length;
    var totalItems = App.kills.reduce(function(s,l){ return s + l.items.length; }, 0);
    var allLootRows = [];
    App.kills.forEach(function(k){ k.items.forEach(function(it){ allLootRows.push({ kill:k, item:it }); }); });
    var loot = computeLootTotals(allLootRows);
    return { totalKills:totalKills, totalItems:totalItems, soldCount:loot.soldCount, sold:loot.sold, mineCount:loot.mineCount, mine:loot.mine };
  }

  function statAmountLines(amount){
    return '<span>'+fmtNum(Math.round(amount.zeny || 0))+' Z</span><span>'+fmtNum(Math.round(amount.baht || 0))+' ฿</span>';
  }

  function renderStats(){
    if(!App.session || !App.session.id) return;
    var s = computeStats();
    document.getElementById('statTotalKills').textContent = s.totalKills;
    document.getElementById('statTotalItems').textContent = s.totalItems;
    document.getElementById('statItemsSold').textContent = s.soldCount;
    document.getElementById('statItemsSoldAmount').innerHTML = statAmountLines(s.sold);
    // ยอดสะสมตลอดชีพ (ทุกปาร์ตี้ที่เคยเข้าร่วม รวมปาร์ตี้ที่ออกไปแล้ว) — ไม่ใช่แค่ของ App.kills
    // ที่สโคปตามบัญชี/ปาร์ตี้ที่กำลังดูอยู่ (ดู loadMyLifetimeShare)
    document.getElementById('statMyShare').textContent = App.myLifetimeShare.count;
    document.getElementById('statMyShareAmount').innerHTML = statAmountLines(App.myLifetimeShare);
    // รูปล่าสุดในการ์ด: การ์ด "ฆ่า" = บอสที่กดฆ่าล่าสุด, การ์ด "ไอเทม" = ไอเทมชิ้นล่าสุด — มีรูปในหลังบ้านถึงจะโชว์ ไม่มีก็ซ่อนช่อง
    var sorted = App.kills.slice().sort(function(a,b){ return b.ts-a.ts; });
    setStatThumb('thumbTotalKills', latestBossThumb(sorted));
    setStatThumb('thumbTotalItems', latestItemThumb(sorted));
  }
  function latestBossThumb(kills){
    if(!kills.length) return null;
    var k = kills[0];
    var b = CATALOG.filter(function(c){ return String(c.id)===String(k.bossId); })[0];
    return (b && b.imageUrl) ? { url:b.imageUrl, title:k.bossName } : null;
  }
  function latestItemThumb(kills){
    var k = kills.filter(function(x){ return x.items.length>0; })[0];
    if(!k) return null;
    for(var i=0;i<k.items.length;i++){
      var url = itemImageUrl(k.items[i].name);
      if(url) return { url:url, title:k.items[i].name };
    }
    return null;
  }
  function setStatThumb(id, t){
    var el = document.getElementById(id);
    var q = function(s){ return String(s).replace(/"/g,'&quot;'); };
    el.hidden = !t;
    el.innerHTML = t ? '<img src="'+q(t.url)+'" alt="'+q(t.title)+'" title="ล่าสุด: '+q(t.title)+'">' : '';
  }

  function renderGuestChip(){
    document.getElementById('userMenu').hidden = true;
    document.getElementById('guestAuthButtons').hidden = false;
    document.getElementById('pointsValue').textContent = '0';
  }
  function userPackageChipInfo(profile){
    var now = Date.now();
    var rows = settingsPackageRows(profile, now);
    var plan = rows[0] || {name:'ฟรี',expiry:0};
    // บัญชีรุ่นเดิมที่ยังมีวันหมดอายุรวม แต่ไม่มีข้อมูลแพ็กเกจแยก
    var legacyExpiry = new Date((profile && profile.expires_at)||0).getTime() || 0;
    if(!plan.expiry && legacyExpiry > now && !isNoExpiry(legacyExpiry)) plan = {name:'แพ็กเกจสมาชิก',expiry:legacyExpiry};
    if(!plan.expiry && profile && (profile.role==='admin' || profile.legacy_unlimited)) plan = {name:'4 in 1 — ครบทั้ง 4 ระบบ',expiry:0};
    // มีหลายแพ็กเกจพร้อมกัน (เช่น จับเวลาบอส + 1 in 1): ป้ายโชว์ตัวแรก + "+N" และรายชื่อทั้งหมดอยู่ใน tooltip
    if(plan===rows[0] && plan.expiry && rows.length>1){
      plan = {name:plan.name, expiry:plan.expiry, extra:rows.length-1,
        all:rows.map(function(r){ return r.name+' — หมดอายุ '+fmtDate(r.expiry); })};
    }
    return plan;
  }
  function packageTimeText(expiry){
    if(!expiry) return 'ใช้งานได้ไม่จำกัด';
    var remaining = Math.max(0, expiry-Date.now());
    return 'เหลือ '+Math.floor(remaining/86400000)+' วัน '+(Math.floor(remaining/3600000)%24)+' ชม.';
  }
  function renderUser(){
    renderSettingsPackages();
    if(App.isGuest){ renderGuestChip(); return; }
    document.getElementById('userMenu').hidden = false;
    document.getElementById('guestAuthButtons').hidden = true;
    var acc = App.profile;
    if(!acc) return;
    var name = acc.display_name || '';
    document.getElementById('userAvatar').textContent = name.trim().charAt(0).toUpperCase();
    document.getElementById('userName').textContent = name;
    document.getElementById('pointsValue').textContent = fmtNum(acc.points||0);
    var pill = document.getElementById('userPill');
    var expiry = document.getElementById('userExpiry');
    var packageInfo = userPackageChipInfo(acc);
    var remaining = packageInfo.expiry ? packageInfo.expiry-Date.now() : 0;
    var soon = packageInfo.expiry && remaining <= 7*86400000;
    pill.textContent = (packageInfo.expiry ? packageInfo.name : (packageInfo.name==='ฟรี' ? 'แพ็กเกจฟรี' : packageInfo.name)) + (packageInfo.extra ? ' +'+packageInfo.extra : '');
    pill.title = packageInfo.all ? packageInfo.all.join('\n') : '';
    pill.className = 'membership-pill '+(soon?'soon':packageInfo.expiry?'ok':'neutral');
    expiry.textContent = packageInfo.expiry ? packageTimeText(packageInfo.expiry) : 'ใช้งานได้ไม่จำกัด';
    expiry.className = 'membership-time'+(soon?' soon':'');
    renderExpiryState();
  }

  // โทเค็นที่เพิ่งต่ออายุอาจถูกเซิร์ฟเวอร์ปฏิเสธชั่วคราว (นาฬิกาเหลื่อมกันไม่กี่วินาที → PGRST303)
  // ลองใหม่อีก 1 ครั้งหลังรอสั้นๆ กันข้อมูลหลักโหลดไม่ขึ้นตอนเปิดแอป
  function withSkewRetry(run){
    return run().then(function(res){
      if(res && res.error && res.error.code==='PGRST303'){
        return new Promise(function(r){ setTimeout(r, 1500); }).then(run);
      }
      return res;
    });
  }
  var PROFILE_COLS = 'display_name, points, role, expires_at, username, birth_date, servers, server_quota, facebook_url, legacy_unlimited, plan_bundle_expires_at, plan_timers_expires_at';
  // อ่านโปรไฟล์ตัวเองผ่านฟังก์ชัน my_profile — ฐานข้อมูลไม่ให้สมาชิกปาร์ตี้อ่านวันเกิด/แต้มของกันได้แล้ว
  // (ตาราง profiles เปิดอ่านได้แค่ id กับ display_name) จึงอ่านคอลัมน์ส่วนตัวตรงๆ ไม่ได้อีก
  function refreshProfile(){
    return withSkewRetry(function(){ return supa.rpc('my_profile'); }).then(function(res){
      // ยังไม่ได้รัน SQL สร้างฟังก์ชัน → ใช้วิธีอ่านตารางตรงแบบเดิมไปก่อน (กันหน้าเว็บพังระหว่างอัปเดต)
      if(res.error && /my_profile|PGRST202/.test((res.error.message||'')+' '+(res.error.code||''))){
        console.warn('ยังไม่มีฟังก์ชัน my_profile — อ่านโปรไฟล์แบบเดิมไปก่อน', res.error);
        return refreshProfileLegacy();
      }
      if(res.error || !res.data){ console.error('refreshProfile', res.error); return; }
      return applyProfile(res.data);
    });
  }
  function refreshProfileLegacy(){
    return withSkewRetry(function(){ return supa.from('profiles').select(PROFILE_COLS).eq('id', App.session.id).single(); }).then(function(res){
      // กันกรณีที่ยังไม่ได้รัน SQL เพิ่มคอลัมน์ใหม่ๆ — ถ้าไม่ดักไว้ โปรไฟล์จะโหลดไม่ได้เลย
      // และทั้งแอพจะพัง ถอยไปใช้คอลัมน์ชุดเดิมทีละคอลัมน์แทน
      if(res.error && PROFILE_COLS.indexOf('facebook_url')!==-1 && /facebook_url/.test(res.error.message||'')){
        console.warn('profiles.facebook_url ยังไม่มีในฐานข้อมูล — ข้ามไปก่อน', res.error);
        PROFILE_COLS = PROFILE_COLS.replace(', facebook_url', '');
        return refreshProfileLegacy();
      }
      if(res.error && PROFILE_COLS.indexOf('server_quota')!==-1 && /server_quota/.test(res.error.message||'')){
        console.warn('profiles.server_quota ยังไม่มีในฐานข้อมูล — ใช้โควต้าเริ่มต้น 1 เซิร์ฟไปก่อน', res.error);
        PROFILE_COLS = PROFILE_COLS.replace(', server_quota', '');
        return refreshProfileLegacy();
      }
      if(res.error && PROFILE_COLS.indexOf('legacy_unlimited')!==-1 && /legacy_unlimited|plan_bundle_expires_at|plan_timers_expires_at/.test(res.error.message||'')){
        console.warn('คอลัมน์สิทธิ์แพ็กเกจใหม่ยังไม่มีในฐานข้อมูล — ถือว่าไม่จำกัดสิทธิ์ไปก่อน', res.error);
        PROFILE_COLS = PROFILE_COLS.replace(', legacy_unlimited, plan_bundle_expires_at, plan_timers_expires_at', '');
        return refreshProfileLegacy();
      }
      if(res.error){ console.error('refreshProfile', res.error); return; }
      return applyProfile(res.data);
    });
  }
  function applyProfile(data){
      App.profile = data;
      document.getElementById('railAdminBtn').hidden = App.profile.role !== 'admin';
      var packageProfile = App.profile;
      packageProfile.feature_expiries = {};
      return supa.from('package_feature_entitlements').select('feature,expires_at').eq('user_id', App.session.id).then(function(entitlements){
        if(App.profile !== packageProfile) return;
        // Missing/unavailable scoped entitlement data never grants additional rights.
        if(!entitlements.error) (entitlements.data||[]).forEach(function(e){
          if(e.feature==='farm' || e.feature==='accountItems') packageProfile.feature_expiries[e.feature]=e.expires_at;
        });
        renderUser();
      }).catch(function(){ if(App.profile===packageProfile) renderUser(); });
  }

  function renderHistory(){
    var list = document.getElementById('historyList');
    var today = todayKey(Date.now());
    // สมาชิกปาร์ตี้ดูประวัติย้อนหลังได้ไม่จำกัดเสมอ ไม่ว่าตัวเองจะมีแพ็กเกจไหม (สิทธิ์ดูมาจากการเป็น
    // สมาชิกของปาร์ตี้นั้นโดยตรง) — แต่แก้ไข/ลบยังคุมแยกอีกชั้นด้วย isFreePartyMember() ใน lootRowHtml
    var timersAllowed = hasTimersPlan() || !!App.viewingHostId;
    var todayOnlyBox = document.getElementById('todayOnly');
    todayOnlyBox.disabled = !timersAllowed;
    todayOnlyBox.title = timersAllowed ? '' : 'บัญชีฟรีดูประวัติได้แค่วันนี้ — สมัครแพ็กเกจ "จับเวลาบอส" เพื่อดูย้อนหลังทั้งหมด';
    var onlyToday = todayOnlyBox.checked || !timersAllowed;
    var entries = App.kills.filter(function(l){ return !onlyToday || todayKey(l.ts)===today; })
                          .slice().sort(function(a,b){ return b.ts-a.ts; });
    document.getElementById('htabKills').className = App.historyTab==='kills' ? 'active' : '';
    document.getElementById('htabItems').className = App.historyTab==='items' ? 'active' : '';
    document.getElementById('htabBoss').className = App.historyTab==='boss' ? 'active' : '';
    document.getElementById('historyDeleteAll').hidden = !App.kills.length || isFreePartyMember();
    if(App.historyTab==='items'){ renderLootView(list, entries.filter(function(l){ return l.items.length>0; })); return; }
    if(App.historyTab==='boss'){ renderBossView(list, entries); return; }
    if(!entries.length){ list.innerHTML = '<p class="empty-note">ไม่มีข้อมูลในช่วงนี้</p>'; return; }
    list.innerHTML = entries.map(function(l){
      // รายการของปาร์ตี้อื่นที่เคยได้ส่วนแบ่งไว้แต่ไม่ได้อยู่แล้ว (ดึงมาโชว์ผ่าน fetchSharedKills) หรือ
      // เป็นสมาชิกฟรีของปาร์ตี้ปัจจุบัน (isFreePartyMember) ลบไม่ได้
      var writable = l.hostId===App.session.id || (l.hostId===activeOwnerId() && !isFreePartyMember());
      var delBtn = writable ? '<button type="button" class="hist-del" data-del-kill="'+l.id+'" title="ลบรายการนี้">✕</button>' : '';
      return '<div class="log-row">'+historyAvatarHtml(l.bossId, l.bossName)+'<div class="log-body">'+
        '<div class="hist-head"><div class="when">'+fmtDateTime(l.ts)+(l.killedBy ? ' · '+escapeHtml(l.killedBy) : '')+'</div>'+
          delBtn+'</div>'+
        '<div class="boss">'+escapeHtml(l.bossName)+'</div>'+
        '<div class="chip-row">'+(l.items.length ? l.items.map(function(it){ return '<span class="chip">'+itemIconHtml(it.name,'item-ic')+escapeHtml(it.name)+'</span>'; }).join('') : '<span class="chip">ไม่มีไอเทม</span>')+'</div></div></div>';
    }).join('');
  }

  // ---------- รอบ 2: ของที่ได้ — หารกับปาร์ตี้ / บันทึกขาย / ส่วนแบ่ง ----------
  var lootFilter = 'all';
  var lootEditing = null;
  function loadPartyRoster(){
    var hostId = activeOwnerId();
    return Promise.all([
      supa.from('profiles').select('id, display_name').eq('id', hostId).maybeSingle(),
      supa.from('party_members').select('member_id, profiles!member_id(display_name)').eq('host_id', hostId).is('removed_at', null)
    ]).then(function(rs){
      if(rs[0].error) console.error('loadPartyRoster host', rs[0].error);
      if(rs[1].error) console.error('loadPartyRoster members', rs[1].error);
      var host = rs[0].data;
      App.partyRoster = [{ id:hostId, name:(host && host.display_name) || '-' }].concat((rs[1].data||[]).map(function(m){
        return { id:m.member_id, name:(m.profiles && m.profiles.display_name) || 'ไม่ทราบชื่อ' };
      }));
    });
  }
  // คนที่เคยติ๊กหาร (อยู่ใน shared_with ของไอเทมที่เคยขาย) แต่ออกจากปาร์ตี้ไปแล้ว — ไม่อยู่ใน
  // partyRoster ปัจจุบัน จึงต้องดึงชื่อแยกมาเก็บไว้เอง เพื่อโชว์เป็นชิปล็อก (ดู lootRowHtml)
  // App.departedSharerNames จริงๆ คือ "แผนที่ชื่อของทุกคนที่เคยหารของ" ไม่ใช่แค่คนที่ออกปาร์ตี้ไปแล้ว —
  // ตั้งต้นด้วยชื่อจาก partyRoster ก่อน (ฟรี ไม่ต้อง query) แล้วดึงเพิ่มเฉพาะ id ที่ยังไม่มีชื่อ เหตุผลที่
  // ต้องทำแบบนี้แทนที่จะเช็คแค่ "อยู่ใน partyRoster ปัจจุบันไหม": lootRowHtml คำนวณ roster ของแต่ละแถวแยก
  // ต่างหาก (ว่างเปล่าถ้าแถวนั้น read-only เช่น สมาชิกฟรี) ถ้าคนนั้นถูกนับว่า "known" จาก partyRoster
  // ตรงนี้ แต่แถวนั้นไม่ได้โชว์ผ่าน roster จริง ก็จะไม่มีชื่อให้ใช้เลย ต้องมีชื่อสำรองไว้ในแผนที่นี้เสมอ
  function loadDepartedSharerNames(){
    var names = {}; (App.partyRoster||[]).forEach(function(p){ names[p.id] = p.name; });
    var missing = {};
    App.kills.forEach(function(k){ k.items.forEach(function(it){
      (it.sharedWith||[]).forEach(function(id){ if(!names[id]) missing[id] = true; });
    }); });
    var ids = Object.keys(missing);
    if(!ids.length){ App.departedSharerNames = names; return Promise.resolve(); }
    return supa.from('profiles').select('id, display_name').in('id', ids).then(function(res){
      if(res.error){ console.error('loadDepartedSharerNames', res.error); App.departedSharerNames = names; return; }
      (res.data||[]).forEach(function(p){ names[p.id] = p.display_name || 'ไม่ทราบชื่อ'; });
      App.departedSharerNames = names;
    });
  }
  function lootRows(entries, applyFilter){
    var rows = [];
    entries.forEach(function(k){ k.items.forEach(function(it){ rows.push({ kill:k, item:it }); }); });
    // "ยังไม่ขาย" = ของที่ยังค้างตัดสินใจจริงๆ ไม่นับของที่กด "เก็บไว้" แล้ว
    if(applyFilter && lootFilter==='unsold') rows = rows.filter(function(r){ return r.item.soldAmount==null && !r.item.keptAt; });
    if(applyFilter && lootFilter==='sold') rows = rows.filter(function(r){ return r.item.soldAmount!=null; });
    if(applyFilter && lootFilter==='kept') rows = rows.filter(function(r){ return !!r.item.keptAt; });
    // "ทั้งหมด" = ของทุกชิ้นยกเว้นที่กด "เก็บไว้" แล้ว (ย้ายไปอยู่แท็บ "เก็บไว้" แทน ไม่ปนกัน)
    if(applyFilter && lootFilter==='all') rows = rows.filter(function(r){ return !r.item.keptAt; });
    return rows;
  }
  function currencyLabel(c){ return c==='baht' ? 'บ' : 'z'; }
  // ยอดขาย+ส่วนแบ่งของฉัน คิดจากไอเทมทั้งชุดที่ส่งมา (rows) — ใช้ทั้งในสรุปประวัติการล่า
  // และการ์ดสถิติหน้าจับเวลาบอส (computeStats ส่ง App.kills ทั้งหมดเข้ามา ไม่กรองตามวัน)
  function computeLootTotals(rows){
    var sold = { zeny:0, baht:0 }, mine = { zeny:0, baht:0 }, soldCount = 0, mineCount = 0;
    rows.forEach(function(r){
      var it = r.item;
      if(it.soldAmount==null) return;
      soldCount++;
      sold[it.soldCurrency] += it.soldAmount;
      if(it.sharedWith.indexOf(App.session.id)!==-1){
        mineCount++;
        mine[it.soldCurrency] += it.soldAmount / it.sharedWith.length;
      }
    });
    return { sold:sold, mine:mine, soldCount:soldCount, mineCount:mineCount };
  }
  function lootPairText(o){ var p=[]; if(o.zeny) p.push(fmtNum(Math.round(o.zeny))+' z'); if(o.baht) p.push(fmtNum(Math.round(o.baht))+' บ'); return p.length ? p.join(' · ') : '0'; }
  function lootSummaryHtml(rows){
    var t = computeLootTotals(rows);
    return '<div class="loot-summary">'+
      '<div><span class="lbl">ได้ของทั้งหมด</span><b>'+rows.length+' ชิ้น</b></div>'+
      '<div><span class="lbl">ขายแล้ว '+t.soldCount+' ชิ้น</span><b>'+lootPairText(t.sold)+'</b></div>'+
      '<div><span class="lbl">ส่วนแบ่งของฉัน</span><b>'+lootPairText(t.mine)+'</b></div>'+
    '</div>';
  }
  function lootRowHtml(r){
    var k = r.kill, it = r.item;
    // แก้ไข/ลบ/ติ๊กหารได้เฉพาะรายการที่ยังมีสิทธิ์เขียนจริง (ตรงกับเงื่อนไข RLS ฝั่ง DB: เจ้าของ หรือ
    // สมาชิกปัจจุบันของปาร์ตี้นั้นที่มีแพ็กเกจจับเวลาบอส) — ของตัวเองเขียนได้เสมอ, ของปาร์ตี้ปัจจุบัน
    // เขียนได้ถ้าไม่ใช่ "สมาชิกฟรี" (isFreePartyMember), ของปาร์ตี้อื่นที่เคยได้ส่วนแบ่งไว้แต่ไม่ได้อยู่
    // แล้ว (ดึงมาโชว์ผ่าน fetchSharedKills) ล็อกทั้งแถวเสมอ ดูได้อย่างเดียว
    var writable = k.hostId===App.session.id || (k.hostId===activeOwnerId() && !isFreePartyMember());
    // รายการนี้เป็นประวัติส่วนตัวของตัวเอง (ก่อนเข้าปาร์ตี้ปัจจุบัน) ที่ถูกรวมมาแสดงปนกับของ
    // ปาร์ตี้ (ดู loadKillsForActiveOwner) — ต้องหารกับตัวเองเท่านั้น ไม่ใช่ roster ของปาร์ตี้ที่กำลังดูอยู่
    // เพราะไอเทมนี้ไม่ได้เกี่ยวอะไรกับปาร์ตี้นั้นเลย
    var roster = !writable ? [] : (k.hostId && k.hostId !== activeOwnerId())
      ? [{ id:App.session.id, name:(App.profile && App.profile.display_name) || '-' }]
      : (App.partyRoster || []);
    var unit = currencyLabel(it.soldCurrency);
    // คนที่เคยติ๊กหารไว้แต่ออกจากปาร์ตี้ไปแล้ว (ไม่อยู่ใน roster ปัจจุบัน) ยังต้องค้างชื่อไว้ในประวัติ
    // เหมือนเดิม แค่กดติ๊กออกไม่ได้แล้ว (ดู loadDepartedSharerNames) — ต่างจากคนในปาร์ตี้ตอนนี้ที่ยัง
    // กดติ๊ก/ปลดได้ปกติ — แถวที่ไม่มีสิทธิ์เขียนเลย (writable=false) ล็อกทุกชื่อหมด ไม่มีใครกดได้
    var rosterIds = {}; roster.forEach(function(p){ rosterIds[p.id] = true; });
    var departed = (it.sharedWith||[]).filter(function(id){ return !rosterIds[id]; }).map(function(id){
      return { id:id, name:id===App.session.id ? ((App.profile && App.profile.display_name) || '-') : (App.departedSharerNames[id] || 'ไม่ทราบชื่อ') };
    });
    // ไม่มีปาร์ตี้ (roster มีแค่ตัวเอง 1 คน) ก็ยังต้องโชว์แถวนี้ ไม่งั้นไม่มีทางติ๊กชื่อตัวเอง
    // ยอดขายเลยไม่มีวันเข้า "ส่วนแบ่งของฉัน" ได้เลยเพราะ sharedWith ว่างตลอด
    var shareHtml = (roster.length > 0 || departed.length > 0) ? '<div class="loot-line"><span class="loot-lbl">หาร</span>'+
      roster.map(function(p){
        var on = it.sharedWith.indexOf(p.id)!==-1;
        return '<button type="button" class="share-chip'+(on?' on':'')+'" data-share-toggle="'+it.id+'" data-member="'+p.id+'">'+(on?'✓ ':'')+escapeHtml(p.name)+'</button>';
      }).join('')+
      departed.map(function(p){
        return '<button type="button" class="share-chip on chip-locked" disabled title="'+(writable ? 'ออกจากปาร์ตี้ไปแล้ว — แก้ไขไม่ได้' : 'ปาร์ตี้อื่น — ดูได้อย่างเดียว')+'">✓ '+escapeHtml(p.name)+'</button>';
      }).join('')+'</div>' : '';
    var soldHtml;
    if(it.soldAmount!=null && (lootEditing!==it.id || !writable)){
      var each = it.sharedWith.length ? it.soldAmount / it.sharedWith.length : null;
      soldHtml = '<div class="loot-line"><span class="loot-lbl">ขายแล้ว</span><b>'+fmtNum(it.soldAmount)+' '+unit+'</b>'+
        '<span class="loot-each">'+(each!=null ? 'คนละ '+fmtNum(Math.round(each))+' '+unit+' ('+it.sharedWith.length+' คน)' : 'ไม่หาร')+'</span>'+
        (writable ? '<button type="button" class="btn btn-ghost btn-sm" data-sold-edit="'+it.id+'">แก้ไข</button>' : '')+'</div>';
    } else if(writable) {
      soldHtml = '<div class="loot-line"><span class="loot-lbl">ขายได้</span>'+
        '<input type="text" inputmode="numeric" class="sold-amount" placeholder="จำนวน" value="'+(it.soldAmount!=null ? fmtNum(it.soldAmount) : '')+'" data-sold-input="'+it.id+'">'+
        '<select class="sold-currency" data-sold-currency="'+it.id+'"><option value="zeny"'+(it.soldCurrency!=='baht'?' selected':'')+'>zeny</option><option value="baht"'+(it.soldCurrency==='baht'?' selected':'')+'>บาท</option></select>'+
        '<button type="button" class="btn btn-primary btn-sm" data-sold-save="'+it.id+'">บันทึก</button>'+
        (it.soldAmount!=null ? '<button type="button" class="btn btn-ghost btn-sm" data-sold-clear="'+it.id+'">ยกเลิกขาย</button>' : '')+
      '</div>';
    } else {
      soldHtml = '<div class="loot-line"><span class="loot-lbl">ยังไม่ขาย</span></div>';
    }
    // สถานะ: ขายแล้ว > เก็บไว้ (ไม่หาร ไม่ขาย เช่นของราคาถูก — เก็บประวัติไว้โดยไม่ต้องลบ) > หาร N คน > รอแบ่ง (ยังไม่ตัดสินใจ)
    var kept = !!it.keptAt && it.soldAmount==null;
    var pill, action = '';
    if(it.soldAmount!=null) pill = '<span class="membership-pill ok">ขายแล้ว</span>';
    else if(kept){
      pill = '<span class="membership-pill neutral">เก็บไว้</span>';
      if(writable) action = '<button type="button" class="loot-act" data-keep-undo="'+it.id+'" title="กลับไปเป็นรอแบ่ง">ยกเลิก</button>';
    } else {
      pill = it.sharedWith.length ? '<span class="membership-pill soon">หาร '+it.sharedWith.length+' คน</span>' : '<span class="membership-pill neutral">รอแบ่ง</span>';
      if(writable) action = '<button type="button" class="loot-act" data-keep="'+it.id+'" title="ของไม่มีมูลค่า ไม่หาร ไม่ขาย — เก็บประวัติไว้เฉยๆ">เก็บไว้</button>';
    }
    var bodyHtml = kept
      ? '<div class="loot-line"><span class="loot-lbl">เก็บไว้</span><span class="loot-each">ไม่หาร ไม่ขาย · กดเก็บเมื่อ '+fmtDateTime(it.keptAt)+'</span></div>'
      : shareHtml+soldHtml;
    var delBtn = writable ? '<button type="button" class="hist-del" data-del-item="'+it.id+'" title="ลบไอเทมนี้">✕</button>' : '';
    return '<div class="log-row loot-row">'+historyAvatarHtml(k.bossId, k.bossName)+'<div class="log-body">'+
      '<div class="loot-head"><div class="boss">'+itemIconHtml(it.name,'item-ic item-ic-lg')+escapeHtml(it.name)+'</div>'+
        '<div class="loot-head-r">'+pill+action+delBtn+'</div></div>'+
      '<div class="when">'+escapeHtml(k.bossName)+' · '+fmtDateTime(k.ts)+(k.killedBy ? ' · '+escapeHtml(k.killedBy) : '')+'</div>'+
      bodyHtml+
    '</div></div>';
  }
  function renderLootView(list, entries){
    var allRows = lootRows(entries, false);
    var rows = lootRows(entries, true);
    var filterHtml = '<div class="loot-filter">'+
      '<button type="button" class="'+(lootFilter==='all'?'active':'')+'" data-loot-filter="all">ทั้งหมด</button>'+
      '<button type="button" class="'+(lootFilter==='unsold'?'active':'')+'" data-loot-filter="unsold">ยังไม่ขาย</button>'+
      '<button type="button" class="'+(lootFilter==='sold'?'active':'')+'" data-loot-filter="sold">ขายแล้ว</button>'+
      '<button type="button" class="'+(lootFilter==='kept'?'active':'')+'" data-loot-filter="kept">เก็บไว้</button></div>';
    list.innerHTML = lootSummaryHtml(allRows) + filterHtml +
      (rows.length ? rows.map(lootRowHtml).join('') : '<p class="empty-note">ไม่มีไอเทมในช่วงนี้</p>');
  }
  function findKillItem(itemId){
    for(var i=0;i<App.kills.length;i++){
      var its = App.kills[i].items;
      for(var j=0;j<its.length;j++){ if(its[j].id===itemId) return its[j]; }
    }
    return null;
  }
  function updateKillItem(itemId, patch){
    return supa.from('kill_items').update(patch).eq('id', itemId).then(function(res){
      if(res.error){ console.error('updateKillItem', res.error); toast('บันทึกไม่สำเร็จ: '+res.error.message); }
      else bossNotifyChanged();
      return loadKills();
    }).then(function(){ renderHistory(); renderStats(); });
  }
  // มุมมอง "ตามบอส" แยกตามคนกด MVP/ตายแล้ว (kills.killed_by): ปุ่มเลือกคน = สมาชิกปาร์ตี้ + คนที่เคยกดแม้ออกจากปาร์ตี้ไปแล้ว
  // 'all' = ทุกคน (มีบรรทัด "กดโดย ใคร ×กี่ครั้ง" ใต้ชื่อบอส), 'none' = รอบเก่าที่ไม่รู้ว่าใครกด
  var bossKillerFilter = 'all';
  function killerNameOf(k){ return k.killedById ? (k.killedBy || 'ไม่ทราบชื่อ') : 'ไม่ระบุ'; }
  function killerOptions(){
    var seen = {}, opts = [];
    (App.partyRoster||[]).forEach(function(p){ if(!seen[p.id]){ seen[p.id] = true; opts.push({ id:p.id, name:p.name }); } });
    App.kills.forEach(function(k){
      var id = k.killedById || 'none';
      if(seen[id]) return;
      seen[id] = true; opts.push({ id:id, name:killerNameOf(k) });
    });
    return opts;
  }
  function renderBossView(list, entries){
    var opts = killerOptions();
    if(bossKillerFilter!=='all' && !opts.some(function(o){ return o.id===bossKillerFilter; })) bossKillerFilter = 'all';
    var counts = {};
    entries.forEach(function(k){ var id = k.killedById || 'none'; counts[id] = (counts[id]||0)+1; });
    var multi = opts.length > 1;
    var chips = multi ? '<div class="loot-filter">'+
      '<button type="button" class="'+(bossKillerFilter==='all'?'active':'')+'" data-boss-killer="all">ทั้งหมด</button>'+
      opts.map(function(o){
        return '<button type="button" class="'+(bossKillerFilter===o.id?'active':'')+'" data-boss-killer="'+o.id+'">'+escapeHtml(o.name)+' ('+(counts[o.id]||0)+')</button>';
      }).join('')+'</div>' : '';
    var scoped = bossKillerFilter==='all' ? entries : entries.filter(function(k){ return (k.killedById||'none')===bossKillerFilter; });
    list.innerHTML = chips + (scoped.length ? historyByBossHtml(scoped, multi ? bossKillerFilter : null) : '<p class="empty-note">ไม่มีข้อมูลในช่วงนี้</p>');
  }
  // รวมยอดต่อตัว (ฆ่ากี่ครั้ง/วันนี้/ไอเทมที่เคยได้) เรียงตัวที่ฆ่าล่าสุดขึ้นก่อน
  // killer: null = ไม่แยกคน, 'all' = โชว์บรรทัด "กดโดย", อื่นๆ = กำลังดูคนเดียว (ปุ่ม ✕ ลบเฉพาะรอบของคนนั้น)
  function historyByBossHtml(entries, killer){
    // แยกการ์ดตาม (บอส, เซิร์ฟเวอร์) ไม่ใช่แค่บอสอย่างเดียว — บอสตัวเดียวกันที่ฆ่าคนละเซิร์ฟ
    // จะไม่ถูกรวมยอดปนกัน (รอบเก่าที่ไม่มี server_id เก็บไว้ จะรวมเป็นการ์ดเดียวแยกไม่มีป้าย)
    var groups = {}, order = [];
    entries.forEach(function(l){
      var key = l.bossId+''+(l.serverId||'');
      if(!groups[key]){ groups[key] = { bossId:l.bossId, serverId:l.serverId, name:l.bossName, kills:[], items:Object.create(null), by:{}, byOrder:[] }; order.push(key); }
      var g = groups[key];
      g.kills.push(l);
      var who = killerNameOf(l);
      if(!g.by[who]){ g.by[who] = 0; g.byOrder.push(who); }
      g.by[who]++;
      l.items.forEach(function(it){ g.items[it.name] = (g.items[it.name]||0)+1; });
    });
    var today = todayKey(Date.now());
    var delAttr = (killer && killer!=='all') ? ' data-del-killer="'+killer+'"' : '';
    return order.map(function(key){
      var g = groups[key];
      var todayCount = g.kills.filter(function(l){ return todayKey(l.ts)===today; }).length;
      var names = Object.keys(g.items);
      var byHtml = killer==='all' ? '<div class="hist-by">กดโดย '+g.byOrder.map(function(w){ return escapeHtml(w)+' ×'+g.by[w]; }).join(' · ')+'</div>' : '';
      var displayName = g.name;
      var svAttr = ' data-del-server="'+(g.serverId||'')+'"';
      return '<div class="log-row">'+historyAvatarHtml(g.bossId, g.name)+'<div class="log-body">'+
        '<div class="hist-head"><div class="when">ฆ่าแล้ว '+g.kills.length+' ครั้ง · วันนี้ '+todayCount+' · ล่าสุด '+fmtDateTime(g.kills[0].ts)+'</div>'+
          '<button type="button" class="hist-del" data-del-boss="'+String(g.bossId).replace(/"/g,'&quot;')+'"'+svAttr+delAttr+' title="'+(delAttr ? 'ลบประวัติบอสตัวนี้เฉพาะรอบที่คนนี้กด' : 'ลบประวัติบอสตัวนี้ทั้งหมด')+'">✕</button></div>'+
        '<div class="boss">'+escapeHtml(displayName)+'</div>'+byHtml+
        '<div class="chip-row">'+(names.length ? names.map(function(it){ return '<span class="chip">'+itemIconHtml(it,'item-ic')+escapeHtml(it)+(g.items[it]>1 ? ' ×'+g.items[it] : '')+'</span>'; }).join('') : '<span class="chip">ยังไม่เคยได้ไอเทม</span>')+'</div></div></div>';
    }).join('');
  }

  function renderRateChips(){
    var root = document.getElementById('rateChips');
    var removable = App.rateSlots.length > 1;
    if(!SERVER_RATES.length){ root.innerHTML = '<p class="empty-note">ยังไม่มีเซิร์ฟเวอร์ในระบบ</p>'; return; }
    var cards = App.rateSlots.map(function(serverId, i){
      var sv = serverRateById(serverId) || SERVER_RATES[0];
      var options = myServerIds().map(function(id){
        var s = serverRateById(id);
        return '<option value="'+id+'"'+(id===sv.id?' selected':'')+'>'+(s?s.name:id)+'</option>';
      }).join('');
      return '<div class="stat-chip rate-chip">'+
        (removable ? '<button type="button" class="rate-chip-remove" data-remove-rate-slot="'+i+'" title="ลบการ์ด">✕</button>' : '')+
        '<select class="rate-select" data-slot="'+i+'">'+options+'</select>'+
        '<div class="rate-values">'+
          '<div class="rate-buy"><span class="rate-label">รับ</span><span class="rate-num">'+sv.buy+'บ</span></div>'+
        '</div>'+
      '</div>';
    }).join('');
    // ปุ่มนี้ทำ 2 หน้าที่: ถ้ายังมีเซิร์ฟในโควต้าที่ยังไม่ได้วางการ์ด = เพิ่มฟรี
    // ถ้าใช้โควต้าหมดแล้ว = ซื้อโควต้าเพิ่ม 30 แต้ม (ป้ายราคาจะขึ้นให้เห็นก่อนกด)
    var freeSlotLeft = App.rateSlots.length < serverQuota();
    var addBtn = App.rateSlots.length < MAX_RATE_CHIP_SLOTS
      ? '<button type="button" class="stat-chip rate-chip-add" id="addRateChipBtn">'+
          '<span class="rate-chip-add-label">+ เพิ่มเซิร์ฟเวอร์'+
            (freeSlotLeft ? '' : ' <span class="rate-chip-cost">'+SERVER_SLOT_COST+' แต้ม</span>')+
          '</span>'+
          // ใช้ไปกี่ช่อง / ซื้อไว้ทั้งหมดกี่ช่อง
          '<span class="rate-chip-count">('+App.rateSlots.length+'/'+serverQuota()+')</span>'+
        '</button>'
      : '';
    root.innerHTML = cards + addBtn;
  }

  function renderTickerServerChips(){
    var chips = document.getElementById('tickerServerChips');
    chips.innerHTML = App.tickerServers.map(function(id){
      var sv = serverRateById(id);
      var selected = App.tickerSelectedServers.indexOf(id)!==-1;
      return '<span class="chip chip-server'+(selected?' selected':'')+'" data-ticker-server="'+id+'">'+(sv?sv.name:id)+'</span>';
    }).join('');

    renderTicker();
  }

  // Presentation only: scroll the real announcements only when their content overflows.
  var tickerTrackElement = document.getElementById('tickerTrack');
  var tickerWrapElement = tickerTrackElement.parentElement;
  var tickerMotionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
  var tickerFrame = 0, tickerLastFrame = 0, tickerMaxScroll = 0, tickerOffset = 0;
  var tickerPhase = 'forward', tickerPhaseTime = 0, tickerReturnFrom = 0;
  var tickerHovered = false, tickerPointerId = null, tickerResumeAt = 0;

  function animateTickerFrame(now){
    tickerFrame = 0;
    if(tickerMotionPreference.matches || tickerMaxScroll<=1) return;
    var elapsed = tickerLastFrame ? Math.min(now - tickerLastFrame, 64) : 0;
    tickerLastFrame = now;
    var active = document.activeElement;
    var keyboardFocus = active && tickerWrapElement.contains(active) && active.matches(':focus-visible');
    if(tickerHovered || tickerPointerId!==null || now<tickerResumeAt || keyboardFocus || document.hidden){
      tickerOffset = Math.max(0, Math.min(tickerWrapElement.scrollLeft, tickerMaxScroll));
      tickerPhase = 'forward';
      tickerPhaseTime = 0;
    }else if(tickerPhase==='end'){
      tickerPhaseTime += elapsed;
      if(tickerPhaseTime>=1200){
        tickerPhase = 'return';
        tickerPhaseTime = 0;
        tickerReturnFrom = tickerOffset;
      }
    }else if(tickerPhase==='return'){
      tickerPhaseTime += elapsed;
      var progress = Math.min(1, tickerPhaseTime/650);
      var eased = progress*progress*(3-2*progress);
      tickerOffset = tickerReturnFrom*(1-eased);
      tickerWrapElement.scrollLeft = tickerOffset;
      if(progress===1){ tickerPhase = 'start'; tickerPhaseTime = 0; }
    }else if(tickerPhase==='start'){
      tickerPhaseTime += elapsed;
      if(tickerPhaseTime>=650){ tickerPhase = 'forward'; tickerPhaseTime = 0; }
    }else{
      tickerOffset = Math.min(tickerMaxScroll, tickerOffset + elapsed * 0.024); // 24px/second
      tickerWrapElement.scrollLeft = tickerOffset;
      if(tickerOffset>=tickerMaxScroll){ tickerPhase = 'end'; tickerPhaseTime = 0; }
    }
    tickerFrame = requestAnimationFrame(animateTickerFrame);
  }

  function rebuildTickerLoop(){
    cancelAnimationFrame(tickerFrame);
    tickerFrame = 0;
    tickerLastFrame = 0;
    tickerPhase = 'forward';
    tickerPhaseTime = 0;
    tickerMaxScroll = Math.max(0, tickerWrapElement.scrollWidth-tickerWrapElement.clientWidth);
    tickerOffset = Math.max(0, Math.min(tickerWrapElement.scrollLeft, tickerMaxScroll));
    tickerWrapElement.scrollLeft = tickerOffset;
    if(!tickerTrackElement.querySelector('[data-announce-id]') || tickerMaxScroll<=1 ||
       tickerMotionPreference.matches || !tickerWrapElement.clientWidth) return;
    tickerFrame = requestAnimationFrame(animateTickerFrame);
  }

  tickerWrapElement.addEventListener('pointerenter', function(e){
    if(e.pointerType==='mouse') tickerHovered = true;
  });
  tickerWrapElement.addEventListener('pointerleave', function(e){
    if(e.pointerType==='mouse') tickerHovered = false;
  });
  tickerWrapElement.addEventListener('pointerdown', function(e){
    tickerPointerId = e.pointerId;
    tickerResumeAt = performance.now()+1200;
  }, {passive:true});
  function releaseTickerPointer(e){
    if(e.pointerId!==tickerPointerId) return;
    tickerPointerId = null;
    tickerResumeAt = performance.now()+1200;
  }
  window.addEventListener('pointerup', releaseTickerPointer, {passive:true});
  window.addEventListener('pointercancel', releaseTickerPointer, {passive:true});
  tickerWrapElement.addEventListener('wheel', function(){
    tickerResumeAt = performance.now()+1200;
  }, {passive:true});
  tickerWrapElement.addEventListener('scroll', function(){
    var now = performance.now();
    // Keep waiting while a touch swipe is still coasting; automatic scrolls do not pause it.
    if(tickerPointerId!==null || now<tickerResumeAt) tickerResumeAt = now+1200;
  }, {passive:true});
  tickerMotionPreference.addEventListener('change', rebuildTickerLoop);
  var tickerObservedSize = '';
  var tickerResizeObserver = new ResizeObserver(function(){
    var size = tickerWrapElement.clientWidth+':'+tickerWrapElement.scrollWidth;
    if(size!==tickerObservedSize){
      tickerObservedSize = size;
      rebuildTickerLoop();
    }
  });
  tickerResizeObserver.observe(tickerWrapElement);
  tickerResizeObserver.observe(tickerTrackElement);
  if(document.fonts) document.fonts.ready.then(rebuildTickerLoop);

  function renderTicker(){
    var track = document.getElementById('tickerTrack');
    var now = Date.now();

    // ตัดประกาศที่หมดอายุออกจากหน่วยความจำ (แถวจริงในฐานข้อมูลถูกกรองด้วย expires_at
    // ตอน select อยู่แล้ว ตรงนี้ไว้กันอันที่หมดอายุระหว่างที่ยังไม่ได้ poll รอบใหม่)
    App.rateAnnouncements = App.rateAnnouncements.filter(function(a){ return a.expiresAt==null || a.expiresAt>now; });

    var posts = App.rateAnnouncements.filter(function(a){ return App.tickerSelectedServers.indexOf(a.serverId)!==-1; })
                                      .slice().sort(function(a,b){ return b.ts-a.ts; });
    if(!posts.length){
      track.style.animation = 'none';
      track.innerHTML = '<span class="ticker-item"><span class="dashboard-empty-title">ยังไม่มีประกาศจากเซิร์ฟเวอร์ที่เลือก</span><span class="dashboard-empty-detail">'+(App.isGuest ? 'เข้าสู่ระบบเพื่อเลือกเซิร์ฟเวอร์และลงประกาศรับ M' : 'เลือกเซิร์ฟเวอร์ที่ต้องการดู หรือกด "ลงประกาศ" เพื่อเริ่มประกาศรับ M')+'</span></span>';
      rebuildTickerLoop();
      return;
    }

    var items = posts.map(function(a){
      var sv = serverRateById(a.serverId);
      var parts = [];
      if(a.buy!=null) parts.push('<span class="buy">รับM '+fmtNum(a.buy)+'บ</span>');
      var countdown = a.expiresAt!=null ? '<span class="ticker-countdown" data-expires-at="'+a.expiresAt+'">'+fmtDuration(a.expiresAt-now)+'</span>' : '';
      // มีลิงก์ Facebook แนบมากับประกาศ (จำสำเนาไว้ตอนลงประกาศ) ให้กดชื่อแล้วไปหน้านั้นได้เลย
      var posterHtml = a.facebookUrl
        ? '<a class="poster" href="'+escapeHtml(/^https?:\/\//i.test(a.facebookUrl) ? a.facebookUrl : 'https://'+a.facebookUrl)+'" target="_blank" rel="noopener noreferrer">('+escapeHtml(a.userName)+')</a>'
        : '<span class="poster">('+escapeHtml(a.userName)+')</span>';
      return '<span class="ticker-item" data-announce-id="'+a.id+'">'+
        '<span class="ticker-item-main">'+(sv?sv.name:a.serverId)+' '+posterHtml+'</span>'+
        '<span class="ticker-item-sub">'+parts.join(' / ')+countdown+'</span>'+
      '</span>';
    }).join('');

    // Render each real announcement once, retaining its countdown and profile link.
    track.style.animation = 'none';
    track.innerHTML = items;
    rebuildTickerLoop();
  }

  function tickTickerCountdowns(){
    var now = Date.now();
    var spans = document.querySelectorAll('#tickerTrack .ticker-countdown');
    if(!spans.length) return;
    var expired = false;
    spans.forEach(function(el){
      var exp = parseInt(el.dataset.expiresAt, 10);
      var remain = exp - now;
      if(remain <= 0){ expired = true; return; }
      el.textContent = fmtDuration(remain);
    });
    if(expired) renderTicker();
  }

  // ---------- merchant รับ/ขาย bar chart (real data from App.merchantLog) ----------
  // Hand-rolled inline SVG — no charting library, so nothing depends on a CDN script executing.
  var MR_CHART_SERIES_KEYS = ['sell','buy','profit'];
  var MR_CHART_SERIES_LABEL = { sell:'ขาย', buy:'ซื้อ', profit:'กำไรสุทธิ' };
  var MR_CHART_SERIES_COLOR = { sell:'#3fbd75', buy:'#ef5a56', profit:'#5b8ef4' };
  var MR_LOSS_COLOR = '#ef5a56';
  var hiddenMrChartSeries = { sell:false, buy:false, profit:false };
  var mrChartTimeframe = 'today';
  var mrChartServerId = null;
  var mrChartServerUserChanged = false;
  var mrChartCategoryFilter = 'all';
  var mrChartGeom = null; // recomputed on each render; used by the hover handler

  // Bucket unit/count come from CHART_TIMEFRAME_CONFIG (shared with the farm chart) so both
  // pages tier day → week → month at the same breakpoints instead of always bucketing by day
  // (which used to render 365 unreadable slivers at "1 ปี").
  function mrChartGenerateBuckets(cfg, endOffsetUnits){
    var buckets = generateTimeBuckets(cfg.unit, cfg.count, endOffsetUnits);
    buckets.forEach(function(b){ b.sell = 0; b.buy = 0; });
    return buckets;
  }

  function mrChartBuckets(tf, serverId, endOffsetUnits, categoryFilter){
    var cfg = mrChartCfg(tf, serverId, categoryFilter);
    var buckets = mrChartGenerateBuckets(cfg, endOffsetUnits);
    var byKey = {};
    buckets.forEach(function(b){ byKey[b.key] = b; });
    App.merchantLog.forEach(function(e){
      if(serverId!=='all' && e.serverId!==serverId) return;
      if(categoryFilter && categoryFilter!=='all' && (e.category||'zeny')!==categoryFilter) return;
      var b = byKey[farmBucketKey(e.ts, cfg.unit)];
      if(!b) return;
      var t = entryTotals(e);
      var amount = t.baht + (t.zeny>0 && e.exchangeRate>0 ? farmZenyToBaht(t.zeny, e.exchangeRate) : 0);
      if(entryType(e)==='sell'){ b.sell += amount; }
      else { b.buy += amount; }
    });
    buckets.forEach(function(b){ b.profit = b.sell-b.buy; });
    return buckets;
  }

  function populateMrChartServerSelect(){
    var sel = document.getElementById('mrChartServerSelect');
    var ids = historyPickerServerIds();
    var invalid = mrChartServerId!=='all' && (mrChartServerId==null || ids.indexOf(mrChartServerId)===-1);
    if(!mrChartServerUserChanged || invalid) mrChartServerId = firstMyServerIn(ids);
    sel.innerHTML = ids.map(function(id){
      return '<option value="'+id+'">'+serverLabel(id)+'</option>';
    }).join('')+'<option value="all">ALL</option>';
    sel.value = mrChartServerId;

    var tag = document.getElementById('mrChartServerTag');
    var tagNames = mrChartServerId==='all'
      ? ids.map(function(id){ var sv = serverRateById(id); return sv?sv.name:id; })
      : [(function(){ var sv = serverRateById(mrChartServerId); return sv ? sv.name : (mrChartServerId||''); })()];
    tag.innerHTML = tagNames.map(function(n){ return '<span class="farm-revenue-server">'+n+'</span>'; }).join('');
  }

  function niceStep(rough){
    var mag = Math.pow(10, Math.floor(Math.log10(rough||1)));
    var norm = rough / mag;
    var step = norm<1.5 ? 1 : norm<3 ? 2 : norm<7 ? 5 : 10;
    return step * mag;
  }

  // ---------- ยอดนักฟาม (farm yield tracker) ----------
  var FARM_SERIES_COLOR = { earned:'#f2c94c', cost:'#ef5a56', profit:'#3fbd75', avgPerSession:'#c9a8f0' };
  var FARM_SERIES_LABEL = { earned:'ยอดรวม', cost:'ทุน', profit:'กำไร', avgPerSession:'เฉลี่ย/กั้ม' };
  var FARM_SERIES_KEYS = ['earned','cost','profit','avgPerSession'];

  function farmBucketVal(b, key){
    return farmChartUnit==='baht' ? (b[key+'Baht']||0) : (b[key]||0);
  }
  function farmUnitSuffix(){
    return farmChartUnit==='baht' ? ' บ' : ' z';
  }
  // TF ชุดเดียวใช้ร่วมกันทุกที่: กราฟกำไร 2 หน้า + ประวัติซื้อ-ขาย + ประวัติการฟาม
  // unit/count = ความละเอียดของแท่งกราฟ, days/months/years = ช่วงย้อนหลังของ "ประวัติ"
  var CHART_TIMEFRAME_CONFIG = {
    'today': { unit:'day', count:1, label:'วันนี้', days:1 },
    '7d': { unit:'day', count:7, label:'7วัน', days:7 },
    '30d': { unit:'day', count:30, label:'30วัน', days:30 },
    '15d': { unit:'day', count:15, label:'15วัน', days:15 },
    '1m': { unit:'week', count:5, label:'1เดือน', months:1 },
    '3m': { unit:'month', count:3, label:'3เดือน', months:3 },
    '6m': { unit:'month', count:6, label:'6เดือน', months:6 },
    '1y': { unit:'month', count:12, label:'1ปี', years:1 },
    'all': { unit:'month', count:12, label:'ทั้งหมด' }
  };

  // จุดเริ่มของช่วงเวลาที่ TF ครอบคลุม (null = ทั้งหมด ไม่ตัดอะไรทิ้ง)
  function tfRangeStartTs(tf){
    var cfg = CHART_TIMEFRAME_CONFIG[tf];
    if(!cfg || tf==='all') return null;
    var d = new Date(); d.setHours(0,0,0,0);
    if(cfg.days) d.setDate(d.getDate()-(cfg.days-1));
    else if(cfg.months) d.setMonth(d.getMonth()-cfg.months);
    else if(cfg.years) d.setFullYear(d.getFullYear()-cfg.years);
    return d.getTime();
  }
  function todayStartTs(){ var d = new Date(); d.setHours(0,0,0,0); return d.getTime(); }
  // บัญชีฟรี (ไม่มีสิทธิ์ตามพารามิเตอร์ allowed) ดูประวัติย้อนหลังได้แค่วันนี้ — ไม่ว่าตัวกรอง
  // ช่วงเวลาที่เลือกไว้จะกว้างแค่ไหนก็ตาม (ข้อมูลจริงยังอยู่ครบ แค่ไม่โชว์เกินวันนี้ให้เห็น)
  function capStartTsForPlan(rawStartTs, allowed){
    if(allowed) return rawStartTs;
    var t = todayStartTs();
    return rawStartTs===null ? t : Math.max(rawStartTs, t);
  }

  // TF "ทั้งหมด" บนกราฟไม่มีจำนวนแท่งตายตัว — ย้อนไปถึงรายการแรกสุดที่มีจริง แล้วเลือก
  // ความละเอียด วัน/สัปดาห์/เดือน ให้แท่งไม่ถี่จนอ่านไม่ออก (เหมือนที่ 1 ปี ใช้แท่งเดือน)
  function tfConfigFor(tf, earliestTs){
    var cfg = CHART_TIMEFRAME_CONFIG[tf] || CHART_TIMEFRAME_CONFIG['7d'];
    if(tf!=='all') return cfg;
    if(!earliestTs) return { unit:'day', count:7, label:cfg.label };
    var now = new Date(); now.setHours(0,0,0,0);
    var start = new Date(earliestTs); start.setHours(0,0,0,0);
    var days = Math.floor((now.getTime()-start.getTime())/86400000)+1;
    if(days<=31) return { unit:'day', count:Math.max(1,days), label:cfg.label };
    if(days<=182) return { unit:'week', count:Math.ceil(days/7), label:cfg.label };
    var months = (now.getFullYear()-start.getFullYear())*12 + (now.getMonth()-start.getMonth()) + 1;
    return { unit:'month', count:Math.min(Math.max(1,months),60), label:cfg.label };
  }

  function farmEarliestTs(serverId){
    var min = null;
    App.farmLog.forEach(function(e){ if(e.serverId!==serverId) return; if(min===null || e.ts<min) min = e.ts; });
    return min;
  }
  function mrEarliestTs(serverId, categoryFilter){
    var min = null;
    App.merchantLog.forEach(function(e){
      if(serverId!=='all' && e.serverId!==serverId) return;
      if(categoryFilter && categoryFilter!=='all' && (e.category||'zeny')!==categoryFilter) return;
      if(min===null || e.ts<min) min = e.ts;
    });
    return min;
  }
  function farmChartCfg(){
    return tfConfigFor(farmTimeframe, farmTimeframe==='all' ? farmEarliestTs(App.farmServerId) : null);
  }
  function mrChartCfg(tf, serverId, categoryFilter){
    return tfConfigFor(tf, tf==='all' ? mrEarliestTs(serverId, categoryFilter) : null);
  }
  var hiddenFarmSeries = { earned:false, cost:false, profit:false, avgPerSession:false };
  var farmTimeframe = 'today';
  var farmChartUnit = 'zeny';
  var farmChartGeom = null;

  function farmCostRows(serverId){
    if(!App.farmCostItems[serverId]) App.farmCostItems[serverId] = [{ id:uid(), name:'', price:'', qty:'', currency:'zeny' }];
    return App.farmCostItems[serverId];
  }

  function farmExchangeRate(serverId){
    var v = App.farmExchangeRates[serverId];
    return v!=null && v!=='' ? parseFloat(v) : 0;
  }

  function farmZenyToBaht(zeny, rate){
    return (zeny/1000000)*rate;
  }
  function farmBahtToZeny(baht, rate){
    return rate>0 ? (baht/rate)*1000000 : 0;
  }

  function merchantExchangeRate(serverId){
    var v = App.merchantExchangeRates[serverId];
    return v!=null && v!=='' ? parseFloat(v) : 0;
  }

  function farmCostBreakdown(serverId){
    var zenyTotal = 0, bahtTotal = 0, hasBaht = false;
    farmCostRows(serverId).forEach(function(r){
      var lineTotal = (parseFloat(r.price)||0)*(parseFloat(r.qty)||0);
      if((r.currency||'zeny')==='baht'){ bahtTotal += lineTotal; hasBaht = true; }
      else zenyTotal += lineTotal;
    });
    var rate = farmExchangeRate(serverId);
    var bahtConverted = rate>0 ? (bahtTotal/rate)*1000000 : 0;
    return { zenyTotal:zenyTotal, bahtTotal:bahtTotal, bahtConverted:bahtConverted, total:zenyTotal+bahtConverted, rate:rate, hasBaht:hasBaht };
  }

  function farmCostTotal(serverId){
    return farmCostBreakdown(serverId).total;
  }

  function farmSnapshotCostRows(serverId){
    return farmCostRows(serverId).map(function(r){ return { id:r.id, name:r.name, price:r.price, qty:r.qty, currency:r.currency||'zeny' }; });
  }

  // หน้าฟามใช้ dropdown ตัวเดียวคุมทั้ง "ช่องกรอกต้นทุน" และ "กราฟ/ประวัติการฟาม"
  // เลยต้องโชว์เซิร์ฟที่เคยมีข้อมูลฟามไว้ด้วย ไม่งั้นเลิกเล่นเซิร์ฟไหนแล้วประวัติเซิร์ฟนั้นจะเข้าไม่ถึงเลย
  // เซิร์ฟที่พักอยู่จะดูย้อนหลังได้อย่างเดียว กรอกใหม่ไม่ได้ (ดู renderFarmRetiredState)
  // ไม่กรองเซิร์ฟพักที่ซ่อนไว้ — ใช้สำหรับหน้าตั้งค่า (เหมือน rawHistoryServerIds)
  function rawFarmServerIds(){
    var ids = myServerIds().slice();
    App.farmLog.forEach(function(e){ if(e.serverId && ids.indexOf(e.serverId)===-1) ids.push(e.serverId); });
    Object.keys(App.farmCostItems||{}).forEach(function(id){
      if(ids.indexOf(id)===-1 && (App.farmCostItems[id]||[]).length) ids.push(id);
    });
    return ids;
  }
  // ตัดเซิร์ฟพักที่ผู้ใช้ซ่อนไว้ออก (ดู isHistoryServerShown) — เซิร์ฟที่เล่นอยู่ (myServerIds) ไม่ถูกกรองอยู่แล้ว
  function farmServerIds(){
    return rawFarmServerIds().filter(isHistoryServerShown);
  }
  function populateFarmServerSelect(){
    var sel = document.getElementById('farmServerSelect');
    var ids = farmServerIds();
    if(ids.indexOf(App.farmServerId)===-1){
      App.farmServerId = ids[0] || null;
      saveFarmServer();
    }
    sel.innerHTML = ids.map(function(id){ return '<option value="'+id+'">'+serverLabel(id)+'</option>'; }).join('');
    sel.value = App.farmServerId;
  }

  function renderFarmExchangeRate(){
    var input = document.getElementById('farmExRateInput');
    var v = App.farmExchangeRates[App.farmServerId];
    input.value = v!=null && v!=='' ? Number(v).toLocaleString('th-TH') : '';
    input.classList.remove('farm-exrate-invalid');
    document.getElementById('farmExRateError').hidden = true;
  }

  function renderFarmMapName(){
    document.getElementById('farmMapInput').value = App.farmMapNames[App.farmServerId] || '';
  }

  function updateFarmCostSummary(){
    var bd = farmCostBreakdown(App.farmServerId);
    document.getElementById('farmCostTotal').textContent = fmtNum(bd.total)+' z';
  }

  function renderFarmCostItems(){
    var rows = farmCostRows(App.farmServerId);
    var removable = rows.length > 1;
    document.getElementById('farmCostItems').innerHTML = rows.map(function(r, rowIdx){
      var currency = r.currency || 'zeny';
      return '<div class="farm-cost-row" data-row-id="'+r.id+'">'+
        '<span class="mr-row-index">'+(rowIdx+1)+'.</span>'+
        '<input type="text" class="farm-cost-name" maxlength="120" placeholder="วิง, เร่ง, กั้ม" value="'+(r.name||'').replace(/"/g,'&quot;')+'">'+
        '<input type="number" class="farm-cost-qty" placeholder="จำนวน" value="'+(r.qty===''||r.qty==null?'':r.qty)+'">'+
        '<input type="text" inputmode="numeric" class="farm-cost-price" placeholder="ราคา" value="'+(r.price===''||r.price==null?'':fmtNum(r.price))+'">'+
        '<select class="farm-cost-currency">'+
          '<option value="zeny"'+(currency==='zeny'?' selected':'')+'>Zeny</option>'+
          '<option value="baht"'+(currency==='baht'?' selected':'')+'>บาท</option>'+
        '</select>'+
        '<button type="button" class="mr-row-remove" data-remove-row="'+r.id+'"'+(removable?'':' disabled')+'>✕</button>'+
      '</div>';
    }).join('');
    updateFarmCostSummary();
  }

  function farmRareItemsTotal(){
    return farmRareItemRows.reduce(function(s,r){ return s + (parseFloat(r.price)||0)*(parseFloat(r.qty)||1); }, 0);
  }

  function renderFarmRareItems(){
    var rows = farmRareItemRows;
    var removable = rows.length > 1;
    document.getElementById('farmRareItems').innerHTML = rows.map(function(r, rowIdx){
      var currency = r.currency || 'zeny';
      return '<div class="farm-rare-row" data-row-id="'+r.id+'">'+
        '<span class="mr-row-index">'+(rowIdx+1)+'.</span>'+
        '<input type="text" class="farm-rare-name" maxlength="120" placeholder="Elu, Ori, Card" value="'+(r.name||'').replace(/"/g,'&quot;')+'">'+
        '<input type="number" class="farm-rare-qty" placeholder="จำนวน" value="'+(r.qty===''||r.qty==null?'':r.qty)+'" min="1">'+
        '<input type="text" inputmode="numeric" class="farm-rare-price" placeholder="ราคา" value="'+(r.price===''||r.price==null?'':fmtNum(r.price))+'">'+
        '<select class="farm-rare-currency">'+
          '<option value="zeny"'+(currency==='zeny'?' selected':'')+'>Zeny</option>'+
          '<option value="baht"'+(currency==='baht'?' selected':'')+'>บาท</option>'+
        '</select>'+
        '<button type="button" class="mr-row-remove" data-remove-rare-row="'+r.id+'"'+(removable?'':' disabled')+'>✕</button>'+
      '</div>';
    }).join('');
  }

  function farmWeekIndex(ts){
    var days = Math.floor((new Date(ts) - new Date(2020,0,1))/86400000);
    return Math.floor(days/7);
  }
  function farmWeekRangeLabel(weekIdx){
    var start = new Date(new Date(2020,0,1).getTime() + weekIdx*7*86400000);
    var end = new Date(start.getTime() + 6*86400000);
    return start.toLocaleDateString('th-TH',{day:'numeric',month:'short'})+' - '+end.toLocaleDateString('th-TH',{day:'numeric',month:'short'});
  }
  function farmBucketKey(ts, unit){
    var d = new Date(ts);
    if(unit==='week') return 'w'+farmWeekIndex(ts);
    if(unit==='month') return d.getFullYear()+'-'+d.getMonth();
    return d.toDateString();
  }

  function farmBeShort(d){ return String(d.getFullYear()+543).slice(-2); }

  // Shared day/week/month bucket generator — used by both the farm and merchant charts
  // so a given timeframe tiers to the same granularity (and bar count) on either page.
  function generateTimeBuckets(unit, count, endOffsetUnits){
    endOffsetUnits = endOffsetUnits || 0;
    var now = new Date();
    var buckets = [];
    for(var i=count-1;i>=0;i--){
      var idx = i + endOffsetUnits*count;
      var d, label;
      if(unit==='week'){
        d = new Date(now.getFullYear(), now.getMonth(), now.getDate()-idx*7);
        label = farmWeekRangeLabel(farmWeekIndex(d.getTime()));
      } else if(unit==='month'){
        d = new Date(now.getFullYear(), now.getMonth()-idx, 1);
        label = d.toLocaleDateString('th-TH',{month:'short'});
      } else {
        d = new Date(now.getFullYear(), now.getMonth(), now.getDate()-idx);
        label = d.toLocaleDateString('th-TH',{day:'numeric',month:'short'});
      }
      var tooltipLabel = label+' '+farmBeShort(d);
      buckets.push({ key:farmBucketKey(d.getTime(),unit), label:label, tooltipLabel:tooltipLabel });
    }
    return buckets;
  }

  function farmGenerateBuckets(unit, count, endOffsetUnits){
    var buckets = generateTimeBuckets(unit, count, endOffsetUnits);
    buckets.forEach(function(b){
      b.earned=0; b.cost=0; b.profit=0; b.count=0; b.earnedBaht=0; b.costBaht=0; b.profitBaht=0;
    });
    return buckets;
  }

  function farmBuckets(serverId, unit, count, endOffsetUnits){
    var buckets = farmGenerateBuckets(unit, count, endOffsetUnits);
    var byKey = {};
    buckets.forEach(function(b){ byKey[b.key] = b; });
    App.farmLog.forEach(function(e){
      if(e.serverId!==serverId) return;
      var b = byKey[farmBucketKey(e.ts, unit)];
      if(!b) return;
      b.earned += e.earned; b.profit += e.profit; b.cost += e.cost; b.count += (e.count||1);
      if(e.exchangeRate>0){
        b.earnedBaht += farmZenyToBaht(e.earned, e.exchangeRate);
        b.profitBaht += farmZenyToBaht(e.profit, e.exchangeRate);
        b.costBaht += farmZenyToBaht(e.cost, e.exchangeRate);
      }
    });
    buckets.forEach(function(b){
      b.avgPerSession = b.count>0 ? b.profit/b.count : 0;
      b.avgPerSessionBaht = b.count>0 ? b.profitBaht/b.count : 0;
    });
    return buckets;
  }

  function renderFarmChart(){
    hideFarmChartHover();
    var serverTagEl = document.getElementById('farmRevenueServerTag');
    var curServer = serverRateById(App.farmServerId);
    serverTagEl.textContent = curServer ? curServer.name : '';
    var svg = document.getElementById('farmChartSvg');
    var cfg = farmChartCfg();
    var buckets = farmBuckets(App.farmServerId, cfg.unit, cfg.count, 0);
    var series = FARM_SERIES_KEYS.filter(function(s){ return !hiddenFarmSeries[s]; });
    var W=640, H=220, padL=52, padR=8, padT=10, padB=22;
    var plotW = W-padL-padR, plotH = H-padT-padB;
    var n = buckets.length;

    var allVals = [0];
    series.forEach(function(s){ buckets.forEach(function(b){ allVals.push(farmBucketVal(b,s)); }); });
    var rawMin = Math.min.apply(null, allVals), rawMax = Math.max.apply(null, allVals);
    var step = niceStep((rawMax-rawMin)/4 || rawMax*0.1 || 1);
    var yMin = Math.floor(rawMin/step)*step;
    var yMax = Math.ceil(rawMax/step)*step;
    if(yMax===yMin) yMax = yMin+step;

    var slotW = plotW/n;
    function xSlot(i){ return padL + i*slotW; }
    function yAt(v){ return padT + plotH - ((v-yMin)/(yMax-yMin))*plotH; }
    var y0 = yAt(0);

    var parts = [];
    var gridCount = (yMax-yMin)/step;
    for(var g=0; g<=gridCount; g++){
      var gv = yMin + g*step, gy = yAt(gv);
      parts.push('<line x1="'+padL+'" y1="'+gy+'" x2="'+(W-padR)+'" y2="'+gy+'" stroke="#262832" stroke-width="1"/>');
      parts.push('<text x="'+(padL-6)+'" y="'+(gy+3)+'" text-anchor="end" font-size="9" fill="#8b8d98">'+fmtNum(gv)+'</text>');
    }
    var everyN = Math.max(1, Math.ceil(n/8));
    for(var i=0;i<n;i+=everyN){
      parts.push('<text x="'+(xSlot(i)+slotW/2)+'" y="'+(H-6)+'" text-anchor="middle" font-size="9" fill="#8b8d98">'+buckets[i].label+'</text>');
    }
    if(!App.farmLog.some(function(e){ return e.serverId===App.farmServerId; })){
      parts.push('<text x="'+(W/2)+'" y="'+(H/2)+'" text-anchor="middle" font-size="11" fill="#8b8d98">ยังไม่มีข้อมูลการฟาม — บันทึกกั้มแรกทางด้านขวา</text>');
    } else {
      var groupPad = n<=1 ? 0.32 : 0.16;
      var groupW = slotW*(1-groupPad*2);
      var barGap = groupW*0.08;
      var barW = (groupW - barGap*(series.length-1))/Math.max(series.length,1);
      buckets.forEach(function(b,i){
        var groupX = xSlot(i) + slotW*groupPad;
        series.forEach(function(s, si){
          var bx = groupX + si*(barW+barGap);
          var v = farmBucketVal(b,s);
          var y1 = yAt(v), y2 = y0;
          var top = Math.min(y1,y2), h = Math.max(Math.abs(y1-y2), 1);
          parts.push('<rect x="'+bx.toFixed(1)+'" y="'+top.toFixed(1)+'" width="'+barW.toFixed(1)+'" height="'+h.toFixed(1)+'" rx="2" fill="'+FARM_SERIES_COLOR[s]+'"/>');
        });
      });
    }
    if(yMin<0){
      parts.push('<line x1="'+padL+'" y1="'+y0.toFixed(1)+'" x2="'+(W-padR)+'" y2="'+y0.toFixed(1)+'" stroke="#3a3c48" stroke-width="1"/>');
    }
    parts.push('<g id="farmChartHoverLayer"></g>');
    svg.setAttribute('viewBox','0 0 '+W+' '+H);
    svg.innerHTML = parts.join('');

    farmChartGeom = { W:W, H:H, padL:padL, plotW:plotW, padT:padT, n:n, slotW:slotW, xSlot:xSlot, yAt:yAt, buckets:buckets };
    renderFarmChartLegend(buckets);
    renderFarmSeriesFilter();
    renderFarmKpi();
  }

  function renderFarmSeriesFilter(){
    var shown = FARM_SERIES_KEYS.filter(function(s){ return !hiddenFarmSeries[s]; });
    var hidden = FARM_SERIES_KEYS.filter(function(s){ return hiddenFarmSeries[s]; });
    document.getElementById('farmSeriesChips').innerHTML = shown.map(function(s){
      var color = FARM_SERIES_COLOR[s];
      return '<span class="farm-series-chip" style="background:color-mix(in srgb, '+color+' 20%, transparent)">'+
        '<span class="cl-dot" style="background:'+color+'"></span>'+FARM_SERIES_LABEL[s]+
        '<button type="button" class="farm-series-chip-x" data-farm-legend-remove="'+s+'">✕</button></span>';
    }).join('');
    var dropdownBtn = document.getElementById('farmSeriesDropdownBtn');
    dropdownBtn.hidden = !hidden.length;
    var dropdown = document.getElementById('farmSeriesDropdown');
    dropdown.innerHTML = hidden.map(function(s){
      var color = FARM_SERIES_COLOR[s];
      return '<button type="button" class="farm-series-dropdown-item" data-farm-legend-add="'+s+'"><span class="cl-dot" style="background:'+color+'"></span>'+FARM_SERIES_LABEL[s]+'</button>';
    }).join('') || '<span class="farm-series-dropdown-empty">แสดงครบทุกรายการแล้ว</span>';
  }

  function renderFarmChartLegend(buckets){
    var el = document.getElementById('farmChartLegend');
    var totals = { earned:0, cost:0, profit:0, count:0, earnedBaht:0, costBaht:0, profitBaht:0 };
    buckets.forEach(function(b){
      totals.earned+=b.earned; totals.cost+=b.cost; totals.profit+=b.profit; totals.count+=b.count;
      totals.earnedBaht+=b.earnedBaht; totals.costBaht+=b.costBaht; totals.profitBaht+=b.profitBaht;
    });
    var displayVals = {
      earned: farmChartUnit==='baht'?totals.earnedBaht:totals.earned,
      cost: farmChartUnit==='baht'?totals.costBaht:totals.cost,
      profit: farmChartUnit==='baht'?totals.profitBaht:totals.profit,
      avgPerSession: totals.count>0 ? (farmChartUnit==='baht'?totals.profitBaht:totals.profit)/totals.count : 0
    };
    var unit = farmUnitSuffix();
    var row = FARM_SERIES_KEYS.map(function(s){
      var off = hiddenFarmSeries[s];
      var countSuffix = s==='avgPerSession' ? ' <span style="color:var(--text-dim);font-weight:400">('+totals.count+' กั้ม)</span>' : '';
      return '<button type="button" class="chart-legend-item chart-legend-dir'+(off?' off':'')+'" data-farm-legend="'+s+'">'+
        '<span class="cl-dot" style="background:'+FARM_SERIES_COLOR[s]+'"></span>'+FARM_SERIES_LABEL[s]+
        ' <b style="color:'+FARM_SERIES_COLOR[s]+'">'+fmtNum(displayVals[s])+unit+'</b>'+countSuffix+'</button>';
    }).join('');
    el.innerHTML = '<div class="chart-legend-row">'+row+'</div>';
  }

  function renderFarmKpi(){
    var cfg = farmChartCfg();
    var cur = farmBuckets(App.farmServerId, cfg.unit, cfg.count, 0);
    var prev = farmBuckets(App.farmServerId, cfg.unit, cfg.count, 1);
    function sum(arr,k){ return arr.reduce(function(s,b){ return s+b[k]; }, 0); }
    var profitKey = farmChartUnit==='baht' ? 'profitBaht' : 'profit';
    var unit = farmUnitSuffix();
    var curProfit = sum(cur,profitKey);
    var prevProfit = sum(prev,profitKey);
    var valueEl = document.getElementById('farmKpiValue');
    valueEl.textContent = (curProfit<0?'-':'')+fmtNum(Math.abs(curProfit))+unit;
    valueEl.style.color = curProfit>=0 ? FARM_SERIES_COLOR.profit : FARM_LOSS_COLOR;
    document.getElementById('farmKpiPeriod').textContent = '('+cfg.label+')';
    var deltaEl = document.getElementById('farmKpiDelta');
    if(prevProfit!==0){
      var deltaPct = (curProfit-prevProfit)/Math.abs(prevProfit)*100;
      deltaEl.hidden = false;
      deltaEl.className = 'farm-kpi-delta '+(deltaPct>=0?'up':'down');
      deltaEl.textContent = (deltaPct>=0?'▲ ':'▼ ')+Math.abs(deltaPct).toFixed(1)+'%';
    } else {
      deltaEl.hidden = true;
    }
    var totalCount = sum(cur,'count');
    var avgLineEl = document.getElementById('farmKpiAvgLine');
    if(totalCount>0){
      var avgPerSession = curProfit/totalCount;
      avgLineEl.textContent = 'เฉลี่ย/กั้ม: '+(avgPerSession<0?'-':'')+fmtNum(Math.abs(avgPerSession))+unit+' ('+totalCount+' กั้ม)';
    } else {
      avgLineEl.textContent = '';
    }
  }

  var FARM_LOSS_COLOR = '#ef5a56';

  function handleFarmChartHover(evt){
    if(!farmChartGeom) return;
    var svg = document.getElementById('farmChartSvg');
    var rect = svg.getBoundingClientRect();
    var relX = ((evt.clientX-rect.left)/rect.width)*farmChartGeom.W;
    var idx = Math.floor((relX-farmChartGeom.padL)/farmChartGeom.slotW);
    idx = Math.max(0, Math.min(farmChartGeom.n-1, idx));

    var layer = document.getElementById('farmChartHoverLayer');
    var slotX = farmChartGeom.xSlot(idx);
    var b = farmChartGeom.buckets[idx];
    var series = FARM_SERIES_KEYS.filter(function(s){ return !hiddenFarmSeries[s]; });
    var svgBits = ['<rect x="'+slotX.toFixed(1)+'" y="'+farmChartGeom.padT+'" width="'+farmChartGeom.slotW.toFixed(1)+'" height="'+(farmChartGeom.H-22-farmChartGeom.padT)+'" fill="rgba(255,255,255,0.05)"/>'];
    var rows = [];
    var hoverUnit = farmUnitSuffix();
    series.forEach(function(s){
      var color = FARM_SERIES_COLOR[s];
      var v = farmBucketVal(b,s);
      rows.push('<div class="ct-row"><span class="ct-key"><span class="ct-swatch" style="background:'+color+'"></span>'+FARM_SERIES_LABEL[s]+'</span><span class="ct-val" style="color:'+color+'">'+fmtNum(v)+hoverUnit+'</span></div>');
    });
    if(b.count>0){
      rows.push('<div class="ct-row"><span class="ct-key">จำนวนกั้ม</span><span class="ct-val">'+b.count+' กั้ม</span></div>');
    }
    if(layer) layer.innerHTML = svgBits.join('');

    var tip = document.getElementById('farmChartTooltip');
    tip.innerHTML = '<span class="ct-time">'+(b.tooltipLabel||b.label)+'</span>'+rows.join('');
    var wrapW = document.getElementById('farmChartWrap').clientWidth;
    var centerX = slotX + farmChartGeom.slotW/2;
    var tipLeft = (centerX/farmChartGeom.W)*wrapW + 10;
    if(tipLeft+150>wrapW) tipLeft = (centerX/farmChartGeom.W)*wrapW - 150;
    tip.style.left = Math.max(4, tipLeft)+'px';
    tip.hidden = false;
  }
  function hideFarmChartHover(){
    document.getElementById('farmChartTooltip').hidden = true;
    var layer = document.getElementById('farmChartHoverLayer');
    if(layer) layer.innerHTML = '';
  }

  var farmHistoryPage = 0;
  var farmHistoryRange = 'today';
  // กดซ่อนการ์ดวันไหน = เหลือแสดงแค่ใบล่าสุดของวันนั้น (rows[0] เพราะ sort ใหม่สุดก่อนไว้แล้ว)
  var farmHistoryDayCollapsed = {};
  function resetFarmTimeframes(){
    farmHistoryRange = 'today';
    farmTimeframe = 'today';
    farmHistoryPage = 0;
    var historyRangeEl = document.getElementById('farmHistoryRange');
    var timeframeEl = document.getElementById('farmTimeframeSelect');
    if(historyRangeEl) historyRangeEl.value = 'today';
    if(timeframeEl) timeframeEl.value = 'today';
  }
  var editingFarmId = null;
  var farmEditCostBackup = null;
  var farmOcActive = false;
  var farmOcHintAcknowledged = false;
  var farmRareItemRows = [{ id:uid(), name:'', price:'', qty:'', currency:'zeny' }];
  var FARM_HISTORY_PAGE_SIZE = 5;
  var FARM_HISTORY_PAGE_SIZE_OPTIONS = [5,10,15,20,30];

  function renderFarmHistory(){
    var farmRangeAllowed = !App.profile || hasFarmPlan();
    if(!farmRangeAllowed) farmHistoryRange = 'today';
    lockHistoryRangeSelect(document.getElementById('farmHistoryRange'), farmRangeAllowed);
    renderFreeQuotaNotes();
    var list = document.getElementById('farmHistoryList');
    var pag = document.getElementById('farmHistoryPagination');
    // ประวัติการฟามใช้ TF ชุดเดียวกับกราฟ ไม่ต้องเลือกวันที่เริ่ม-สิ้นสุดเองแล้ว
    var startTs = capStartTsForPlan(tfRangeStartTs(farmHistoryRange), hasFarmPlan());
    var entries = App.farmLog.filter(function(e){
      return e.serverId===App.farmServerId && (startTs===null || e.ts>=startTs);
    });
    entries.sort(function(a,b){ return b.ts-a.ts; });

    // จัดกลุ่มตามวันที่จากรายการทั้งหมดก่อน แล้วค่อยแบ่งหน้าโดยนับเป็น "วัน" (ไม่ใช่นับรายการ)
    var allDayOrder = [], allDayGroups = {};
    entries.forEach(function(e){
      var dk = mrDateStr(new Date(e.ts));
      if(!allDayGroups[dk]){ allDayGroups[dk] = { ts:e.ts, rows:[] }; allDayOrder.push(dk); }
      allDayGroups[dk].rows.push(e);
    });

    var summaryCount = entries.reduce(function(s,e){ return s+(e.count||1); }, 0);
    var summaryProfit = entries.reduce(function(s,e){ return s+e.profit; }, 0);
    var summaryHasRate = entries.some(function(e){ return e.exchangeRate>0; });
    var summaryBaht = entries.reduce(function(s,e){
      return s + (e.exchangeRate>0 ? farmZenyToBaht(e.profit, e.exchangeRate) : 0);
    }, 0);
    var summaryBahtText = summaryHasRate ? '<span style="color:#f3d48e"> = '+(summaryProfit>=0?'+':'')+fmtNum(summaryBaht)+' บ</span>' : '';
    var summaryEl = document.getElementById('farmHistorySummary');
    if(entries.length){
      summaryEl.innerHTML = '<span class="farm-history-summary-count">'+allDayOrder.length+' วัน</span><span class="farm-history-summary-count">'+summaryCount+' กั้ม</span><span class="farm-history-summary-profit '+(summaryProfit>=0?'farm-profit-pos':'farm-profit-neg')+'">กำไรรวม '+(summaryProfit>=0?'+':'')+fmtNum(summaryProfit)+' z</span>'+summaryBahtText;
    } else {
      summaryEl.textContent = '';
    }

    if(!entries.length){
      list.innerHTML = '<p class="mr-empty">ไม่มีประวัติการฟามในช่วงที่เลือกสำหรับเซิร์ฟเวอร์นี้</p>';
      pag.innerHTML = '';
      return;
    }

    var totalPages = Math.max(1, Math.ceil(allDayOrder.length/FARM_HISTORY_PAGE_SIZE));
    if(farmHistoryPage > totalPages-1) farmHistoryPage = totalPages-1;
    if(farmHistoryPage < 0) farmHistoryPage = 0;
    var pageDayKeys = allDayOrder.slice(farmHistoryPage*FARM_HISTORY_PAGE_SIZE, farmHistoryPage*FARM_HISTORY_PAGE_SIZE+FARM_HISTORY_PAGE_SIZE);

    function farmHistoryEntryHtml(e, displayIndex){
      var pos = e.profit>=0;
      var count = e.count || 1;
      var hasRate = e.exchangeRate>0;
      var costBahtText = hasRate ? ' = '+fmtNum(farmZenyToBaht(e.cost, e.exchangeRate))+' บ' : '';
      var profitBahtText = hasRate ? ' = '+(pos?'+':'')+fmtNum(farmZenyToBaht(e.profit, e.exchangeRate))+' บ' : '';
      var earnedBahtText = hasRate ? ' = '+fmtNum(farmZenyToBaht(e.earned, e.exchangeRate))+' บ' : '';
      var avgProfit = e.profit / count;
      var avgProfitBahtText = hasRate ? ' = '+(pos?'+':'')+fmtNum(farmZenyToBaht(avgProfit, e.exchangeRate))+' บ' : '';
      var mapChip = e.mapName ? '<span class="farm-history-chip farm-history-map">Map: '+escapeHtml(e.mapName)+'</span>' : '';
      var rareTag = (e.rareItems||[]).filter(function(r){ return r.name; }).map(function(r){
        var qtySuffix = r.qty>1 ? ' x'+r.qty : '';
        var rareUnit = (r.currency||'zeny')==='baht' ? 'บ' : 'z';
        return r.price
          ? '<span class="farm-rare-tag sold">🎁 '+escapeHtml(r.name)+qtySuffix+' +'+fmtNum(r.price*r.qty)+' '+rareUnit+'</span>'
          : '<span class="farm-rare-tag pending">🎁 '+escapeHtml(r.name)+qtySuffix+' (รอขาย)</span>';
      }).join('');
      return '<div class="mr-entry farm-history-entry farm-history-alt-'+(displayIndex%2===0?'odd':'even')+(e.id===editingFarmId?' editing':'')+'" data-farm-entry-id="'+e.id+'">'+
        '<div class="farm-history-entry-head"><div class="farm-history-meta"><span class="farm-history-time">'+fmtTimeShort(e.ts)+'</span><span class="farm-history-chip farm-history-count">'+count+' กั้ม</span>'+mapChip+'</div>'+
          '<span class="mr-entry-actions farm-history-actions">'+
            '<button type="button" class="mr-edit" data-farm-edit="'+e.id+'" title="แก้ไข">✎</button>'+
            '<button type="button" class="mr-del" data-farm-del="'+e.id+'" title="ลบ">🗑</button>'+
          '</span></div>'+
        '<div class="farm-history-metrics">'+
          '<div class="farm-history-metric farm-history-revenue"><span>รายได้</span><b class="farm-income-hover" data-farm-income-id="'+e.id+'">'+fmtNum(e.earned)+' z</b><small>'+earnedBahtText+'</small></div>'+
          '<div class="farm-history-metric farm-history-cost"><span>ต้นทุน</span><b class="farm-cost-hover" style="color:var(--danger)" data-farm-cost-id="'+e.id+'">'+fmtNum(e.cost)+' z</b><small style="color:var(--danger)">'+costBahtText+'</small></div>'+
          '<div class="farm-history-metric '+(pos?'farm-profit-pos':'farm-profit-neg')+'"><span>กำไร</span><b class="farm-profit-hover" data-farm-profit-id="'+e.id+'">'+(pos?'+':'')+fmtNum(e.profit)+' z</b><small style="color:#f3d48e">'+profitBahtText+'</small></div>'+
        '</div>'+
        '<div class="farm-history-earned"><span>เฉลี่ย 1 กั้ม</span><b style="color:var(--'+(pos?'success':'danger')+')">'+(pos?'+':'')+fmtNum(avgProfit)+' z</b><small style="color:#f3d48e">'+avgProfitBahtText+'</small></div>'+
        (rareTag ? '<div class="farm-history-rares"><span>ไอเทม</span><div>'+rareTag+'</div></div>' : '')+
      '</div>';
    }

    list.innerHTML = pageDayKeys.map(function(dk, dayIndexInPage){
      var grp = allDayGroups[dk];
      var globalDayIndex = farmHistoryPage*FARM_HISTORY_PAGE_SIZE + dayIndexInPage;
      var dayGamCount = grp.rows.reduce(function(s,e){ return s+(e.count||1); }, 0);
      var dayProfit = grp.rows.reduce(function(s,e){ return s+e.profit; }, 0);
      var dayHasRate = grp.rows.some(function(e){ return e.exchangeRate>0; });
      var dayBaht = grp.rows.reduce(function(s,e){ return s+(e.exchangeRate>0 ? farmZenyToBaht(e.profit, e.exchangeRate) : 0); }, 0);
      var dayBahtText = dayHasRate ? ' <small style="color:#f3d48e">= '+(dayProfit>=0?'+':'')+fmtNum(dayBaht)+' บ</small>' : '';
      // สลับสีการ์ดตามวันที่ (ทุกใบในวันเดียวกันใช้สีเดียวกัน) แทนที่จะสลับทีละใบ
      var collapsed = farmHistoryDayCollapsed.hasOwnProperty(dk) ? farmHistoryDayCollapsed[dk] : true;
      var rowsToShow = collapsed ? [grp.rows[0]] : grp.rows;
      var hiddenCount = grp.rows.length - rowsToShow.length;
      var entriesHtml = rowsToShow.map(function(e){
        return farmHistoryEntryHtml(e, globalDayIndex);
      }).join('');
      var toggleBtn = grp.rows.length>1
        ? '<button type="button" class="farm-history-day-toggle" data-farm-day-toggle="'+encodeURIComponent(dk)+'">'+(collapsed?'แสดงทั้งหมด':'ซ่อน')+'</button>'
        : '';
      return '<div class="farm-history-day">'+
        '<div class="farm-history-day-head"><span>'+historyDayLabel(grp.ts)+'</span><span class="farm-history-day-count">'+grp.rows.length+' รายการ</span><span class="farm-history-day-count">'+dayGamCount+' กั้ม</span>'+
        '<span class="farm-history-day-total '+(dayProfit>=0?'farm-profit-pos':'farm-profit-neg')+'">กำไรรวม '+(dayProfit>=0?'+':'')+fmtNum(dayProfit)+' z'+dayBahtText+'</span>'+toggleBtn+'</div>'+
        (hiddenCount>0 ? '<div class="farm-history-day-hidden-note">ซ่อนอยู่ '+hiddenCount+' รายการ — แสดงเฉพาะรายการล่าสุด</div>' : '')+
        '<div class="farm-history-day-list">'+entriesHtml+'</div>'+
      '</div>';
    }).join('');

    var sizeSelectHtml = '<div class="farm-hist-size"><label for="farmHistPageSize">แสดง</label><select id="farmHistPageSize">'+
      FARM_HISTORY_PAGE_SIZE_OPTIONS.map(function(n){ return '<option value="'+n+'"'+(n===FARM_HISTORY_PAGE_SIZE?' selected':'')+'>'+n+'</option>'; }).join('')+
      '</select><span>วัน</span></div>';

    if(totalPages>1){
      pag.innerHTML = sizeSelectHtml+
        '<div class="farm-hist-nav">'+
        '<button type="button" class="farm-hist-page-btn" id="farmHistPrev"'+(farmHistoryPage===0?' disabled':'')+'>‹ ก่อนหน้า</button>'+
        '<span class="farm-hist-page-info">หน้า '+(farmHistoryPage+1)+' / '+totalPages+'</span>'+
        '<button type="button" class="farm-hist-page-btn" id="farmHistNext"'+(farmHistoryPage>=totalPages-1?' disabled':'')+'>ถัดไป ›</button>'+
        '</div>';
    } else {
      pag.innerHTML = sizeSelectHtml;
    }
  }

  function showFarmCostTooltip(el){
    var id = el.dataset.farmCostId;
    var entry = App.farmLog.filter(function(x){ return x.id===id; })[0];
    var tip = document.getElementById('farmCostTooltip');
    if(!entry || !entry.costItems || !entry.costItems.length){
      tip.innerHTML = '<span class="ct-time">รายการต้นทุนที่ใช้</span><div class="ct-row"><span class="ct-key">ไม่มีข้อมูลรายละเอียด</span></div>';
    } else {
      var count = entry.count || 1;
      var rows = entry.costItems.map(function(it){
        var price = parseFloat(it.price)||0, qty = parseFloat(it.qty)||0;
        var lineTotal = price*qty;
        var isBaht = (it.currency||'zeny')==='baht';
        var valText;
        if(isBaht){
          valText = fmtNum(lineTotal)+' บ';
          if(entry.exchangeRate>0){
            valText += ' = '+fmtNum((lineTotal/entry.exchangeRate)*1000000)+' z';
          }
        } else {
          valText = fmtNum(lineTotal)+' z';
        }
        return '<div class="ct-row"><span class="ct-key">'+escapeHtml(it.name||'-')+'</span><span class="ct-val">'+valText+'</span></div>';
      }).join('');
      if(entry.exchangeRate){
        rows += '<div class="ct-row"><span class="ct-key" style="color:var(--text-dim)">เรทที่ใช้ตอนนั้น</span><span class="ct-val" style="color:var(--text-dim)">1M = '+fmtNum(entry.exchangeRate)+'บ</span></div>';
      }
      rows += '<div class="ct-row" style="border-top:1px dashed var(--border);margin-top:.3rem;padding-top:.3rem"><span class="ct-key">รวม/กั้ม × '+count+'</span><span class="ct-val">'+fmtNum(entry.cost)+' z</span></div>';
      tip.innerHTML = '<span class="ct-time">รายการต้นทุนที่ใช้</span>'+rows;
    }
    var rect = el.getBoundingClientRect();
    tip.hidden = false;
    var left = Math.min(rect.left, window.innerWidth - tip.offsetWidth - 12);
    tip.style.left = Math.max(4, left)+'px';
    tip.style.top = (rect.bottom+6)+'px';
  }

  function showFarmProfitTooltip(el){
    var id = el.dataset.farmProfitId;
    var entry = App.farmLog.filter(function(x){ return x.id===id; })[0];
    var tip = document.getElementById('farmCostTooltip');
    if(!entry){
      tip.innerHTML = '<span class="ct-time">ที่มาของกำไร</span><div class="ct-row"><span class="ct-key">ไม่มีข้อมูลรายละเอียด</span></div>';
    } else {
      var hasRate = entry.exchangeRate>0;
      var earnedBase = entry.earnedBase!=null ? entry.earnedBase : entry.earned;
      function bahtSuffix(z){ return hasRate ? ' (= '+fmtNum(farmZenyToBaht(z, entry.exchangeRate))+' บ)' : ''; }
      var rows = '<div class="ct-row"><span class="ct-key">ฟามได้ (พื้นฐาน)</span><span class="ct-val" style="color:var(--success)">+'+fmtNum(earnedBase)+' z'+bahtSuffix(earnedBase)+'</span></div>';
      (entry.rareItems||[]).filter(function(r){ return r.name && r.price; }).forEach(function(r){
        var rareTotal = r.price*r.qty;
        var isRareBaht = (r.currency||'zeny')==='baht';
        var rareValText = isRareBaht
          ? '+'+fmtNum(rareTotal)+' บ'+(hasRate ? ' (= '+fmtNum(farmBahtToZeny(rareTotal, entry.exchangeRate))+' z)' : '')
          : '+'+fmtNum(rareTotal)+' z'+bahtSuffix(rareTotal);
        rows += '<div class="ct-row"><span class="ct-key">🎁 '+escapeHtml(r.name)+(r.qty>1?' x'+r.qty:'')+'</span><span class="ct-val" style="color:var(--success)">'+rareValText+'</span></div>';
      });
      rows += '<div class="ct-row"><span class="ct-key">ต้นทุน</span><span class="ct-val" style="color:var(--danger)">-'+fmtNum(entry.cost)+' z'+bahtSuffix(entry.cost)+'</span></div>';
      if(hasRate){
        rows += '<div class="ct-row"><span class="ct-key" style="color:var(--text-dim)">เรทที่ใช้ตอนนั้น</span><span class="ct-val" style="color:var(--text-dim)">1M = '+fmtNum(entry.exchangeRate)+'บ</span></div>';
      }
      var pos = entry.profit>=0;
      rows += '<div class="ct-row" style="border-top:1px dashed var(--border);margin-top:.3rem;padding-top:.3rem"><span class="ct-key">กำไรสุทธิ</span><span class="ct-val" style="color:'+(pos?'var(--success)':'var(--danger)')+'">'+(pos?'+':'')+fmtNum(entry.profit)+' z'+bahtSuffix(entry.profit)+'</span></div>';
      tip.innerHTML = '<span class="ct-time">ที่มาของกำไร</span>'+rows;
    }
    var rect = el.getBoundingClientRect();
    tip.hidden = false;
    var left = Math.min(rect.left, window.innerWidth - tip.offsetWidth - 12);
    tip.style.left = Math.max(4, left)+'px';
    tip.style.top = (rect.bottom+6)+'px';
  }

  function showFarmIncomeTooltip(el){
    var id = el.dataset.farmIncomeId;
    var entry = App.farmLog.filter(function(x){ return x.id===id; })[0];
    var tip = document.getElementById('farmCostTooltip');
    if(!entry){
      tip.innerHTML = '<span class="ct-time">ที่มาของรายได้</span><div class="ct-row"><span class="ct-key">ไม่มีข้อมูลรายละเอียด</span></div>';
    } else {
      var hasRate = entry.exchangeRate>0;
      var earnedBase = entry.earnedBase!=null ? entry.earnedBase : entry.earned;
      function bahtSuffix(z){ return hasRate ? ' (= '+fmtNum(farmZenyToBaht(z, entry.exchangeRate))+' บ)' : ''; }
      var rows = '<div class="ct-row"><span class="ct-key">ฟามได้ (พื้นฐาน)</span><span class="ct-val" style="color:var(--success)">+'+fmtNum(earnedBase)+' z'+bahtSuffix(earnedBase)+'</span></div>';
      (entry.rareItems||[]).filter(function(r){ return r.name && r.price; }).forEach(function(r){
        var rareTotal = r.price*r.qty;
        var isRareBaht = (r.currency||'zeny')==='baht';
        var rareValText = isRareBaht
          ? '+'+fmtNum(rareTotal)+' บ'+(hasRate ? ' (= '+fmtNum(farmBahtToZeny(rareTotal, entry.exchangeRate))+' z)' : '')
          : '+'+fmtNum(rareTotal)+' z'+bahtSuffix(rareTotal);
        rows += '<div class="ct-row"><span class="ct-key">🎁 '+escapeHtml(r.name)+(r.qty>1?' x'+r.qty:'')+'</span><span class="ct-val" style="color:var(--success)">'+rareValText+'</span></div>';
      });
      if(hasRate){
        rows += '<div class="ct-row"><span class="ct-key" style="color:var(--text-dim)">เรทที่ใช้ตอนนั้น</span><span class="ct-val" style="color:var(--text-dim)">1M = '+fmtNum(entry.exchangeRate)+'บ</span></div>';
      }
      rows += '<div class="ct-row" style="border-top:1px dashed var(--border);margin-top:.3rem;padding-top:.3rem"><span class="ct-key">รวมรายได้</span><span class="ct-val" style="color:var(--success)">+'+fmtNum(entry.earned)+' z'+bahtSuffix(entry.earned)+'</span></div>';
      tip.innerHTML = '<span class="ct-time">ที่มาของรายได้</span>'+rows;
    }
    var rect = el.getBoundingClientRect();
    tip.hidden = false;
    var left = Math.min(rect.left, window.innerWidth - tip.offsetWidth - 12);
    tip.style.left = Math.max(4, left)+'px';
    tip.style.top = (rect.bottom+6)+'px';
  }

  function resetFarmEditState(){
    farmOcHintAcknowledged = false;
    editingFarmId = null;
    farmEditCostBackup = null;
    document.getElementById('farmCancelEdit').hidden = true;
    document.getElementById('farmLogConfirm').textContent = 'บันทึก';
    document.querySelector('.panel-farm-cost').classList.remove('mr-entry-editing');
    document.getElementById('farmCountInput').value = '1';
    document.getElementById('farmEarnedInput').value = '';
    updateFarmEarnedHint();
    farmRareItemRows = [{ id:uid(), name:'', price:'', qty:'', currency:'zeny' }];
    renderFarmRareItems();
    farmOcActive = false;
    document.getElementById('farmOcToggle').classList.remove('active');
  }

  function preserveFarmViewport(x, y){
    window.scrollTo(x, y);
    requestAnimationFrame(function(){ window.scrollTo(x, y); });
  }

  function cancelFarmEdit(){
    var scrollX = window.scrollX, scrollY = window.scrollY;
    if(farmEditCostBackup){
      App.farmCostItems[farmEditCostBackup.serverId] = farmEditCostBackup.rows;
      App.farmExchangeRates[farmEditCostBackup.serverId] = farmEditCostBackup.exchangeRate;
      App.farmMapNames[farmEditCostBackup.serverId] = farmEditCostBackup.mapName;
      saveFarmCostItems();
      saveFarmExchangeRates();
      saveFarmMapNames();
      renderFarmCostItems();
      renderFarmExchangeRate();
      renderFarmMapName();
    }
    resetFarmEditState();
    renderFarmHistory();
    renderFarmChart();
    preserveFarmViewport(scrollX, scrollY);
  }

  function startEditFarmEntry(id){
    var scrollX = window.scrollX, scrollY = window.scrollY;
    var entry = App.farmLog.filter(function(e){ return e.id===id; })[0];
    if(!entry) return;
    farmOcHintAcknowledged = false;
    App.farmServerId = entry.serverId;
    saveFarmServer();
    document.getElementById('farmServerSelect').value = entry.serverId;
    farmEditCostBackup = { serverId: entry.serverId, rows: farmSnapshotCostRows(entry.serverId), exchangeRate: App.farmExchangeRates[entry.serverId], mapName: App.farmMapNames[entry.serverId] };
    if(entry.costItems && entry.costItems.length){
      App.farmCostItems[entry.serverId] = entry.costItems.map(function(r){
        return { id: r.id || uid(), name:r.name, price:r.price, qty:r.qty, currency:r.currency||'zeny' };
      });
      saveFarmCostItems();
    }
    if(entry.exchangeRate!=null){
      App.farmExchangeRates[entry.serverId] = entry.exchangeRate;
      saveFarmExchangeRates();
    }
    App.farmMapNames[entry.serverId] = entry.mapName || '';
    saveFarmMapNames();
    renderFarmExchangeRate();
    renderFarmMapName();
    renderFarmCostItems();
    document.getElementById('farmCountInput').value = entry.count || 1;
    document.getElementById('farmEarnedInput').value = fmtNum(entry.earnedBase!=null ? entry.earnedBase : entry.earned);
    updateFarmEarnedHint();
    farmRareItemRows = (entry.rareItems && entry.rareItems.length)
      ? entry.rareItems.map(function(r){ return { id: r.id || uid(), name:r.name, price:r.price, qty:r.qty, currency:r.currency||'zeny' }; })
      : [{ id:uid(), name:'', price:'', qty:'', currency:'zeny' }];
    renderFarmRareItems();
    farmOcActive = !!entry.ocApplied;
    document.getElementById('farmOcToggle').classList.toggle('active', farmOcActive);
    editingFarmId = id;
    document.getElementById('farmCancelEdit').hidden = false;
    document.getElementById('farmLogConfirm').textContent = 'บันทึกการแก้ไข';
    document.querySelector('.panel-farm-cost').classList.add('mr-entry-editing');
    renderFarmChart();
    farmHistoryPage = 0;
    renderFarmHistory();
    preserveFarmViewport(scrollX, scrollY);
  }

  function renderFarmPage(){
    if(!App.session || !App.session.id) return;
    populateFarmServerSelect();
    renderFarmExchangeRate();
    renderFarmMapName();
    renderFarmCostItems();
    renderFarmRareItems();
    renderFarmChart();
    document.getElementById('farmHistoryRange').value = farmHistoryRange;
    document.getElementById('farmTimeframeSelect').value = farmTimeframe;
    renderFarmHistory();
    renderFarmRetiredState();
  }

  // เซิร์ฟที่ไม่ได้อยู่ใน "เซิร์ฟเวอร์ที่เล่น" แล้ว = ดูย้อนหลังได้ แต่กรอก/บันทึกอะไรใหม่ไม่ได้
  // ปิดทุกช่องกรอกในการ์ด "ต้นทุนต่อกั้ม" ทิ้ง แล้วขึ้นป้ายบอกเหตุผล
  // (เรียกท้าย renderFarmPage เสมอ เพราะ renderFarmCostItems วาดปุ่ม/ช่องใหม่ทุกครั้ง)
  function renderFarmRetiredState(){
    var panel = document.querySelector('.panel-farm-cost');
    if(!panel) return;
    var retired = isRetiredServer(App.farmServerId);
    panel.classList.toggle('server-retired', retired);
    panel.querySelectorAll('input, select, textarea, button').forEach(function(el){
      if(retired) el.setAttribute('disabled','');
      else el.removeAttribute('disabled');
    });
    var note = document.getElementById('farmRetiredNote');
    if(note) note.hidden = !retired;
  }

  function renderMrChart(){
    hideMrChartHover();
    populateMrChartServerSelect();
    var svg = document.getElementById('mrChartSvg');
    var buckets = mrChartBuckets(mrChartTimeframe, mrChartServerId, 0, mrChartCategoryFilter);
    var series = MR_CHART_SERIES_KEYS.filter(function(s){ return !hiddenMrChartSeries[s]; });
    var W=640, H=220, padL=52, padR=8, padT=10, padB=22;
    var plotW = W-padL-padR, plotH = H-padT-padB;
    var n = buckets.length;

    var allVals = [0];
    series.forEach(function(s){ buckets.forEach(function(b){ allVals.push(b[s]); }); });
    var rawMin = Math.min.apply(null, allVals), rawMax = Math.max.apply(null, allVals);
    var step = niceStep((rawMax-rawMin)/4 || rawMax*0.1 || 1);
    var yMin = Math.floor(rawMin/step)*step;
    var yMax = Math.ceil(rawMax/step)*step;
    if(yMax===yMin) yMax = yMin+step;

    var slotW = plotW/n;
    function xSlot(i){ return padL + i*slotW; }
    function yAt(v){ return padT + plotH - ((v-yMin)/(yMax-yMin))*plotH; }
    var y0 = yAt(0);

    var parts = [];
    var gridCount = (yMax-yMin)/step;
    for(var g=0; g<=gridCount; g++){
      var gv = yMin + g*step, gy = yAt(gv);
      parts.push('<line x1="'+padL+'" y1="'+gy+'" x2="'+(W-padR)+'" y2="'+gy+'" stroke="#262832" stroke-width="1"/>');
      parts.push('<text x="'+(padL-6)+'" y="'+(gy+3)+'" text-anchor="end" font-size="9" fill="#8b8d98">'+fmtNum(gv)+'</text>');
    }
    var everyN = Math.max(1, Math.ceil(n/8));
    for(var i=0;i<n;i+=everyN){
      parts.push('<text x="'+(xSlot(i)+slotW/2)+'" y="'+(H-6)+'" text-anchor="middle" font-size="9" fill="#8b8d98">'+buckets[i].label+'</text>');
    }
    if(!App.merchantLog.some(function(e){ return (mrChartServerId==='all' || e.serverId===mrChartServerId) && (mrChartCategoryFilter==='all' || (e.category||'zeny')===mrChartCategoryFilter); })){
      var chartEmpty = document.querySelector('#view-home .dashboard-chart-empty');
      chartEmpty.hidden = false;
      chartEmpty.innerHTML = '<strong>'+(App.isGuest ? 'เข้าสู่ระบบเพื่อดูกราฟของคุณ' : 'ยังไม่มีข้อมูลสำหรับกราฟนี้')+'</strong><span>'+(App.isGuest ? 'กราฟจะแสดงจากรายการซื้อ–ขายที่บันทึกไว้ในบัญชี' : 'ตรวจสอบเซิร์ฟเวอร์และหมวดหมู่ หรือเริ่มบันทึกในฟอร์มซื้อ–ขาย')+'</span>';
    } else {
      document.querySelector('#view-home .dashboard-chart-empty').hidden = true;
      var groupPad = n<=1 ? 0.32 : 0.16;
      var groupW = slotW*(1-groupPad*2);
      var barGap = groupW*0.08;
      var barW = (groupW - barGap*(series.length-1))/Math.max(series.length,1);
      buckets.forEach(function(b,i){
        var groupX = xSlot(i) + slotW*groupPad;
        series.forEach(function(s, si){
          var bx = groupX + si*(barW+barGap);
          var v = b[s];
          var y1 = yAt(v), y2 = y0;
          var top = Math.min(y1,y2), h = Math.max(Math.abs(y1-y2), 1);
          parts.push('<rect x="'+bx.toFixed(1)+'" y="'+top.toFixed(1)+'" width="'+barW.toFixed(1)+'" height="'+h.toFixed(1)+'" rx="2" fill="'+MR_CHART_SERIES_COLOR[s]+'"/>');
        });
      });
    }
    if(yMin<0){
      parts.push('<line x1="'+padL+'" y1="'+y0.toFixed(1)+'" x2="'+(W-padR)+'" y2="'+y0.toFixed(1)+'" stroke="#3a3c48" stroke-width="1"/>');
    }
    parts.push('<g id="mrChartHoverLayer"></g>');
    svg.setAttribute('viewBox','0 0 '+W+' '+H);
    svg.innerHTML = parts.join('');

    mrChartGeom = { W:W, H:H, padL:padL, plotW:plotW, padT:padT, n:n, slotW:slotW, xSlot:xSlot, yAt:yAt, buckets:buckets };
    renderMrChartLegend(buckets);
    renderMrSeriesFilter();
    renderMrKpi();
  }

  function renderMrChartLegend(buckets){
    var el = document.getElementById('mrChartLegend');
    var totals = { sell:0, buy:0, profit:0 };
    buckets.forEach(function(b){ totals.sell+=b.sell; totals.buy+=b.buy; totals.profit+=b.profit; });
    var row = MR_CHART_SERIES_KEYS.map(function(s){
      var off = hiddenMrChartSeries[s];
      return '<button type="button" class="chart-legend-item chart-legend-dir'+(off?' off':'')+'" data-mr-chart-legend="'+s+'">'+
        '<span class="cl-dot" style="background:'+MR_CHART_SERIES_COLOR[s]+'"></span>'+MR_CHART_SERIES_LABEL[s]+
        ' <b style="color:'+MR_CHART_SERIES_COLOR[s]+'">'+fmtNum(totals[s])+' บ</b></button>';
    }).join('');
    el.innerHTML = '<div class="chart-legend-row">'+row+'</div>';
  }

  function renderMrSeriesFilter(){
    var shown = MR_CHART_SERIES_KEYS.filter(function(s){ return !hiddenMrChartSeries[s]; });
    var hidden = MR_CHART_SERIES_KEYS.filter(function(s){ return hiddenMrChartSeries[s]; });
    document.getElementById('mrSeriesChips').innerHTML = shown.map(function(s){
      var color = MR_CHART_SERIES_COLOR[s];
      return '<span class="farm-series-chip" style="background:color-mix(in srgb, '+color+' 20%, transparent)">'+
        '<span class="cl-dot" style="background:'+color+'"></span>'+MR_CHART_SERIES_LABEL[s]+
        '<button type="button" class="farm-series-chip-x" data-mr-legend-remove="'+s+'">✕</button></span>';
    }).join('');
    var dropdownBtn = document.getElementById('mrSeriesDropdownBtn');
    dropdownBtn.hidden = !hidden.length;
    var dropdown = document.getElementById('mrSeriesDropdown');
    dropdown.innerHTML = hidden.map(function(s){
      var color = MR_CHART_SERIES_COLOR[s];
      return '<button type="button" class="farm-series-dropdown-item" data-mr-legend-add="'+s+'"><span class="cl-dot" style="background:'+color+'"></span>'+MR_CHART_SERIES_LABEL[s]+'</button>';
    }).join('') || '<span class="farm-series-dropdown-empty">แสดงครบทุกรายการแล้ว</span>';
  }

  function renderMrKpi(){
    var cfg = mrChartCfg(mrChartTimeframe, mrChartServerId, mrChartCategoryFilter);
    var cur = mrChartBuckets(mrChartTimeframe, mrChartServerId, 0, mrChartCategoryFilter);
    var prev = mrChartBuckets(mrChartTimeframe, mrChartServerId, 1, mrChartCategoryFilter);
    function sum(arr,k){ return arr.reduce(function(s,b){ return s+b[k]; }, 0); }
    var curProfit = sum(cur,'profit');
    var prevProfit = sum(prev,'profit');
    var valueEl = document.getElementById('mrKpiValue');
    valueEl.textContent = (curProfit<0?'-':'')+fmtNum(Math.abs(curProfit))+' บ';
    valueEl.style.color = curProfit>=0 ? MR_CHART_SERIES_COLOR.profit : MR_LOSS_COLOR;
    document.getElementById('mrKpiPeriod').textContent = '('+cfg.label+')';
    var deltaEl = document.getElementById('mrKpiDelta');
    if(prevProfit!==0){
      var deltaPct = (curProfit-prevProfit)/Math.abs(prevProfit)*100;
      deltaEl.hidden = false;
      deltaEl.className = 'farm-kpi-delta '+(deltaPct>=0?'up':'down');
      deltaEl.textContent = (deltaPct>=0?'▲ ':'▼ ')+Math.abs(deltaPct).toFixed(1)+'%';
    } else {
      deltaEl.hidden = true;
    }
  }

  function handleMrChartHover(evt){
    if(!mrChartGeom) return;
    var svg = document.getElementById('mrChartSvg');
    var rect = svg.getBoundingClientRect();
    var relX = ((evt.clientX-rect.left)/rect.width)*mrChartGeom.W;
    var idx = Math.floor((relX-mrChartGeom.padL)/mrChartGeom.slotW);
    idx = Math.max(0, Math.min(mrChartGeom.n-1, idx));

    var layer = document.getElementById('mrChartHoverLayer');
    var slotX = mrChartGeom.xSlot(idx);
    var b = mrChartGeom.buckets[idx];
    var svgBits = ['<rect x="'+slotX.toFixed(1)+'" y="'+mrChartGeom.padT+'" width="'+mrChartGeom.slotW.toFixed(1)+'" height="'+(mrChartGeom.H-22-mrChartGeom.padT)+'" fill="rgba(255,255,255,0.05)"/>'];
    if(layer) layer.innerHTML = svgBits.join('');

    var series = MR_CHART_SERIES_KEYS.filter(function(s){ return !hiddenMrChartSeries[s]; });
    var rows = series.map(function(s){
      var color = MR_CHART_SERIES_COLOR[s];
      var v = b[s];
      return '<div class="ct-row"><span class="ct-key"><span class="ct-swatch" style="background:'+color+'"></span>'+MR_CHART_SERIES_LABEL[s]+'</span><span class="ct-val" style="color:'+color+'">'+fmtNum(v)+' บ</span></div>';
    });
    var tip = document.getElementById('mrChartTooltip');
    tip.innerHTML = '<span class="ct-time">'+(b.tooltipLabel||b.label)+'</span>'+rows.join('');
    var wrapW = document.getElementById('mrChartWrap').clientWidth;
    var centerX = slotX + mrChartGeom.slotW/2;
    var tipLeft = (centerX/mrChartGeom.W)*wrapW + 10;
    if(tipLeft+150>wrapW) tipLeft = (centerX/mrChartGeom.W)*wrapW - 150;
    tip.style.left = Math.max(4, tipLeft)+'px';
    tip.hidden = false;
  }
  function hideMrChartHover(){
    document.getElementById('mrChartTooltip').hidden = true;
    var layer = document.getElementById('mrChartHoverLayer');
    if(layer) layer.innerHTML = '';
  }

  function fmtNum(n){
    return Number(n||0).toLocaleString('th-TH', { maximumFractionDigits:2 });
  }

  function renderMerchantServers(){
    var chips = document.getElementById('mrServerChips');
    chips.innerHTML = App.merchantServers.map(function(id){
      var sv = serverRateById(id);
      var selected = id === App.currentServerId;
      return '<span class="chip chip-server'+(selected?' selected':'')+'" data-select-server="'+id+'">'+(sv?sv.name:id)+'</span>';
    }).join('');
  }

  function selectMerchantServer(id){
    App.currentServerId = id;
    saveCurrentServer();
    renderMerchantServers();
    renderMrExchangeRate();
    // A stock pick belongs to the server it was picked under — drop the picked batch on
    // server switch rather than risk selling something from the wrong server's warehouse.
    // Selling an Item is always "จากคลัง" now, so fromStock itself stays true — only the
    // specific batch selection is cleared, ready to re-pick from the new server's stock.
    [App.zenyRows, App.itemRows, App.otherRows].forEach(function(rows){
      (rows||[]).forEach(function(row){ if(row.stockGroupKey){ row.stockGroupKey = null; row.stockGroup = null; } });
    });
    renderItemRows();
    // เลือกเซิร์ฟที่กล่องซื้อ-ขาย = ให้ "ประวัติ" กับกราฟกำไรเปลี่ยนตามไปด้วย
    // จะได้ดูตัวเลขของเซิร์ฟที่กำลังบันทึกอยู่ ไม่ต้องไปไล่เปลี่ยน dropdown ทีละอัน
    historyState.serverId = id;
    historyState.userChangedServer = true;
    resetMerchantHistoryRange();
    mrChartServerId = id;
    mrChartServerUserChanged = true;
    renderMerchantHistory();
    renderMrChart();
  }

  function renderMrExchangeRate(){
    var input = document.getElementById('mrExRateInput');
    var v = App.merchantExchangeRates[App.currentServerId];
    input.value = v!=null && v!=='' ? Number(v).toLocaleString('th-TH') : '';
    input.classList.remove('farm-exrate-invalid');
    document.getElementById('mrExRateError').hidden = true;
  }

  function newItemRow(name, price, qty, currency, slots, lineId){
    // fromStock defaults true — selling an Item only ever works "จากคลัง" now (the
    // manual/stock toggle was removed), so a fresh row is always ready to show the
    // เลือกรายการในคลัง dropdown the moment it's a sell-Item row. It's a no-op for any
    // other type/category, since only sellFromStockAvailable (sell + item) reads it.
    return { rid: uid(), lineId: lineId||null, name: name||'', price: price!=null?price:'', qty: qty!=null?qty:'', currency: currency==='zeny'?'zeny':'baht', slots: slots||[],
      fromStock:true, stockGroupKey:null, stockGroup:null };
  }

  function cleanDecimalInput(value){
    var cleaned = value.replace(/[^\d.]/g,'');
    var firstDot = cleaned.indexOf('.');
    if(firstDot!==-1){
      cleaned = cleaned.slice(0,firstDot+1) + cleaned.slice(firstDot+1).replace(/\./g,'').slice(0,2);
    }
    return cleaned;
  }
  function formatDecimalDisplay(raw){
    raw = String(raw==null?'':raw);
    if(!raw) return '';
    var hasDot = raw.indexOf('.') !== -1;
    var parts = raw.split('.');
    var intPart = parts[0] || '';
    var decPart = hasDot ? (parts[1]||'').slice(0,2) : '';
    var intFormatted = intPart ? Number(intPart).toLocaleString('th-TH') : (hasDot ? '0' : '');
    return intFormatted + (hasDot ? '.'+decPart : '');
  }

  function defaultRowCurrency(){ return 'baht'; }
  // A fresh M row always carries the fixed, locked name — never blank, never user-typed.
  // `price` is optional — passed in when carrying the last-used ราคา (เรท) forward after a save.
  function newZenyRow(price){ return newItemRow(ZENY_LABEL, price!=null&&price!=='' ? price : null, null, 'baht'); }

  // How much M is currently on hand for this server — ซื้อมาทั้งหมด minus ขายไปทั้งหมด,
  // across every M entry ever logged (not just what's on screen in ประวัติ). Shown right
  // on the buy-sell form itself so there's no need to go check ประวัติ first to know how
  // much is left before recording a new M trade.
  function computeZenyRemaining(serverId){
    if(!serverId) return 0;
    var buyQty = 0, sellQty = 0;
    App.merchantLog.forEach(function(e){
      if(e.serverId!==serverId || (e.category||'zeny')!=='zeny') return;
      var qty = (e.lines||[]).reduce(function(s,l){ return s+(parseFloat(l.qty)||0); }, 0);
      if(entryType(e)==='buy') buyQty += qty; else sellQty += qty;
    });
    return buyQty - sellQty;
  }
  function activeRows(){
    if(App.merchantCategory==='zeny') return App.zenyRows;
    if(App.merchantCategory==='other') return App.otherRows;
    return App.itemRows;
  }
  function setActiveRows(rows){
    if(App.merchantCategory==='zeny') App.zenyRows = rows;
    else if(App.merchantCategory==='other') App.otherRows = rows;
    else App.itemRows = rows;
  }
  function lineCurrency(l){ return l && l.currency==='zeny' ? 'zeny' : 'baht'; }
  var CURRENCY_UNIT_LABEL = { baht:'บ', zeny:'z' };
  // "z"/"(Zeny)" render in the normal text color everywhere, not a highlight color.
  var MR_ZENY_COLOR = 'var(--text)';
  function fmtCurrencyAmount(amount, currency){
    var unit = CURRENCY_UNIT_LABEL[currency==='zeny'?'zeny':'baht'];
    if(currency==='zeny') unit = '<span style="color:'+MR_ZENY_COLOR+'">'+unit+'</span>';
    return fmtNum(amount)+' '+unit;
  }
  // "(Zeny)" tag shown after an item's name wherever it was bought/sold using Zeny as
  // the payment currency (Item/อื่นๆ lines only — M lines already mean Zeny itself).
  function zenyNameTag(){
    return ' <span style="color:'+MR_ZENY_COLOR+'">(Zeny)</span>';
  }
  function entryTotals(e){
    // entries saved before per-line currency existed only ever had baht amounts
    if(e.totalBaht==null && e.totalZeny==null) return { baht: e.total||0, zeny: 0 };
    return { baht: e.totalBaht||0, zeny: e.totalZeny||0 };
  }
  function entryBahtEquivalent(e){
    var t = entryTotals(e);
    if(!t.zeny || !(e.exchangeRate>0)) return null;
    return t.baht + farmZenyToBaht(t.zeny, e.exchangeRate);
  }
  function fmtEntryTotal(e){
    var t = entryTotals(e);
    var parts = [];
    if(t.baht) parts.push(fmtCurrencyAmount(t.baht, 'baht'));
    if(t.zeny) parts.push(fmtCurrencyAmount(t.zeny, 'zeny'));
    var text = parts.length ? parts.join(' + ') : fmtNum(0);
    var bahtEq = entryBahtEquivalent(e);
    if(bahtEq!=null) text += ' = <span class="mr-rate-hover">'+fmtCurrencyAmount(bahtEq, 'baht')+'</span>';
    return text;
  }

  function itemNameChoices(){
    if(App.merchantCategory==='zeny') return []; // M's name is fixed — no suggestions to offer
    return App.merchantItems[App.merchantCategory] || [];
  }

  function itemNameWithSlots(name, slots){
    var hasSlots = slots && slots.length;
    var safeName = escapeHtml(name);
    if(!hasSlots) return '<span class="mr-item-name">'+safeName+'</span>';
    var parts = [];
    slots.forEach(function(s){
      String(s).split(',').forEach(function(p){
        p = p.trim();
        if(p) parts.push(escapeHtml(p));
      });
    });
    if(!parts.length) return '<span class="mr-item-name">'+safeName+'</span>';
    var slotStr = '| '+parts.join(' | ')+' |';
    return '<span class="mr-item-name-slots"><span class="mr-item-name">'+safeName+'</span><span class="mr-item-slots-inline"> : '+slotStr+'</span></span>';
  }

  function renderItemRows(){
    var root = document.getElementById('mrItemRows');
    var rows = activeRows();
    var isZenyTab = App.merchantCategory === 'zeny';
    // M trades are always priced in real baht — normalize away any stale zeny-currency row.
    if(isZenyTab) rows.forEach(function(row){ row.currency = 'baht'; });
    var removable = rows.length > 1;
    var showSlots = App.merchantCategory === 'item';
    var sellFromStockAvailable = App.merchantType==='sell' && App.merchantCategory==='item' && App.currentServerId;
    var stockGroups = sellFromStockAvailable ? sellableGroupsFor(App.currentServerId, App.merchantCategory) : [];
    root.innerHTML = rows.map(function(row, rowIdx){
      var slots = row.slots || [];
      var fromStock = sellFromStockAvailable; // selling an Item is always "จากคลัง" — no manual/stock toggle to choose between
      var lockFields = fromStock && row.stockGroupKey;
      var slotsHtml = '';
      if(showSlots && !lockFields){
        slotsHtml = '<div class="mr-slot-section">'+
          slots.map(function(slot, idx){
            return '<div class="mr-slot-row">'+
              '<input type="text" class="mr-slot-input" maxlength="120" data-slot-idx="'+idx+'" placeholder="เช่น : C.ไข่หมุน, Aspd+1, Dex+5, โจมไกล5%" value="'+String(slot||'').replace(/"/g,'&quot;')+'">'+
              '<button type="button" class="mr-slot-remove" data-remove-slot="'+idx+'" title="ลบ Slot">✕</button>'+
            '</div>';
          }).join('')+
          '<button type="button" class="mr-slot-add">+ เพิ่ม Slot</button>'+
        '</div>';
      } else if(lockFields && slots.length){
        var lockedSlotParts = [];
        slots.forEach(function(s){ String(s).split(',').forEach(function(p){ p=p.trim(); if(p) lockedSlotParts.push(p); }); });
        slotsHtml = lockedSlotParts.length ? '<div class="mr-slot-section mr-slot-section-locked">Slot: '+escapeHtml(lockedSlotParts.join(' | '))+'</div>' : '';
      }
      var currencyOptionsHtml = isZenyTab
        ? '<option value="baht" selected>บาท</option>'
        : '<option value="baht"'+(row.currency!=='zeny'?' selected':'')+'>บาท</option>'+
          '<option value="zeny"'+(row.currency==='zeny'?' selected':'')+'>Zeny</option>';
      var sellSourceHtml = '';
      if(sellFromStockAvailable){
        // No more manual-vs-stock toggle — selling an Item always means picking a batch
        // from the warehouse, so the dropdown is the only thing here now.
        var opts = '<option value="">— เลือกรายการในคลัง —</option>'+stockGroups.map(function(g){
          var unit = g.currency==='zeny' ? 'z' : 'บ';
          var label = '['+itemTierLabel(g.tier)+'] ' + g.name + (g.slots&&g.slots.length ? ' : '+g.slots.join(' | ') : '') + ' — คงเหลือ '+fmtNum(g.qty)+' ชิ้น (ราคาซื้อ '+fmtNum(g.price)+' '+unit+')';
          return '<option value="'+escapeHtml(g.key)+'"'+(row.stockGroupKey===g.key?' selected':'')+'>'+escapeHtml(label)+'</option>';
        }).join('');
        sellSourceHtml = '<div class="mr-sell-source">'+
          '<label class="mr-entry-field">เลือกไอเทมจากคลัง<select class="mr-stock-select" data-row-id="'+row.rid+'">'+opts+'</select></label>';
        if(row.stockGroupKey){
          // Read the live group (not the row's own cached snapshot) so a restore/undo
          // elsewhere that touches this same batch shows up here immediately.
          var liveItemGroup = stockGroups.filter(function(g){ return g.key===row.stockGroupKey; })[0];
          if(liveItemGroup) sellSourceHtml += '<div class="mr-stock-info">คงเหลือในคลัง: '+fmtNum(liveItemGroup.qty)+' ชิ้น</div>';
        }
        sellSourceHtml += '</div>';
      }
      // M has no warehouse card of its own — show "คงเหลือ" (bought minus sold so far,
      // this server) right on the row instead, so it's visible before recording a trade
      // without having to go check ประวัติ first.
      var zenyRemainingHtml = '';
      if(isZenyTab && App.currentServerId){
        var remaining = computeZenyRemaining(App.currentServerId);
        zenyRemainingHtml = remaining>=0
          ? '<div class="mr-stock-info">คงเหลือตอนนี้: <strong>'+fmtNum(remaining)+' M</strong></div>'
          : '<div class="mr-stock-info mr-stock-info-warn">ขายเกินที่มี: '+fmtNum(-remaining)+' M</div>';
      }
      return '<div class="mr-item-row" data-row-id="'+row.rid+'">'+
        sellSourceHtml+
        '<div class="mr-item-row-main">'+
          '<label class="mr-entry-field mr-entry-name"><span>'+(App.merchantCategory==='other'?'รายละเอียดรายการ':'ชื่อไอเทม')+'</span><div class="mr-name-wrap">'+
            '<span class="mr-row-index">'+(rowIdx+1)+'.</span>'+
            (isZenyTab
              ? '<input type="text" class="mr-row-name" autocomplete="off" readonly value="'+ZENY_LABEL+'">'
              : '<input type="text" class="mr-row-name" autocomplete="off" maxlength="120" placeholder="'+(App.merchantCategory==='other'?'เช่น : AirTime, จ้างปั้นตัว, อื่นๆ':'เช่น : +5 บูท (ถ้ามีออฟ+เพิ่มSlot), Card, ปีกทอง, อื่นๆ')+'" value="'+row.name.replace(/"/g,'&quot;')+'">'+
                '<div class="mr-item-suggest" hidden></div>')+
          '</div></label>'+
          '<label class="mr-entry-field mr-entry-qty">'+(isZenyTab?'จำนวน M':showSlots?'จำนวน (ชิ้น)':'จำนวน')+
            '<input type="text" inputmode="decimal" class="mr-row-qty" placeholder="จำนวน" value="'+formatDecimalDisplay(row.qty)+'"></label>'+
          '<label class="mr-entry-field mr-entry-price">'+(isZenyTab?'ราคา / 1 M (บาท)':showSlots?'ราคาต่อชิ้น':'ราคาต่อหน่วย')+
            '<input type="text" inputmode="decimal" class="mr-row-price" placeholder="ราคา" value="'+formatDecimalDisplay(row.price)+'"></label>'+
          // สกุลเงินตอนขาย "ไม่ล็อก" ตามล็อตในคลังอีกต่อไป (เดิมล็อกตามตอนซื้อ) เพราะขายได้จริง
          // อาจได้เป็นคนละสกุลเงินกับตอนซื้อ (เช่น ซื้อด้วย Zeny แต่ขายได้เป็นบาท) — กำไร/ขาดทุน
          // ยังคำนวณถูกต้อง เพราะต้นทุนฝั่งซื้อกับยอดฝั่งขายแปลงเป็นบาทแยกอิสระจากกันอยู่แล้ว
          // (ราคาก็แก้ได้อิสระอยู่แล้วเช่นกัน — ล็อกไว้แค่ชื่อ/Slot เพื่อไม่ให้สับสนว่าขายล็อตไหน)
          '<label class="mr-entry-field mr-entry-currency">สกุลเงิน<select class="mr-row-currency">'+currencyOptionsHtml+'</select></label>'+
          '<button type="button" class="mr-row-remove" aria-label="ลบรายการ" data-remove-row="'+row.rid+'" '+(removable?'':'disabled')+'>✕</button>'+
        '</div>'+
        zenyRemainingHtml+
        '<div class="mr-entry-details"><p class="mr-entry-section-label">'+(showSlots?'รูปภาพ / Slot':'รูปภาพ')+'</p>'+
          '<div class="mr-entry-image">'+rowImageButtonHtml(row, stockGroups)+'<span>ลากรูปภาพไอเทมมาใส่ (ไม่บังคับ)</span></div>'+slotsHtml+'</div>'+
      '</div>';
    }).join('');
    hydrateItemThumbs(root);
    updateMerchantTotal();
    syncMerchantEntryPresentation();
  }

  // Display-only state: never changes row values, totals, validation or persistence.
  function syncMerchantEntryPresentation(){
    var panel = document.getElementById('mrEntryPanel');
    var isM = !!panel.querySelector('#mrCategoryToggle [data-category="zeny"].active');
    var hasZenyCurrency = Array.from(panel.querySelectorAll('.mr-row-currency')).some(function(el){ return el.value==='zeny'; });
    document.getElementById('mrExRateField').hidden = isM || !hasZenyCurrency;
    panel.querySelectorAll('#mrTypeToggle button, #mrCategoryToggle button').forEach(function(button){
      button.setAttribute('aria-pressed', String(button.classList.contains('active')));
    });
  }
  document.getElementById('mrItemRows').addEventListener('change', syncMerchantEntryPresentation);

  // ---------- รูปไอเทม (แนบได้แถวละ 1 รูป ในรายการซื้อ-ขาย) ----------
  // ไฟล์รูปเก็บใน Supabase Storage (bucket ส่วนตัว โฟลเดอร์ = user id) ในประวัติเก็บแค่ path ไว้ที่
  // line.image — ห้ามยัดรูปลง localStorage: จุได้ราว 5MB เต็มเร็ว แล้วประวัติทั้งก้อนจะบันทึกไม่ลงแบบเงียบๆ
  // ขายจากคลังไม่มีรูปของตัวเอง → ยืมรูปของรายการซื้อต้นทางผ่าน warehouseSale.sourceLines ตอนแสดงผล
  var ITEM_IMAGE_BUCKET = 'item-images';
  var ITEM_IMAGE_MAX_SIDE = 1024;                 // ด้านยาวสุดหลังย่อ
  var ITEM_IMAGE_KEEP_ORIGINAL_BYTES = 250*1024;  // รูปเล็กอยู่แล้ว = เก็บไฟล์เดิม ตัวหนังสือในรูปคมกว่า
  var ITEM_IMAGE_MAX_BYTES = 1024*1024;           // ต้องตรงกับ file_size_limit ของ bucket
  var ITEM_IMAGE_ICON = '<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>';
  var itemImageUrlCache = {};   // path -> { url, exp } หรือ { promise } ระหว่างรอลิงก์
  var pendingImageRowId = null; // แถวที่กดปุ่มรูปไว้ รอผู้ใช้เลือกไฟล์

  // ย่อให้ด้านยาวไม่เกิน 1024px แล้วแปลงเป็น WebP (รูป tooltip ในเกมเหลือหลักสิบ KB)
  function prepareItemImage(file){
    return new Promise(function(resolve, reject){
      var src = URL.createObjectURL(file);
      var img = new Image();
      img.onload = function(){
        URL.revokeObjectURL(src);
        var w = img.naturalWidth, h = img.naturalHeight;
        var scale = Math.min(1, ITEM_IMAGE_MAX_SIDE/Math.max(w, h));
        if(scale===1 && file.size<=ITEM_IMAGE_KEEP_ORIGINAL_BYTES && /^image\/(png|jpeg|webp)$/.test(file.type)){
          resolve(file);
          return;
        }
        var canvas = document.createElement('canvas');
        canvas.width = Math.max(1, Math.round(w*scale));
        canvas.height = Math.max(1, Math.round(h*scale));
        var ctx = canvas.getContext('2d');
        ctx.imageSmoothingQuality = 'high';
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        canvas.toBlob(function(blob){
          if(blob && blob.type==='image/webp'){ resolve(blob); return; }
          // เบราว์เซอร์ที่ทำ WebP ไม่ได้จะคืน PNG (ไฟล์ใหญ่) มาแทน — ถอยไปใช้ JPEG
          canvas.toBlob(function(jpg){ if(jpg) resolve(jpg); else reject(new Error('encode')); }, 'image/jpeg', 0.9);
        }, 'image/webp', 0.9);
      };
      img.onerror = function(){ URL.revokeObjectURL(src); reject(new Error('decode')); };
      img.src = src;
    });
  }
  function itemImageExt(type){ return type==='image/png' ? 'png' : (type==='image/jpeg' ? 'jpg' : 'webp'); }

  // ลิงก์ชั่วคราว (1 ชม.) สำหรับเปิดรูปส่วนตัว — จำไว้ใช้ซ้ำ ไม่ขอใหม่ทุกครั้งที่ชี้เมาส์
  function userItemImageUrl(path){
    var c = itemImageUrlCache[path];
    if(c && c.url && c.exp > Date.now()) return Promise.resolve(c.url);
    if(c && c.promise) return c.promise;
    if(!App.session) return Promise.reject(new Error('no-session'));
    var p = supa.storage.from(ITEM_IMAGE_BUCKET).createSignedUrl(path, 3600).then(function(res){
      if(res.error || !res.data || !res.data.signedUrl) throw (res.error || new Error('no-url'));
      itemImageUrlCache[path] = { url: res.data.signedUrl, exp: Date.now() + 50*60000 };
      return res.data.signedUrl;
    });
    itemImageUrlCache[path] = { promise: p };
    p.catch(function(){ delete itemImageUrlCache[path]; });
    return p;
  }
  function hydrateItemThumbs(root){
    (root || document).querySelectorAll('img[data-thumb-path]:not([src])').forEach(function(img){
      userItemImageUrl(img.dataset.thumbPath).then(function(url){ if(img.isConnected) img.src = url; }, function(){});
    });
  }
  function removeItemImages(paths){
    paths = (paths || []).filter(function(p){ return p; });
    if(!paths.length || !App.session) return;
    paths.forEach(function(p){ delete itemImageUrlCache[p]; });
    supa.storage.from(ITEM_IMAGE_BUCKET).remove(paths).then(function(res){
      if(res.error) console.warn('removeItemImages', res.error);
    }, function(err){ console.warn('removeItemImages', err); });
  }
  function uploadRowImages(rows){
    var paths = {}, failed = [];
    return Promise.all(rows.map(function(r){
      var blob = r.imageBlob;
      var path = App.session.id+'/'+uid()+'.'+itemImageExt(blob.type);
      return supa.storage.from(ITEM_IMAGE_BUCKET).upload(path, blob, { contentType: blob.type, cacheControl: '31536000', upsert: false })
        .then(function(res){ if(res.error) throw res.error; paths[r.rid] = path; })
        .catch(function(err){ console.warn('upload item image', err); failed.push(r.rid); });
    })).then(function(){ return { paths: paths, failed: failed }; });
  }

  // รูปของบรรทัดในประวัติ: รูปที่แนบเอง > รูปของรายการซื้อต้นทาง (กรณีขายจากคลัง)
  function lineImagePath(line){
    if(!line) return null;
    if(line.image) return line.image;
    var sources = line.warehouseSale && line.warehouseSale.sourceLines;
    if(sources){
      for(var i=0;i<sources.length;i++){
        var src = sources[i].lineId ? findMerchantLineById(sources[i].lineId) : null;
        if(src && src.line.image) return src.line.image;
      }
    }
    return null;
  }
  function lineImagePathById(lineId){
    var found = lineId ? findMerchantLineById(lineId) : null;
    return found ? lineImagePath(found.line) : null;
  }
  function historyGroupImagePath(g){
    for(var i=0;i<g.tx.length;i++){ var p = lineImagePath(g.tx[i].line); if(p) return p; } // tx เรียงใหม่สุดก่อน
    return null;
  }
  // ล็อตในคลังที่จะถูกขายออกก่อน (เก่าสุด) มีรูปตอนซื้อไหม
  function stockGroupImagePath(g){
    if(!g || !g.records) return null;
    for(var i=0;i<g.records.length;i++){
      var p = lineImagePathById(g.records[i].lineId);
      if(p) return p;
    }
    return null;
  }
  function rowInheritedImagePath(row, stockGroups){
    if(!row.stockGroupKey || !(App.merchantType==='sell' && App.merchantCategory==='item')) return null;
    var g = stockGroups
      ? stockGroups.filter(function(x){ return x.key===row.stockGroupKey; })[0]
      : findSellableGroup(App.currentServerId, App.merchantCategory, row.stockGroupKey);
    return stockGroupImagePath(g || row.stockGroup);
  }
  function rowAcceptsImage(row){ return !row.imageBlob && !row.imageLoading && !rowInheritedImagePath(row); }

  // ไอคอนรูป + พื้นที่ชี้เมาส์ดูรูป ครอบชื่อไอเทม (ไม่มีรูป = คืนชื่อเดิมตามปกติ)
  function itemImageNameHtml(path, nameHtml, plainName){
    if(!path) return nameHtml;
    return '<span class="item-img-hover" data-img-path="'+escapeHtml(path)+'">'+
      '<span class="item-img-ico" data-img-view="'+escapeHtml(path)+'" data-img-name="'+escapeHtml(plainName||'')+'" title="ดูรูปไอเทม">'+ITEM_IMAGE_ICON+'</span>'+
      nameHtml+
    '</span>';
  }

  function rowImageButtonHtml(row, stockGroups){
    if(row.imageLoading) return '<span class="mr-row-img loading" aria-label="กำลังเตรียมรูป"></span>';
    if(row.imagePreviewUrl){
      return '<button type="button" class="mr-row-img has-img" data-row-img="'+row.rid+'" data-img-row="'+row.rid+'" title="ดูรูป / เปลี่ยนรูป" aria-label="ดูรูปที่แนบ"><img src="'+row.imagePreviewUrl+'" alt=""></button>';
    }
    var inherited = rowInheritedImagePath(row, stockGroups);
    if(inherited){
      return '<button type="button" class="mr-row-img has-img inherited" data-row-img="'+row.rid+'" data-img-path="'+escapeHtml(inherited)+'" title="รูปจากตอนบันทึกซื้อ" aria-label="ดูรูปจากตอนบันทึกซื้อ"><img data-thumb-path="'+escapeHtml(inherited)+'" alt=""></button>';
    }
    return '<button type="button" class="mr-row-img empty" data-row-img="'+row.rid+'" title="แนบรูปไอเทมให้แถวนี้" aria-label="แนบรูปไอเทมให้แถวนี้">'+ITEM_IMAGE_ICON+'</button>';
  }

  // ไฟล์แรกไปที่แถวที่ระบุ (ถ้ามี) ที่เหลือไล่ใส่แถวที่ยังไม่มีรูป เต็มแล้วเพิ่มแถวใหม่ให้
  function attachImageFiles(files, targetRowId){
    files = (files || []).filter(function(f){ return f && f.type && f.type.indexOf('image/')===0; });
    if(!files.length){ toast('รองรับเฉพาะไฟล์รูปภาพ'); return; }
    // M มีแถวเดียวตายตัว (ไม่มีปุ่ม +เพิ่มรายการ) — แนบได้แค่ 1 รูป ไม่สร้างแถวใหม่ให้
    if(App.merchantCategory==='zeny') files = files.slice(0, 1);
    var rows = activeRows();
    var targets = [];
    var addedRow = false;
    files.forEach(function(file, i){
      var row = null;
      if(i===0 && targetRowId) row = rows.filter(function(r){ return r.rid===targetRowId; })[0] || null;
      if(!row) row = rows.filter(function(r){ return rowAcceptsImage(r) && targets.indexOf(r)===-1; })[0] || null;
      if(!row){
        if(App.merchantCategory==='zeny') return;
        row = newItemRow(null, null, null, defaultRowCurrency()); rows.push(row); addedRow = true;
      }
      row.imageLoading = true;
      targets.push(row);
      prepareItemImage(file).then(function(blob){
        if(blob.size > ITEM_IMAGE_MAX_BYTES) throw new Error('too-big');
        if(row.imagePreviewUrl) URL.revokeObjectURL(row.imagePreviewUrl);
        row.imageBlob = blob;
        row.imagePreviewUrl = URL.createObjectURL(blob);
      }).catch(function(err){
        toast(err && err.message==='too-big' ? 'รูปใหญ่เกิน 1MB แม้ย่อแล้ว — ลองครอปให้เหลือเฉพาะกรอบไอเทม' : 'เปิดไฟล์รูปนี้ไม่ได้');
      }).then(function(){
        row.imageLoading = false;
        refreshRowImageButton(row);
      });
    });
    if(addedRow) renderItemRows();
    else targets.forEach(refreshRowImageButton);
  }
  // เปลี่ยนแค่ปุ่มรูปของแถวนั้น ไม่วาดทั้งฟอร์มใหม่ (กันเคอร์เซอร์หลุดจากช่องที่กำลังพิมพ์)
  function refreshRowImageButton(row){
    var rowEl = document.querySelector('#mrItemRows .mr-item-row[data-row-id="'+row.rid+'"]');
    var old = rowEl && rowEl.querySelector('.mr-row-img');
    if(!old) return;
    var tmp = document.createElement('div');
    tmp.innerHTML = rowImageButtonHtml(row);
    if(tmp.firstChild) old.parentNode.replaceChild(tmp.firstChild, old);
    hydrateItemThumbs(rowEl);
    syncMerchantEntryPresentation();
  }

  // ---- กล่องรูปที่เด้งตอนชี้เมาส์ ----
  var itemImagePopToken = 0;
  var itemImagePopAnchor = null;
  function itemImageSourceFor(el){
    if(el.dataset.imgRow){
      var row = activeRows().filter(function(r){ return r.rid===el.dataset.imgRow; })[0];
      return row && row.imagePreviewUrl ? Promise.resolve(row.imagePreviewUrl) : Promise.reject(new Error('no-row'));
    }
    return userItemImageUrl(el.dataset.imgPath);
  }
  function positionItemImagePop(anchor){
    var pop = document.getElementById('itemImagePop');
    var r = anchor.getBoundingClientRect();
    var pw = pop.offsetWidth, ph = pop.offsetHeight, gap = 12, m = 8;
    var vw = window.innerWidth, vh = window.innerHeight;
    var left = r.right + gap;
    if(left + pw > vw - m) left = r.left - pw - gap;
    if(left < m) left = Math.max(m, Math.min(vw - pw - m, r.left));
    var top = Math.max(m, Math.min(vh - ph - m, r.top + r.height/2 - ph/2));
    pop.style.left = Math.round(left)+'px';
    pop.style.top = Math.round(top)+'px';
  }
  function showItemImagePop(anchor){
    var pop = document.getElementById('itemImagePop');
    var img = pop.querySelector('img');
    var status = pop.querySelector('.item-img-status');
    var token = ++itemImagePopToken;
    img.hidden = true;
    img.removeAttribute('src');
    status.textContent = 'กำลังโหลดรูป...';
    status.hidden = false;
    pop.hidden = false;
    positionItemImagePop(anchor);
    itemImageSourceFor(anchor).then(function(url){
      if(token!==itemImagePopToken) return;
      img.onload = function(){
        if(token!==itemImagePopToken) return;
        status.hidden = true;
        img.hidden = false;
        positionItemImagePop(anchor);
      };
      img.onerror = function(){ if(token===itemImagePopToken){ status.textContent = 'โหลดรูปไม่ได้'; positionItemImagePop(anchor); } };
      img.src = url;
    }).catch(function(){
      if(token===itemImagePopToken){ status.textContent = 'โหลดรูปไม่ได้'; positionItemImagePop(anchor); }
    });
  }
  function hideItemImagePop(){
    itemImagePopToken++;
    itemImagePopAnchor = null;
    document.getElementById('itemImagePop').hidden = true;
  }

  // ---- หน้าต่างดูรูปใหญ่ (กดไอคอนรูป / กดรูปย่อในฟอร์ม — ทางหลักบนมือถือที่ไม่มีเมาส์) ----
  var itemImageLightboxToken = 0;
  var itemImageLightboxRowId = null;
  function openItemImageLightbox(opts){
    hideItemImagePop();
    var box = document.getElementById('itemImageLightbox');
    var img = document.getElementById('itemImageLightboxImg');
    var status = document.getElementById('itemImageLightboxStatus');
    var caption = document.getElementById('itemImageLightboxCaption');
    var token = ++itemImageLightboxToken;
    itemImageLightboxRowId = opts.rowId || null;
    document.getElementById('itemImageLightboxActions').hidden = !opts.rowId;
    caption.textContent = opts.caption || '';
    caption.hidden = !opts.caption;
    img.hidden = true;
    img.removeAttribute('src');
    status.textContent = 'กำลังโหลดรูป...';
    status.hidden = false;
    box.hidden = false;
    (opts.url ? Promise.resolve(opts.url) : userItemImageUrl(opts.path)).then(function(url){
      if(token!==itemImageLightboxToken) return;
      img.onload = function(){ if(token===itemImageLightboxToken){ status.hidden = true; img.hidden = false; } };
      img.onerror = function(){ if(token===itemImageLightboxToken) status.textContent = 'โหลดรูปไม่ได้'; };
      img.src = url;
    }).catch(function(){
      if(token===itemImageLightboxToken) status.textContent = 'โหลดรูปไม่ได้ (รูปอาจถูกลบไปแล้ว)';
    });
    document.getElementById('itemImageLightboxClose').focus();
  }
  function closeItemImageLightbox(){
    itemImageLightboxToken++;
    itemImageLightboxRowId = null;
    document.getElementById('itemImageLightbox').hidden = true;
  }

  function renderNameSuggest(rowEl){
    var input = rowEl.querySelector('.mr-row-name');
    var box = rowEl.querySelector('.mr-item-suggest');
    var q = input.value.trim().toLowerCase();
    var matches = itemNameChoices().filter(function(n){ return !q || n.toLowerCase().indexOf(q)!==-1; });
    if(!matches.length){
      box.innerHTML = '<p class="mr-suggest-empty">ไม่มีชื่อที่บันทึกไว้</p>';
    } else {
      box.innerHTML = matches.map(function(n){
        return '<div class="mr-suggest-row" data-pick="'+n.replace(/"/g,'&quot;')+'"><span>'+n+'</span>'+
          '<button type="button" class="chip-x" data-remove-name="'+n.replace(/"/g,'&quot;')+'">✕</button>'+
        '</div>';
      }).join('');
    }
    box.hidden = false;
  }

  function hideAllSuggests(){
    document.querySelectorAll('.mr-item-suggest').forEach(function(b){ b.hidden = true; });
  }

  function updateMerchantTotal(){
    var totalBaht = 0, totalZeny = 0;
    activeRows().forEach(function(row){
      var amount = (parseFloat(row.price)||0) * (parseFloat(row.qty)||0);
      if(row.currency==='zeny') totalZeny += amount; else totalBaht += amount;
    });
    var hasZeny = totalZeny > 0;
    document.getElementById('mrTotalBaht').textContent = fmtNum(totalBaht);
    document.getElementById('mrTotalZenyRow').hidden = !hasZeny;
    if(hasZeny) document.getElementById('mrTotalZeny').textContent = fmtNum(totalZeny);
  }

  function setMerchantCategory(cat){
    App.merchantCategory = cat;
    document.querySelectorAll('#mrCategoryToggle .seg-btn').forEach(function(b){
      b.classList.toggle('active', b.dataset.category===cat);
    });
    document.getElementById('mrImageField').hidden = cat==='zeny';
    document.getElementById('mrExRateField').hidden = cat==='zeny';
    // M is always exactly one fixed row — no "+เพิ่มรายการ" to add more of it.
    document.getElementById('mrAddRowBtn').hidden = cat==='zeny';
    renderItemRows();
  }

  var MR_TYPE_LABEL = { buy:'ซื้อ', sell:'ขาย' };
  function entryType(e){ return e.type === 'sell' ? 'sell' : 'buy'; }

  // category: กรองหมวดหมู่ (all/zeny/item/other) — แทนที่ view เดิม ('item'/'day') ที่ถูกตัด "ตามวัน" ออกแล้ว
  var historyState = { serverId:'all', userChangedServer:false, category:'all', range:'today', search:'', expanded:{}, expandedDays:{}, soldOutOpen:null };
  // ป้าย "New" 2 ชั้น ไม่ auto-เปิดการ์ดให้อีกต่อไป (การ์ดเริ่มปิดเสมอ) ป้ายเป็นตัวดึงความสนใจแทน:
  // ชั้น 1 (recentNewGroupIds) = จุดบนสุดที่หัวการ์ดไอเทม หายเมื่อกดเปิดการ์ดนั้น
  // ชั้น 2 (recentNewTxIds) = จุดที่หัวกลุ่มวันที่ข้างในการ์ด หายเมื่อกดเปิดกลุ่มวันที่นั้นดูรายการจริง
  // เก็บลง localStorage ทั้งคู่ ให้อยู่ข้ามการรีเฟรชหน้า จนกว่าจะกดเปิดดูจริงตามลำดับชั้น
  var recentNewGroupIds = {};
  var recentNewTxIds = {};
  function saveRecentNewGroupIds(){ if(App.keys) persist(App.keys.recentNewGroup, recentNewGroupIds); }
  function saveRecentNewTxIds(){ if(App.keys) persist(App.keys.recentNewTx, recentNewTxIds); }
  // ดัชนี id ของ tx ที่อยู่ในแต่ละกลุ่มวันที่ — สร้างใหม่ทุกครั้งที่ render เพื่อรู้ว่า
  // ตอนกดเปิดกลุ่มวันที่ไหน ควรเคลียร์ป้าย New ของ id ไหนบ้าง (ไม่ใช่เคลียร์รวมทุกกลุ่ม)
  var historyDayTxIds = {};
  function resetMerchantHistoryRange(){
    historyState.range = 'today';
    var rangeEl = document.getElementById('mrHistoryRange');
    if(rangeEl) rangeEl.value = 'today';
  }
  // ค่าเริ่มต้นของตัวกรองเซิร์ฟเวอร์ (ประวัติ+กราฟ) = เซิร์ฟแรกที่ตั้งค่าไว้ในบัญชี ถ้ามีข้อมูล/เลือกได้จริง
  // ไม่งั้น fallback ไปตัวแรกในลิสต์ที่มีให้เลือก กันกรณีเซิร์ฟแรกของบัญชียังไม่เคยมีประวัติเลย
  // (userChangedServer กันไว้ไม่ให้ค่าเริ่มต้นทับสิ่งที่ผู้ใช้เลือกเองไปแล้ว เช่นกด "ALL")
  function firstMyServerIn(ids){
    var firstMine = myServerIds()[0];
    return (firstMine && ids.indexOf(firstMine)!==-1) ? firstMine : (ids[0] || null);
  }

  function mrDateStr(d){ return d.getFullYear()+'-'+pad2(d.getMonth()+1)+'-'+pad2(d.getDate()); }

  // ไม่กรองเซิร์ฟพักที่ซ่อนไว้ — ใช้สำหรับหน้าตั้งค่า (ต้องเห็นทุกเซิร์ฟที่เคยมีประวัติ ถึงจะติ๊กเปิดกลับได้)
  function rawHistoryServerIds(){
    var ids = [];
    App.merchantLog.forEach(function(e){ if(ids.indexOf(e.serverId)===-1) ids.push(e.serverId); });
    return ids;
  }
  // รายชื่อเซิร์ฟใน dropdown ของ "ประวัติซื้อ-ขาย" กับกราฟกำไร — ตัดเซิร์ฟพักที่ผู้ใช้ซ่อนไว้ออก
  // (ดู isHistoryServerShown / การ์ด "เซิร์ฟเวอร์เก่า (พัก) ที่มีประวัติ" ในหน้าตั้งค่า)
  function historyServerIds(){
    return rawHistoryServerIds().filter(isHistoryServerShown);
  }
  // รายชื่อเซิร์ฟใน dropdown ของ "ประวัติ" กับกราฟกำไร = เซิร์ฟที่มีข้อมูลบันทึกไว้
  // บวกเซิร์ฟที่กำลังเลือกอยู่ในกล่องซื้อ-ขาย ถึงเซิร์ฟนั้นจะยังไม่มีข้อมูลก็ต้องเลือกดูได้
  // ไม่งั้นพอสลับเซิร์ฟที่กล่องซื้อ-ขาย ตัวกรองจะเด้งกลับไปเซิร์ฟอื่นทันที
  function historyPickerServerIds(){
    var ids = historyServerIds();
    if(App.currentServerId && ids.indexOf(App.currentServerId)===-1) ids = ids.concat([App.currentServerId]);
    return ids;
  }

  var lastHistoryServerIdsKey = null;
  function populateHistoryServerFilter(){
    var sel = document.getElementById('historyServerFilter');
    var ids = historyPickerServerIds();
    var invalid = historyState.serverId!=='all' && ids.indexOf(historyState.serverId)===-1;
    if(!historyState.userChangedServer || invalid) historyState.serverId = firstMyServerIn(ids) || 'all';
    // ใส่สถานะพัก/ไม่พักลงไปในคีย์ด้วย ไม่งั้นถ้า labels เปลี่ยน (เช่นโปรไฟล์เพิ่งโหลดเสร็จ)
    // แต่ ids ชุดเดิม จะไม่รีเฟรช dropdown ให้ ป้าย "(พัก)" จะค้างผิดอยู่แบบนั้นตลอด
    var key = ids.map(function(id){ return id+(isRetiredServer(id)?'1':'0'); }).join('|');
    if(key !== lastHistoryServerIdsKey){
      lastHistoryServerIdsKey = key;
      sel.innerHTML = ids.map(function(id){
        return '<option value="'+id+'">'+serverLabel(id)+'</option>';
      }).join('')+'<option value="all">ALL</option>';
    }
    sel.value = historyState.serverId;

    var tag = document.getElementById('mrHistoryServerTag');
    var tagNames = historyState.serverId==='all'
      ? ids.map(function(id){ var sv = serverRateById(id); return sv?sv.name:id; })
      : [(function(){ var sv = serverRateById(historyState.serverId); return sv ? sv.name : (historyState.serverId||''); })()];
    tag.innerHTML = tagNames.map(function(n){ return '<span class="farm-revenue-server">'+n+'</span>'; }).join('');
  }

  // Single source of truth for "which entries match the history panel's active filters"
  // (server + ช่วงเวลา + ค้นหา). Both views and the summary tiles are built from this, so
  // the tiles always total exactly what's on screen.
  function historyRangeStartTs(){
    return capStartTsForPlan(tfRangeStartTs(historyState.range), hasTradePlan());
  }
  function historyLineMatches(l){
    if(!historyState.search) return true;
    return String(l && l.name || '').toLowerCase().indexOf(historyState.search)!==-1;
  }
  // `opts.ignoreRange` skips the ช่วงเวลา filter (server + ค้นหา still apply) — used to
  // pull an item's full buy/sell history for accurate cost/remaining math even when only
  // one side of a trade (say, a sale made today of stock bought last week) falls inside
  // the currently selected range.
  function filteredMerchantEntries(opts){
    opts = opts || {};
    var entries = App.merchantLog.slice();
    if(historyState.serverId!=='all') entries = entries.filter(function(e){ return e.serverId===historyState.serverId; });
    if(historyState.category!=='all') entries = entries.filter(function(e){ return (e.category||'zeny')===historyState.category; });
    if(!opts.ignoreRange){
      var startTs = historyRangeStartTs();
      if(startTs!=null) entries = entries.filter(function(e){ return e.ts>=startTs; });
    }
    if(historyState.search) entries = entries.filter(function(e){ return (e.lines||[]).some(historyLineMatches); });
    return entries;
  }
  // Every (entry, line) pair that passes the filters, newest first — the unit both
  // views render. A record saved with several lines shows as one row per line.
  function historyScopedLines(opts){
    var out = [];
    filteredMerchantEntries(opts).forEach(function(e){
      var t = entryType(e);
      (e.lines||[]).forEach(function(l){ if(historyLineMatches(l)) out.push({ entry:e, line:l, type:t }); });
    });
    out.sort(function(a,b){ return b.entry.ts-a.entry.ts; });
    return out;
  }
  function lineBahtValue(e, l){
    var total = parseFloat(l.total)||0;
    if(lineCurrency(l)!=='zeny') return total;
    return e.exchangeRate>0 ? farmZenyToBaht(total, e.exchangeRate) : 0;
  }
  var MR_CATEGORY_LABEL = { zeny:'M', item:'Item', other:'อื่นๆ' };
  function historyCategoryTag(cat){ return '<span class="mr-cat-tag">'+(MR_CATEGORY_LABEL[cat]||MR_CATEGORY_LABEL.zeny)+'</span>'; }
  function historyServerTag(serverId){ var sv = serverRateById(serverId); return '<span class="mr-cat-tag">'+(sv?sv.name:serverId)+'</span>'; }
  function historyEscape(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function fmtTimeShort(ts){ return new Date(ts).toLocaleTimeString('th-TH', {hour:'2-digit',minute:'2-digit'}); }
  function historyDayLabel(ts){
    var d = new Date(ts);
    var today = new Date(); today.setHours(0,0,0,0);
    var day = new Date(d); day.setHours(0,0,0,0);
    var diff = Math.round((today-day)/86400000);
    var text = d.toLocaleDateString('th-TH', {day:'numeric',month:'short',year:'numeric'});
    if(diff===0) return 'วันนี้ · '+text;
    if(diff===1) return 'เมื่อวาน · '+text;
    return text;
  }
  function historyEmptyHtml(){
    if(!App.merchantLog.length) return '<p class="mr-empty"><span class="dashboard-empty-title">'+(App.isGuest ? 'ประวัติซื้อ–ขายของคุณอยู่ที่นี่' : 'เริ่มต้นด้วยรายการแรกของคุณ')+'</span><span class="dashboard-empty-detail">'+(App.isGuest ? 'เข้าสู่ระบบด้วยปุ่มด้านบนเพื่อดูข้อมูลของคุณ หรือสมัครสมาชิกหากยังไม่มีบัญชี ตัวเลข 0 ในหน้านี้ยังไม่ใช่ข้อมูลบัญชีของคุณ' : 'ใช้ปุ่ม "ไปฟอร์มซื้อ–ขาย" ด้านบนเพื่อบันทึกรายการ เมื่อบันทึกแล้วจะดูประวัติและยอดสรุปได้ที่นี่')+'</span></p>';
    if(historyState.search) return '<p class="mr-empty"><span class="dashboard-empty-title">ไม่พบไอเทมชื่อ "'+historyEscape(historyState.search)+'"</span><span class="dashboard-empty-detail">ลองเปลี่ยนคำค้น หรือตรวจสอบหมวดหมู่ เซิร์ฟเวอร์ และช่วงเวลาที่เลือกด้านบน</span></p>';
    return '<p class="mr-empty"><span class="dashboard-empty-title">ไม่มีรายการในช่วงเวลานี้</span><span class="dashboard-empty-detail">ลองเลือกช่วงเวลาที่กว้างขึ้น หรือตรวจสอบหมวดหมู่และเซิร์ฟเวอร์ในตัวกรองด้านบน</span></p>';
  }

  // Groups the filtered lines by server+category+item name(+slots) so "ซื้อมาเท่าไหร่,
  // ขายไปเท่าไหร่, เหลือกี่อัน, กำไรเท่าไหร่" reads at a glance instead of having to
  // mentally match up separate buy/sell rows. Cost of goods sold is FIFO (see below), so
  // profit reflects only what was actually sold — unsold stock is never counted as a
  // "loss". Each group also carries its own transaction rows (tx).
  //
  // The ช่วงเวลา filter only decides which items are LISTED (touched at all within the
  // range) — once an item qualifies, its numbers and tx list are built from its whole
  // history, ignoring the range. Otherwise an item bought last week and sold today under
  // "วันนี้" would show as bought-from-nowhere (0 ซื้อมา, "ขายเกินที่ซื้อ") and overstate
  // profit, because the purchase itself falls outside the window.
  function computeHistoryItemGroups(){
    var activeKeys = {};
    historyScopedLines().forEach(function(t){
      var e = t.entry, l = t.line;
      activeKeys[e.serverId+'|'+(e.category||'zeny')+'|'+l.name+'|'+JSON.stringify(l.slots||[])] = true;
    });
    var groups = {}, order = [];
    historyScopedLines({ ignoreRange:true }).forEach(function(t){
      var e = t.entry, l = t.line;
      var slots = l.slots || [];
      var key = e.serverId+'|'+(e.category||'zeny')+'|'+l.name+'|'+JSON.stringify(slots);
      if(!activeKeys[key]) return; // not touched within the selected range — don't list it
      if(!groups[key]){
        groups[key] = { key:key, name:l.name, slots:slots, category:e.category||'zeny', serverId:e.serverId,
                        buyQty:0, buyBaht:0, sellQty:0, sellBaht:0, lastTs:0, tx:[] };
        order.push(key);
      }
      var g = groups[key];
      var qty = parseFloat(l.qty)||0, baht = lineBahtValue(e, l);
      if(t.type==='buy'){ g.buyQty += qty; g.buyBaht += baht; }
      else { g.sellQty += qty; g.sellBaht += baht; }
      if(e.ts>g.lastTs) g.lastTs = e.ts;
      g.tx.push(t);
    });
    return order.map(function(key){
      var g = groups[key];
      // FIFO (ซื้อก่อน-ขายก่อน): each sale consumes the oldest unsold lots, so what's
      // left on hand is the most recently bought stock at its own price — not an average
      // blended with lots that were already sold. A sale made before its purchase was
      // logged runs a deficit that the next purchase covers first, keeping เหลือ =
      // ซื้อมา − ขายไป.
      var lots = [], deficit = 0, cogs = 0;
      g.tx.slice().reverse().forEach(function(t){            // g.tx is newest-first
        var qty = parseFloat(t.line.qty)||0;
        if(qty<=0) return;
        if(t.type==='buy'){
          var unitCost = lineBahtValue(t.entry, t.line)/qty;
          if(deficit>0){
            var cover = Math.min(qty, deficit);
            cogs += cover*unitCost; deficit -= cover; qty -= cover;
          }
          if(qty>0) lots.push({ qty:qty, unitCost:unitCost });
        } else {
          var need = qty;
          while(need>0 && lots.length){
            var lot = lots[0];
            var take = Math.min(need, lot.qty);
            cogs += take*lot.unitCost; lot.qty -= take; need -= take;
            if(lot.qty<=0) lots.shift();
          }
          deficit += need;
        }
      });
      g.remaining = g.buyQty - g.sellQty;
      g.leftCost = lots.reduce(function(s,lot){ return s+lot.qty*lot.unitCost; }, 0);
      g.profit = g.sellBaht - cogs;
      return g;
    }).sort(function(a,b){ return b.lastTs-a.lastTs; });
  }

  // One transaction row. opts.showName → item name in the main cell (ตามวัน view);
  // otherwise the date goes there (ตามไอเทม view, where the card already names the item).
  function historyTxRowHtml(t, opts){
    var e = t.entry, l = t.line;
    var cat = e.category || 'zeny';
    var isZeny = lineCurrency(l)==='zeny';
    var showZenyTag = (cat==='item' || cat==='other') && isZeny;
    var edited = (e.editHistory && e.editHistory.length) ? ' mr-edited-hover' : '';
    var serverTag = opts.showServer ? ' '+historyServerTag(e.serverId) : '';
    var imgPath = lineImagePath(l);
    // รายการที่เพิ่งบันทึกใหม่ ขึ้นป้าย "New" — หายทันทีที่กดเปิดดูอะไรก็ตามในประวัติ (ไม่ใช่ตั้งเวลา)
    var newBadge = recentNewTxIds[e.id] ? '<span class="mr-tx-new-badge">New</span>' : '';
    var main = opts.showName
      ? itemImageNameHtml(imgPath, itemNameWithSlots(l.name||'', l.slots), l.name)+(showZenyTag?zenyNameTag():'')+serverTag
      : itemImageNameHtml(imgPath, '', l.name)+'<span class="'+edited.trim()+'">'+(opts.timeOnly?fmtTimeShort(e.ts):fmtDateTime(e.ts))+newBadge+'</span>'+serverTag;
    var totalHtml = fmtCurrencyAmount(l.total, lineCurrency(l));
    if(isZeny && e.exchangeRate>0) totalHtml += ' <small class="mr-rate-hover">≈ '+fmtNum(farmZenyToBaht(parseFloat(l.total)||0, e.exchangeRate))+' บ</small>';
    // ขายไอเทมโดยไม่ได้เลือกจากคลัง (กรอกเองตรงๆ) = ไม่มีต้นทุนที่รู้ที่มาผูกไว้เลย เตือนให้เห็นชัด
    // กันเข้าใจผิดว่ายอดกำไรที่ขึ้นคือกำไรจริงหลังหักต้นทุนแล้ว — วางต่อท้ายเวลา/ชื่อในบรรทัดเดียวกันเลย
    var hasNoStockWarning = t.type==='sell' && cat==='item' && !l.warehouseSale;
    if(hasNoStockWarning) main += '<span class="mr-tx-nostock-warn">⚠ ไม่ได้เลือกจากคลัง ไม่ได้ลบต้นทุน</span>';
    return '<div class="mr-tx type-'+t.type+'" data-entry-id="'+e.id+'">'+
      '<span class="mr-type-badge '+t.type+'">'+MR_TYPE_LABEL[t.type]+'</span>'+
      '<span class="mr-tx-main'+(hasNoStockWarning?' has-warn':'')+'">'+main+'</span>'+
      '<span class="mr-tx-calc">'+fmtNum(l.qty)+' × '+fmtNum(l.rate)+'</span>'+
      '<span class="mr-tx-total">'+totalHtml+'</span>'+
      (opts.showTime ? '<span class="mr-tx-time'+edited+'">'+fmtTimeShort(e.ts)+newBadge+'</span>' : '')+
      '<button type="button" class="mr-del" data-del="'+e.id+'" title="ลบรายการนี้">🗑</button>'+
    '</div>';
  }

  // The tx list inside an expanded item card is grouped by day (its own mini "ตามวัน"),
  // each day collapsible — an item like M can span dozens of transactions over weeks, and
  // a flat list of all of them makes the card unreadably long. Days start collapsed
  // and retain the open/closed state explicitly chosen by the user.
  function historyTxGroupedByDayHtml(g){
    var order = [], byDay = {};
    g.tx.forEach(function(t){
      var k = mrDateStr(new Date(t.entry.ts));
      if(!byDay[k]){ byDay[k] = { ts:t.entry.ts, rows:[], buy:0, sell:0 }; order.push(k); }
      byDay[k].rows.push(t);
      byDay[k][t.type] += lineBahtValue(t.entry, t.line);
    });
    return order.map(function(dayKey, idx){
      var d = byDay[dayKey];
      var dayGroupKey = g.key+'|'+dayKey;
      historyDayTxIds[dayGroupKey] = d.rows.map(function(t){ return t.entry.id; });
      var open = historyState.expandedDays[dayGroupKey];
      if(open===undefined) open = false; // only a user click opens a day
      var tot = [];
      if(d.sell) tot.push('<span class="sell">ขาย '+fmtNum(d.sell)+' บ</span>');
      if(d.buy) tot.push('<span class="buy">ซื้อ '+fmtNum(d.buy)+' บ</span>');
      var dayHasNew = d.rows.some(function(t){ return recentNewTxIds[t.entry.id]; });
      return '<div class="mr-ic-day'+(open?' open':'')+'" data-day-key="'+encodeURIComponent(dayGroupKey)+'">'+
        '<button type="button" class="mr-ic-day-head" aria-expanded="'+(open?'true':'false')+'">'+
          (dayHasNew ? '<span class="mr-ic-new-badge">New</span>' : '')+
          '<span class="mr-ic-chev">▸</span>'+
          '<span>'+historyDayLabel(d.ts)+'</span>'+
          '<span class="mr-ic-day-count">'+d.rows.length+' รายการ</span>'+
          '<span class="mr-ic-day-tot">'+tot.join(' · ')+'</span>'+
        '</button>'+
        '<div class="mr-tx-list"'+(open?'':' hidden')+'>'+
          d.rows.map(function(t){ return historyTxRowHtml(t, { showName:false, showTime:false, showServer:false, timeOnly:true }); }).join('')+
        '</div>'+
      '</div>';
    }).join('');
  }

  function historyItemRowHtml(g, showServer, displayIndex){
    // หน่วย: หมวด M นับเป็น "M", ที่เหลือนับเป็น "ชิ้น"
    var unit = g.category==='zeny' ? 'M' : 'ชิ้น';
    var over = g.remaining<0 ? -g.remaining : 0;        // ขายเกินกว่าที่บันทึกซื้อไว้
    var left = g.remaining>0 ? g.remaining : 0;
    var open = !!historyState.expanded[g.key];
    var leftSub = over>0 ? 'ขายเกินที่ซื้อ '+fmtNum(over)+' '+unit
                : (left>0 ? 'ทุนค้าง ~'+fmtNum(Math.round(g.leftCost))+' บ' : (g.buyQty>0 ? 'ขายหมดแล้ว' : '—'));
    // "เฉลี่ย X บ/หน่วย" under a cell — lets ซื้อมา vs ขายไป price-per-unit be compared at a glance.
    var avgLine = function(baht, qty, u){
      return qty>0 ? '<small class="mr-it-avg" title="เฉลี่ย '+fmtNum(baht/qty)+' บ/'+u+'">เฉลี่ย '+fmtNum(Math.round(baht/qty))+'บ/'+u+'</small>' : '';
    };
    var buyDisplay = function(value){
      return value ? '-'+fmtNum(Math.abs(value)) : fmtNum(0);
    };
    var buyAvgLine = avgLine(g.buyBaht, g.buyQty, unit);
    var groupHasNew = !!recentNewGroupIds[g.key];
    var profitCell = g.sellQty<=0
      ? '<span class="mr-it-cell profit none"><i>กำไร</i><b>—</b><small>ยังไม่ได้ขาย</small></span>'
      : '<span class="mr-it-cell profit"><i>กำไร</i><b class="'+(g.profit>=0?'profit-pos':'profit-neg')+'">'+(g.profit>=0?'+':'')+fmtNum(g.profit)+' บ</b>'+
        '<small class="mr-profit-sale-note">ขายไป '+fmtNum(g.sellQty)+' '+unit+'</small></span>';
    return '<div class="mr-it-row mr-ic history-alt-'+(displayIndex%2===0?'odd':'even')+(open?' open':'')+'" data-key="'+encodeURIComponent(g.key)+'">'+
      '<button type="button" class="mr-ic-head" aria-expanded="'+(open?'true':'false')+'" title="กดเพื่อดูรายการซื้อ-ขายของไอเทมนี้">'+
        (groupHasNew ? '<span class="mr-ic-new-badge">New</span>' : '')+
        '<span class="mr-ic-chev">▸</span>'+
        '<span class="mr-it-namewrap">'+
          '<span class="mr-it-name">'+itemImageNameHtml(historyGroupImagePath(g), itemNameWithSlots(g.name, g.slots), g.name)+'</span>'+
          '<span class="mr-it-tags">'+historyCategoryTag(g.category)+(showServer?historyServerTag(g.serverId):'')+'</span>'+
        '</span>'+
      '</button>'+
      '<span class="mr-it-cell buy"><i>ซื้อมา</i><b>'+fmtNum(g.buyQty)+' '+unit+'</b><small>'+buyDisplay(g.buyBaht)+' บ</small>'+buyAvgLine+'</span>'+
      '<span class="mr-it-cell sell"><i>ขายไป</i><b>'+fmtNum(g.sellQty)+' '+unit+'</b><small>'+fmtNum(g.sellBaht)+' บ</small>'+avgLine(g.sellBaht, g.sellQty, unit)+'</span>'+
      '<span class="mr-it-cell left'+(left>0?'':' zero')+'"><i>เหลือ</i><b>'+fmtNum(left)+' '+unit+'</b><small>'+leftSub+'</small>'+(left>0?avgLine(g.leftCost, left, unit):'')+'</span>'+
      profitCell+
      '<div class="mr-ic-body"'+(open?'':' hidden')+'>'+historyTxGroupedByDayHtml(g)+'</div>'+
    '</div>';
  }

  function renderHistoryItemView(list){
    var groups = computeHistoryItemGroups();
    if(!groups.length){ list.innerHTML = historyEmptyHtml(); return; }
    var showServer = historyState.serverId==='all';
    // Items still on hand (or never sold) come first; fully sold-out ones fold into a
    // group underneath so a long history doesn't bury what still needs selling.
    var isSoldOut = function(g){ return g.sellQty>0 && g.remaining<=0; };
    var active = groups.filter(function(g){ return !isSoldOut(g); });
    var soldOut = groups.filter(isSoldOut);
    var html = '<div class="mr-it">'+
      active.map(function(g, idx){ return historyItemRowHtml(g, showServer, idx); }).join('');
    if(soldOut.length){
      var soldOpen = historyState.soldOutOpen==null ? !active.length : historyState.soldOutOpen;
      var soldProfit = soldOut.reduce(function(s,g){ return s+g.profit; }, 0);
      var soldHasNew = soldOut.some(function(g){ return recentNewGroupIds[g.key]; });
      html += '<div class="mr-it-group-wrap">'+
        '<button type="button" class="mr-it-group'+(soldOpen?' open':'')+'" id="mrItSoldToggle" aria-expanded="'+(soldOpen?'true':'false')+'">'+
          (soldHasNew ? '<span class="mr-ic-new-badge">New</span>' : '')+
          '<span class="mr-ic-chev">▸</span>ขายหมดแล้ว '+soldOut.length+' รายการ'+
          '<span class="mr-it-group-profit '+(soldProfit>=0?'profit-pos':'profit-neg')+'">กำไรรวม '+(soldProfit>=0?'+':'')+fmtNum(soldProfit)+' บ</span>'+
        '</button>'+
        '<div class="mr-it" id="mrItSoldList"'+(soldOpen?'':' hidden')+'>'+soldOut.map(function(g, idx){ return historyItemRowHtml(g, showServer, active.length+idx); }).join('')+'</div>'+
      '</div>';
    }
    list.innerHTML = html+'</div>';
  }

  function renderMerchantHistory(){
    // บัญชีฟรี (ล็อกอินแล้ว): ช่วงเวลาประวัติเลือกได้แค่ "วันนี้"
    var tradeRangeAllowed = !App.profile || hasTradePlan();
    if(!tradeRangeAllowed) historyState.range = 'today';
    lockHistoryRangeSelect(document.getElementById('mrHistoryRange'), tradeRangeAllowed);
    renderFreeQuotaNotes();
    populateHistoryServerFilter();
    renderMerchantSummary();
    var list = document.getElementById('mrHistoryList');
    renderHistoryItemView(list);
  }

  function summaryTilesHtml(buyTotal, sellTotal, unit){
    var profit = sellTotal - buyTotal;
    return '<div class="mr-summary-row">'+
      '<div class="mr-summary-item"><span class="mr-summary-label">ขายทั้งหมด</span><span class="mr-summary-value sell">'+fmtNum(sellTotal)+' '+unit+'</span></div>'+
      '<div class="mr-summary-item"><span class="mr-summary-label">ซื้อทั้งหมด</span><span class="mr-summary-value buy">'+(buyTotal ? '-'+fmtNum(Math.abs(buyTotal)) : fmtNum(0))+' '+unit+'</span></div>'+
      '<div class="mr-summary-item"><span class="mr-summary-label">กำไรสุทธิ</span><span class="mr-summary-value '+(profit>=0?'profit-pos':'profit-neg')+'">'+(profit>=0?'+':'')+fmtNum(profit)+' '+unit+'</span></div>'+
    '</div>';
  }

  function renderMerchantSummary(){
    // Summed per line (not per record) so a search that hides some lines of a multi-line
    // record leaves the tiles matching exactly the rows on screen.
    var buyBaht = 0, sellBaht = 0;
    historyScopedLines().forEach(function(t){
      var v = lineBahtValue(t.entry, t.line);
      if(t.type==='buy') buyBaht += v; else sellBaht += v;
    });
    document.getElementById('mrSummary').innerHTML = summaryTilesHtml(buyBaht, sellBaht, 'บ');
  }

  function mrEntrySummaryHtml(entry){
    var sv = serverRateById(entry.serverId);
    var names = (entry.lines||[]).map(function(l){ return l.name; }).join(', ');
    return (sv?sv.name:entry.serverId)+' · '+names+'<br>'+fmtEntryTotal(entry)+' · '+fmtDateTime(entry.ts);
  }

  // Edit-history notes are typed by the user (not computed), so they must be escaped
  // before going into innerHTML — unlike the old auto-generated diff, which was trusted.
  function escapeHtml(s){
    return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  var MR_EDIT_HISTORY_TOOLTIP_LIMIT = 5;

  function showMrEditedTooltip(el){
    var entryEl = el.closest('[data-entry-id]');
    var entry = entryEl ? App.merchantLog.filter(function(x){ return x.id===entryEl.dataset.entryId; })[0] : null;
    var history = (entry && entry.editHistory ? entry.editHistory.slice() : []).reverse();
    var tip = document.getElementById('mrEditedTooltip');
    if(!history.length){ tip.hidden = true; return; }

    var shown = history.slice(0, MR_EDIT_HISTORY_TOOLTIP_LIMIT);
    var rows = shown.map(function(h, idx){
      var sep = idx>0 ? 'border-top:1px dashed var(--border);margin-top:.35rem;padding-top:.35rem;' : '';
      return '<div style="'+sep+'">'+
        '<span class="ct-time" style="margin-bottom:.15rem">'+fmtDateTime(h.ts)+'</span>'+
        (h.diff ? '<div style="color:var(--text-dim);font-size:.7rem;line-height:1.4">'+h.diff+'</div>' : '')+
      '</div>';
    }).join('');
    if(history.length > shown.length){
      rows += '<div style="border-top:1px dashed var(--border);margin-top:.35rem;padding-top:.35rem;color:var(--text-dim);font-size:.68rem">และอีก '+(history.length-shown.length)+' ครั้งก่อนหน้า</div>';
    }
    tip.innerHTML = '<span class="ct-time">ประวัติการแก้ไข ('+history.length+' ครั้ง)</span>'+rows;

    var rect = el.getBoundingClientRect();
    tip.hidden = false;
    var left = Math.min(rect.left, window.innerWidth - tip.offsetWidth - 12);
    tip.style.left = Math.max(4, left)+'px';
    tip.style.top = (rect.bottom+6)+'px';
  }

  function hideMrEditedTooltip(){
    document.getElementById('mrEditedTooltip').hidden = true;
  }

  function showMrRateTooltip(el){
    var entryEl = el.closest('[data-entry-id]');
    var entry = entryEl ? App.merchantLog.filter(function(x){ return x.id===entryEl.dataset.entryId; })[0] : null;
    var tip = document.getElementById('mrRateTooltip');
    if(!entry || !(entry.exchangeRate>0)){ tip.hidden = true; return; }
    tip.innerHTML = '<span class="ct-time">เรทที่ใช้ตอนนั้น</span>'+
      '<div class="ct-row"><span class="ct-key">1 M</span><span class="ct-val">= '+fmtNum(entry.exchangeRate)+' บ</span></div>';
    var rect = el.getBoundingClientRect();
    tip.hidden = false;
    var left = Math.min(rect.left, window.innerWidth - tip.offsetWidth - 12);
    tip.style.left = Math.max(4, left)+'px';
    tip.style.top = (rect.bottom+6)+'px';
  }

  function hideMrRateTooltip(){
    document.getElementById('mrRateTooltip').hidden = true;
  }

  function setMerchantType(type){
    var changed = App.merchantType !== type;
    App.merchantType = type;
    document.querySelectorAll('.mr-type-btn').forEach(function(b){
      b.classList.toggle('active', b.dataset.type===type);
    });
    if(changed){
      // "จากคลัง" only applies to "ขาย" — switching away from it must drop the picked
      // batch, or a leftover selection would silently cap qty against warehouse stock on
      // a plain "ซื้อ" row where that never applies. fromStock itself stays true; it's
      // simply unused (sellFromStockAvailable is false) outside sell + item.
      [App.zenyRows, App.itemRows, App.otherRows].forEach(function(rows){
        (rows||[]).forEach(function(row){ if(row.stockGroupKey){ row.stockGroupKey = null; row.stockGroup = null; } });
      });
      renderItemRows();
    }
  }

  function renderAll(){
    if(!App.session || !App.session.id){ renderUser(); return; }
    renderUser(); renderStats(); renderRoster(); renderRateChips(); renderTickerServerChips();
    renderMerchantServers();
    renderMrExchangeRate();
    App.zenyRows = [newZenyRow()];
    App.itemRows = [newItemRow(null, null, null, 'baht')];
    App.otherRows = [newItemRow(null, null, null, 'baht')];
    setMerchantType('buy');
    setMerchantCategory('zeny');
    renderMerchantHistory();
    renderMerchantSummary();
    renderMrChart();
    updateItemsRailBadge();
  }

  function toast(msg){
    var el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(toast._t);
    toast._t = setTimeout(function(){ el.classList.remove('show'); }, 2200);
  }

  // A short-lived pill anchored right above `el` — for warnings tied to one specific
  // field (e.g. "มีในคลังแค่ N ชิ้น" on the จำนวน input) where the general centered toast
  // would be too far from what the user is actually looking at.
  function showFieldTip(el, msg){
    var tip = document.getElementById('mrFieldTip');
    tip.textContent = msg;
    tip.hidden = false;
    tip.classList.remove('show');
    var rect = el.getBoundingClientRect();
    requestAnimationFrame(function(){
      var tipRect = tip.getBoundingClientRect();
      var left = rect.left + rect.width/2 - tipRect.width/2;
      left = Math.max(6, Math.min(left, window.innerWidth - tipRect.width - 6));
      tip.style.left = left+'px';
      tip.style.top = Math.max(6, rect.top - tipRect.height - 8)+'px';
      tip.classList.add('show');
    });
    clearTimeout(showFieldTip._t);
    showFieldTip._t = setTimeout(function(){
      tip.classList.remove('show');
      setTimeout(function(){ tip.hidden = true; }, 160);
    }, 1800);
  }

  // onCancel (ไม่บังคับ) = เรียกตอนกด "ยกเลิก" หรือกดพื้นหลังปิด
  function showConfirm(message, onConfirm, onCancel){
    var overlay = document.getElementById('confirmOverlay');
    document.getElementById('confirmMessage').innerHTML = message;
    overlay.hidden = false;
    var okBtn = document.getElementById('confirmOkBtn');
    var cancelBtn = document.getElementById('confirmCancelBtn');
    var backdrop = overlay.querySelector('.confirm-backdrop');
    function close(){
      overlay.hidden = true;
      okBtn.removeEventListener('click', onOk);
      cancelBtn.removeEventListener('click', onCancelClick);
      backdrop.removeEventListener('click', onCancelClick);
    }
    function onOk(){ close(); onConfirm(); }
    function onCancelClick(){ close(); if(onCancel) onCancel(); }
    okBtn.addEventListener('click', onOk);
    cancelBtn.addEventListener('click', onCancelClick);
    backdrop.addEventListener('click', onCancelClick);
  }

  function showFarmRateRequiredPopup(){
    var overlay = document.getElementById('farmRateRequiredOverlay');
    overlay.hidden = false;
    var okBtn = document.getElementById('farmRateRequiredOkBtn');
    var backdrop = overlay.querySelector('.confirm-backdrop');
    function close(){
      overlay.hidden = true;
      okBtn.removeEventListener('click', close);
      backdrop.removeEventListener('click', close);
    }
    okBtn.addEventListener('click', close);
    backdrop.addEventListener('click', close);
  }

  function showMrRateRequiredPopup(){
    var overlay = document.getElementById('mrRateRequiredOverlay');
    overlay.hidden = false;
    var okBtn = document.getElementById('mrRateRequiredOkBtn');
    var backdrop = overlay.querySelector('.confirm-backdrop');
    function close(){
      overlay.hidden = true;
      okBtn.removeEventListener('click', close);
      backdrop.removeEventListener('click', close);
    }
    okBtn.addEventListener('click', close);
    backdrop.addEventListener('click', close);
  }

  // ป็อปอัป "วิธีใช้" แต่ละหน้า — เนื้อหาคนละชุดต่อหน้า {sub:true} = หัวข้อย่อยตัวหนา (สีเดียวกับรายละเอียด แค่หนาขึ้น)
  var HOWTO_CONTENT = {
    home: { title:'บัญชีนักลงทุน', lines:[
      {sub:true, text:'รายการซื้อ-ขาย'},
      '1. เลือกรายการที่จะทำ M ไอเทม อื่นๆ',
      '2. ซื้อ หรือ ขาย',
      '3. เลือกเซิร์ฟเวอร์ที่ทำรายการ (กรณีพ่อค้าแม่ค้าที่เปิดร้าน 2 เซิร์ฟเวอร์ขึ้นไป) รายการจะถูกจัดแบ่งไว้ตามเซิร์ฟเวอร์ที่เลือกไม่รวมกัน',
      '4. ใส่จำนวน M และราคา (แนบรูปไว้ดูรายการในประวัติได้) กดยืนยัน จะแสดงยอดพร้อมรูปในประวัติ',
      {sub:true, text:'เพิ่มเติม I'},
      '1. สำหรับรายการซื้อไอเทม จะถูกส่งไปในคลังไอเทมเพื่อจัดหมวดหมู่',
      '2. + เพิ่ม Slot (ใส่ข้อมูลไอเทมที่มีออฟหรือการ์ดอื่นๆ ได้)',
      {sub:true, text:'เพิ่มเติม II'},
      '1. ขายหรือซื้อไอเทมเป็นแบบ "Zeny" ต้องใส่เรท M วันนั้น ระบบจะคำนวณยอดเป็น "บาท" ให้เลย',
      {sub:true, text:'เพิ่มเติม III'},
      '1. การ "ขายไอเทม" สามารถเลือกในรายการคลังไอเทมได้เลย เพื่อช่วยในการจัดการสต๊อกแบบเป็นระบบ',
      '2. ขายไอเทมที่ไม่มีของในคลังก็ได้ พิมพ์ชื่อไอเทมแล้วกดขายได้เลย จะถูกคำนวณและบันทึกไปไว้ในประวัติ',
      {sub:true, text:'เพิ่มเติม IV'},
      '1. ถ้าจะดูประวัติรายการแบบละเอียด กดปุ่มซ่อนตรงชื่อรายการ ตรงกรอบประวัติ'
    ]},
    items: { title:'คลังไอเทม', lines:[
      '1. จะแสดงรายชื่อไอเทมที่ทำรายการซื้อมาเท่านั้น',
      '2. ลากรายการสินค้าลงกล่องตามความต้องการ จัดหมวดหมู่',
      '3. เมื่อรายการนั้นถูกขายไป (เลือกจากคลัง) ระบบจะลบรายการในคลังออกอัตโนมัติ แล้วแสดงในประวัติหน้าซื้อ-ขาย'
    ]},
    farm: { title:'ยอดนักฟาม', lines:[
      '1. ใส่ราคา M วันนั้น เพื่อคำนวณรายการที่เป็น Zeny เป็นบาทได้ถูกต้อง',
      '2. ใส่ Map ฟาม',
      '3. ใส่รายการต้นทุน ได้ทั้งหน่วยบาท, Zeny รวมกันได้เลย (กด + เพิ่มรายการได้ถ้าใช้หลายอย่าง)',
      '4. ไอเทมหายาก เช่น การ์ด เอลู โอริ อื่นๆ ใส่ชื่อรายการไว้ก่อน พอขายได้ ไปกดแก้ไขที่ประวัติ ระบบจะคำนวณเพิ่มยอดให้',
      '5. ไอเทมหายาก กด + เพิ่มรายการได้ กรณีมีหลายชิ้น',
      '6. การใส่จำนวนกั้ม เอาที่ผู้เล่นสะดวก จะฟาม 1 กั้มแล้วบันทึก หรือ 10 กั้มแล้วบันทึกทีเดียวก็ได้ ระบบจะเฉลี่ยยอดเงินต่อกั้มออกมา',
      '7. ถ้ายอดเงิน OC มาแล้ว ให้ใส่ยอดแล้วบันทึก',
      '8. ถ้ายอดเงิน "ยังไม่ได้ OC" ให้ใส่ยอดเงิน แล้วจึงกด OC 24% บันทึก'
    ]},
    timers: { title:'จับเวลาบอส', lines:[
      '1. การเพิ่มเพื่อนปาร์ตี้ใช้ 50 แต้ม (ถาวรไม่จำกัดเวลา) แต่ห้าม! กดออกปาร์ตี้',
      '2. เพิ่มบอสได้ไม่จำกัด เลือกที่ค้นหาบอส กดเพิ่มตัวที่ต้องการ',
      '3. เพิ่มบอสเองได้ กรณีมีบอสพิเศษหรือบอสไม่ตรงแพท',
      '4. ช่องใส่เวลาตาย ตามเวลาหลุมบอส เช่น 14.30 / 1430 แล้วกด MVP',
      '5. เมื่อฆ่าบอสตาย ติ๊กจุดตายใน Mini Map และกดเลือกไอเทมที่ได้รับ แล้วกด MVP ระบบจะ -3 วินาที และเริ่มจับเวลาบอสตัวนั้นใหม่',
      '6. ประวัติจะขึ้นบอสที่ฆ่าไป และไอเทมที่ได้รับ สามารถเลือกชื่อเพื่อนในปาร์ตี้ที่ได้ส่วนแบ่งในรอบนั้นได้',
      '7. เมื่อขายได้แล้ว ใส่จำนวนเงินที่ขาย ระบบจะหารให้พร้อมบอกยอดเงินที่ได้รับในประวัติของแต่ละคนในปาร์ตี้ที่ได้รับส่วนแบ่ง',
      '8. ระบบเสียงเตือนจะดังก่อนบอสเกิด 3 นาที (ปิดได้)',
      '9. กดเคลียร์เวลา เลิกจับเวลาบอสตัวนั้น',
      {sub:true, text:'เพิ่มเติม I'},
      {warn:true, text:'1. สำหรับแพ็กเกจฟรี เมื่อถูกเพิ่มเข้าปาร์ตี้ จะดูข้อมูลได้อย่างเดียว!'}
    ]}
  };
  function openHowto(key){
    var d = HOWTO_CONTENT[key];
    if(!d) return;
    document.getElementById('howtoTitle').textContent = d.title;
    document.getElementById('howtoBody').innerHTML = d.lines.map(function(l){
      if(typeof l === 'object' && l && l.sub) return '<div class="howto-sub">'+escapeHtml(l.text)+'</div>';
      if(typeof l === 'object' && l && l.warn) return '<div class="howto-warn">'+escapeHtml(l.text)+'</div>';
      return '<div>'+escapeHtml(l)+'</div>';
    }).join('');
    document.getElementById('howtoOverlay').hidden = false;
  }
  function closeHowto(){ document.getElementById('howtoOverlay').hidden = true; }
  document.getElementById('howtoCloseBtn').addEventListener('click', closeHowto);
  document.querySelector('#howtoOverlay .confirm-backdrop').addEventListener('click', closeHowto);
  document.querySelectorAll('.dashboard-howto-label').forEach(function(el){
    el.addEventListener('click', function(){ openHowto(el.dataset.howto); });
  });

  function showFarmOcHint(){
    if(farmOcHintAcknowledged || store(App.keys.farmOcHint, false)) return;
    document.getElementById('farmOcHintDontShow').checked = false;
    document.getElementById('farmOcHintOverlay').hidden = false;
  }

  function updateClock(){
    var now = new Date();
    document.getElementById('clockTime').textContent = pad2(now.getHours())+':'+pad2(now.getMinutes())+':'+pad2(now.getSeconds());
    document.getElementById('clockDate').textContent = now.toLocaleDateString('th-TH', {weekday:'short', day:'numeric', month:'short'})+' '+farmBeShort(now);
  }

  // ---------- auth modal wiring: เปิดจากปุ่ม "เข้าสู่ระบบ/สมัครสมาชิก" ในมุม util-bar ตอนเป็นผู้เยี่ยมชม (guestBlock ด้านล่าง) ----------
  var isRegister = false;
  function setAuthMode(register){
    isRegister = register;
    document.getElementById('loginFields').hidden = isRegister;
    document.getElementById('registerFields').hidden = !isRegister;
    document.getElementById('authSubmit').textContent = isRegister ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ';
    document.getElementById('authToggle').textContent = isRegister ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก';
    document.getElementById('authSwitchText').firstChild.textContent = isRegister ? 'มีบัญชีแล้ว? ' : 'ยังไม่มีบัญชี? ';
    document.getElementById('authError').textContent = '';
  }
  document.getElementById('authToggle').addEventListener('click', function(){ setAuthMode(!isRegister); });
  function openAuthModal(register){
    setAuthMode(register);
    document.getElementById('authModal').hidden = false;
  }
  document.getElementById('authModalClose').addEventListener('click', function(){ document.getElementById('authModal').hidden = true; });
  document.getElementById('authModalBackdrop').addEventListener('click', function(){ document.getElementById('authModal').hidden = true; });

  function mapAuthError(msg){
    if(/invalid login credentials/i.test(msg)) return 'อีเมล/Username หรือรหัสผ่านไม่ถูกต้อง';
    if(/already registered/i.test(msg)) return 'อีเมลนี้สมัครไว้แล้ว';
    if(/at least 6 characters/i.test(msg)) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    if(/invalid email|unable to validate email/i.test(msg)) return 'รูปแบบอีเมลไม่ถูกต้อง';
    if(/database error saving new user/i.test(msg)) return 'สมัครไม่สำเร็จ — Username นี้อาจเพิ่งมีคนใช้ ลองเปลี่ยนแล้วสมัครใหม่';
    if(/email not confirmed/i.test(msg)) return 'บัญชีนี้ยังไม่ได้ยืนยันอีเมล กรุณากดลิงก์ยืนยันในอีเมลก่อนเข้าสู่ระบบ';
    if(/security purposes|rate limit|only request this/i.test(msg)) return 'ส่งคำขอถี่เกินไป กรุณารออีกสักครู่แล้วลองใหม่';
    return msg;
  }

  // ---------- Username: a-z 0-9 _ . ยาว 3-20 ตัว เช็คว่าว่างไหมทันทีที่พิมพ์ (ผ่าน RPC username_available) ----------
  var USERNAME_RE = /^[a-z0-9_.]{3,20}$/;
  var usernameCheckTimer = null, usernameCheckSeq = 0, usernameOk = null; // usernameOk: true=ว่าง, false=ซ้ำ/ผิดรูปแบบ, null=ยังไม่รู้
  function setUsernameHint(text, cls){
    var h = document.getElementById('rg-username-hint');
    h.textContent = text; h.className = 'field-hint'+(cls ? ' '+cls : '');
  }
  function checkUsername(u){
    var seq = ++usernameCheckSeq;
    if(!u){ usernameOk = null; setUsernameHint('ใช้ล็อกอินได้ และเปลี่ยนภายหลังไม่ได้'); return Promise.resolve(null); }
    if(!USERNAME_RE.test(u)){ usernameOk = false; setUsernameHint('ใช้ได้เฉพาะ a-z 0-9 _ . ยาว 3-20 ตัว', 'bad'); return Promise.resolve(false); }
    setUsernameHint('กำลังตรวจสอบ...');
    return supa.rpc('username_available', { u:u }).then(function(res){
      if(seq !== usernameCheckSeq) return null; // มีการพิมพ์ต่อแล้ว ผลอันนี้เก่า
      if(res.error){ console.error('username_available', res.error); usernameOk = null; setUsernameHint('ตรวจสอบไม่ได้ ลองใหม่อีกครั้ง', 'bad'); return null; }
      usernameOk = !!res.data;
      setUsernameHint(usernameOk ? '✓ ใช้ Username นี้ได้' : 'Username นี้มีคนใช้แล้ว', usernameOk ? 'ok' : 'bad');
      return usernameOk;
    });
  }
  document.getElementById('rg-username').addEventListener('input', function(){
    var inp = document.getElementById('rg-username');
    var u = inp.value.toLowerCase().replace(/\s+/g, '');
    if(u !== inp.value) inp.value = u;
    usernameOk = null;
    clearTimeout(usernameCheckTimer);
    usernameCheckTimer = setTimeout(function(){ checkUsername(u); }, 350);
  });
  function birthDateError(v){
    if(!v) return 'กรอกวันเดือนปีเกิด';
    var d = new Date(v+'T00:00:00');
    if(isNaN(d.getTime())) return 'วันเกิดไม่ถูกต้อง';
    if(d.getTime() > Date.now() || d.getFullYear() < 1900) return 'วันเกิดไม่ถูกต้อง';
    return '';
  }

  var authBusy = false;
  document.getElementById('authSubmit').addEventListener('click', function(){
    if(authBusy) return;
    var errEl = document.getElementById('authError');
    errEl.textContent = '';
    if(isRegister){
      var name = document.getElementById('rg-name').value.trim();
      var username = document.getElementById('rg-username').value.trim().toLowerCase();
      var email = document.getElementById('rg-email').value.trim().toLowerCase();
      var pass = document.getElementById('rg-pass').value;
      var pass2 = document.getElementById('rg-pass2').value;
      var birth = document.getElementById('rg-birth').value;
      var server = document.getElementById('rg-server').value;
      if(!server){ errEl.textContent = 'เลือกเซิร์ฟเวอร์ที่เล่นก่อน'; return; }
      if(!name || !username || !email || !pass || !pass2 || !birth){ errEl.textContent = 'กรอกข้อมูลให้ครบทุกช่อง'; return; }
      if(!USERNAME_RE.test(username)){ errEl.textContent = 'Username ใช้ได้เฉพาะ a-z 0-9 _ . ยาว 3-20 ตัว'; return; }
      if(/[<>]/.test(name)){ errEl.textContent = 'ชื่อที่ใช้แสดงห้ามมีเครื่องหมาย < หรือ >'; return; }
      if(pass.length < 6){ errEl.textContent = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'; return; }
      if(pass !== pass2){ errEl.textContent = 'รหัสผ่านทั้งสองช่องไม่ตรงกัน'; return; }
      var bErr = birthDateError(birth);
      if(bErr){ errEl.textContent = bErr; return; }
      authBusy = true;
      clearTimeout(usernameCheckTimer);
      checkUsername(username).then(function(ok){
        if(ok === false){ authBusy = false; errEl.textContent = 'Username นี้มีคนใช้แล้ว'; return; }
        if(ok === null){ authBusy = false; errEl.textContent = 'ตรวจสอบ Username ไม่ได้ ลองใหม่อีกครั้ง'; return; }
        // username/วันเกิด ส่งเป็น metadata → trigger handle_new_user คัดลอกลง profiles ให้
        return supa.auth.signUp({ email:email, password:pass, options:{ data:{ display_name:name, username:username, birth_date:birth, servers:[server] } } }).then(function(res){
          authBusy = false;
          if(res.error){ errEl.textContent = mapAuthError(res.error.message); return; }
          Track.push('signup');
          Track.flush();
          // โปรเจกต์เปิด "ยืนยันอีเมล" ไว้: สมัครแล้วยังไม่มีเซสชันจนกว่าจะกดลิงก์ในอีเมล → พาไปหน้าล็อกอินพร้อมบอกให้ไปยืนยัน
          if(!res.data.session){
            document.getElementById('authToggle').click();
            document.getElementById('li-email').value = username;
            document.getElementById('authError').textContent = 'สมัครสำเร็จ! กรุณากดลิงก์ยืนยันในอีเมล '+email+' แล้วกลับมาเข้าสู่ระบบ';
            return;
          }
          enterApp(res.data.user);
        });
      });
    } else {
      var ident = document.getElementById('li-email').value.trim().toLowerCase();
      var lpass = document.getElementById('li-pass').value;
      if(!ident || !lpass){ errEl.textContent = 'กรอกข้อมูลให้ครบทุกช่อง'; return; }
      authBusy = true;
      // ไม่มี @ = พิมพ์ username มา → ขอให้เซิร์ฟเวอร์แปลงเป็นอีเมลก่อน (RPC email_for_username)
      var emailReady = ident.indexOf('@') !== -1 ? Promise.resolve(ident)
        : supa.rpc('email_for_username', { u:ident }).then(function(r){
            if(r.error) throw new Error(r.error.message);
            if(!r.data) throw new Error('ไม่พบ Username นี้');
            return r.data;
          });
      emailReady.then(function(lemail){
        return supa.auth.signInWithPassword({ email:lemail, password:lpass });
      }).then(function(res){
        authBusy = false;
        if(res.error){ errEl.textContent = mapAuthError(res.error.message); return; }
        // เตะเซสชันอื่นของบัญชีนี้ทิ้ง กันเอารหัสเดียวไปใช้พร้อมกันหลายเครื่อง
        supa.auth.signOut({ scope: 'others' }).then(function(r){ if(r.error) console.error('signOut others', r.error); });
        enterApp(res.data.user);
      }).catch(function(err){
        authBusy = false;
        errEl.textContent = mapAuthError(err.message || String(err));
      });
    }
  });

  var manualSignOut = false;
  document.getElementById('logoutBtn').addEventListener('click', function(){
    manualSignOut = true;
    supa.auth.signOut();
  });

  // ---------- ลืมรหัสผ่าน: ให้ติดต่อแอดมินที่เพจ Facebook (ไม่ส่งอีเมลรีเซ็ตแล้ว) ----------
  // ไม่ได้ตั้ง SMTP ของตัวเอง — อีเมลในตัวของ Supabase ส่งไม่ถึงผู้ใช้ทั่วไป กดแล้วรออีเมลที่ไม่มาจะงงกว่า
  // แอดมินยืนยันตัวตน (username + วันเกิดที่กรอกตอนสมัคร) แล้วตั้งรหัสใหม่ให้ด้วย SQL
  // (ส่วน "ตั้งรหัสผ่านใหม่หลังกดลิงก์รีเซ็ต" ด้านล่างยังเก็บไว้ เผื่อลิงก์เก่าที่เคยส่งไปแล้ว)
  document.getElementById('forgotPasswordLink').addEventListener('click', function(){
    document.getElementById('forgotPasswordOverlay').hidden = false;
  });
  document.addEventListener('click', function(e){
    if(e.target.closest('[data-forgot-close]')) document.getElementById('forgotPasswordOverlay').hidden = true;
  });

  // ---------- ตั้งรหัสผ่านใหม่หลังกดลิงก์รีเซ็ต: ไม่ต้องรู้รหัสเดิม ----------
  document.getElementById('recoverySaveBtn').addEventListener('click', function(){
    var errEl = document.getElementById('recoveryError');
    var p1 = document.getElementById('recoveryPass').value, p2 = document.getElementById('recoveryPass2').value;
    if(!p1 || !p2){ errEl.textContent = 'กรอกรหัสผ่านให้ครบทั้งสองช่อง'; return; }
    if(p1.length < 6){ errEl.textContent = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'; return; }
    if(p1 !== p2){ errEl.textContent = 'รหัสผ่านทั้งสองช่องไม่ตรงกัน'; return; }
    errEl.textContent = '';
    supa.auth.updateUser({ password: p1 }).then(function(res){
      if(res.error){ errEl.textContent = mapAuthError(res.error.message); return; }
      document.getElementById('recoveryPasswordOverlay').hidden = true;
      supa.auth.signOut({ scope: 'others' }).then(function(r){ if(r.error) console.error('signOut others', r.error); });
      toast('ตั้งรหัสผ่านใหม่เรียบร้อยแล้ว');
    });
  });
  document.getElementById('recoveryCancelBtn').addEventListener('click', function(){
    document.getElementById('recoveryPasswordOverlay').hidden = true;
    manualSignOut = true;
    supa.auth.signOut();
  });

  // จับเหตุการณ์ถูกเตะออกจากเซสชันอื่น (เช่น มีคนเอารหัสเดียวกันไปล็อกอินที่เครื่องอื่น)
  // แยกจากการกด "ออกจากระบบ" เอง ด้วย manualSignOut flag เพื่อไม่ให้ toast ซ้อนกัน
  // PASSWORD_RECOVERY: กดลิงก์รีเซ็ตรหัสผ่านมา เด้ง popup ตั้งรหัสใหม่ก่อนเข้าแอพ
  supa.auth.onAuthStateChange(function(event){
    if(event === 'PASSWORD_RECOVERY'){
      document.getElementById('recoveryError').textContent = '';
      document.getElementById('recoveryPass').value = '';
      document.getElementById('recoveryPass2').value = '';
      document.getElementById('recoveryPasswordOverlay').hidden = false;
      return;
    }
    if(event !== 'SIGNED_OUT') return;
    var wasManual = manualSignOut;
    manualSignOut = false;
    if(!App.session) return;
    App.session = null;
    App.profile = null;
    document.getElementById('authModal').hidden = true;
    enterGuestPreview();
    if(!wasManual) toast('บัญชีนี้เพิ่งถูกใช้ล็อกอินจากที่อื่น กรุณาล็อกอินใหม่');
  });

  // ---------- โหมดผู้เยี่ยมชม: ยังไม่ได้ล็อกอิน แต่เห็นหน้าตาแอพเหมือนจริงได้ (ข้อมูลว่างเปล่าตามจริง
  // เพราะไม่มีสิทธิ์ดึงข้อมูลของใคร) กดเมนูดูหน้าอื่นได้ แต่ทุกอย่างที่ไม่อยู่ใน GUEST_VIEW_ALLOW โดนกันด้วย guestBlock แล้วเด้ง popup login ----------
  function enterGuestPreview(){
    App.session = null;
    App.profile = null;
    App.isGuest = true;
    // เคลียร์ข้อมูลที่โหลดมาจาก Supabase ตอนล็อกอินจริงรอบก่อน (ถ้ามี) กันไม่ให้เหลือค้างโชว์
    // ผิดๆ ตอนกลับมาเป็นผู้เยี่ยมชม — ต้องว่างเปล่าจริงเหมือนบัญชีใหม่เอี่ยม
    App.db = []; App.active = {}; App.markers = {}; App.kills = []; App.partyRoster = []; App.departedSharerNames = {};
    App.viewingHostId = null; App.viewingHostName = null;
    cloudEnd();
    bossLiveStop(); bossLive.knownState = null; bossLive.stateHost = null;
    loadUserData('guest'); // โหลดจาก localStorage namespace 'guest' แยกต่างหาก (ว่างเปล่าเสมอ)
    document.body.classList.add('ro-mode');
    document.getElementById('appScreen').hidden = false;
    renderAll();
    renderRoster();
    var hashPage = pageFromHash();
    var page = (NAV_PAGES.indexOf(hashPage) !== -1 && hashPage !== 'admin') ? hashPage : 'home';
    switchPage(page);
    updateClock();
    updatePartyPanelSummary();
  }

  function enterApp(user){
    App.isGuest = false;
    document.body.classList.remove('ro-mode');
    App.session = { id:user.id, email:user.email };
    App.keys = DataKeys(user.email);
    loadUserData(user.email);
    return Promise.all([ refreshProfile(), resolvePartyContext(), serversReady ]).then(function(){
      // จำสถานะข้อมูลบอสก่อนโหลด — เปิดหน้าจับเวลาบอสทีหลังจะได้เทียบว่ามีใครแก้อะไรไประหว่างนั้นไหม
      bossLive.knownState = null; bossLive.stateHost = null;
      var bossHost = activeOwnerId();
      return bossFetchState(bossHost).then(function(state){ bossLive.knownState = state; bossLive.stateHost = bossHost; }, function(){})
        .then(function(){ return Promise.all([ loadUserBosses(), loadKills() ]); });
    }).then(function(){
      loadUserData(user.email);
      // ประวัติ/คลัง/การตั้งค่า อยู่บนคลาวด์ — โหลดแล้วรวมกับของในเครื่องก่อนวาดหน้า (ย้ายของเดิมขึ้นให้ครั้งแรก)
      return cloudBegin(user);
    }).then(function(){
      pruneServerSelections();
      // ประกาศเป็นกระดานร่วม โหลดแยกแล้วค่อยวาดทับอีกที ไม่บล็อกการเปิดหน้า
      refreshAnnouncementsIfChanged(true);
      recomputeServerRatesFromAnnouncements();
      document.getElementById('authModal').hidden = true;
      document.getElementById('appScreen').hidden = false;
      renderAll();
      updatePartyPanelSummary();
      // เปิดหน้าตาม URL hash ถ้ามี (แชร์ลิงก์/เปิดแท็บใหม่มาที่หน้านั้นตรงๆ) ไม่งั้นกลับไปหน้าเดิมที่ค้างไว้ตอน refresh
      var hashPage = pageFromHash();
      var lastPage = NAV_PAGES.indexOf(hashPage) !== -1 ? hashPage : store(App.keys.lastPage, 'home');
      var isAdmin = App.profile && App.profile.role === 'admin';
      if(NAV_PAGES.indexOf(lastPage)===-1 || (lastPage==='admin' && !isAdmin)) lastPage = 'home';
      switchPage(lastPage);
      updateClock();
      renderExpiryState();
      checkExpiryReminder();
      checkPackageReminder();
      // บัญชีเก่าก่อนมีช่องเซิร์ฟเวอร์ตอนสมัคร (ยังว่าง) → บังคับเลือกครั้งเดียวก่อนใช้งาน (บัญชีใหม่เลือกจากฟอร์มสมัครแล้ว)
      if(!App.profile || !(App.profile.servers||[]).length) openServerPick();
    });
  }

  document.getElementById('rateChips').addEventListener('change', function(e){
    var sel = e.target.closest('.rate-select');
    if(!sel) return;
    App.rateSlots[parseInt(sel.dataset.slot,10)] = sel.value;
    saveRateSlots();
    renderRateChips();
    syncMerchantServersWithRateSlots();
    syncTickerServersWithRateSlots();
    renderMerchantServers();
    renderMrChart();
    renderTickerServerChips();
  });

  document.getElementById('rateChips').addEventListener('click', function(e){
    var addBtn = e.target.closest('#addRateChipBtn');
    if(addBtn){
      var mine = myServerIds();
      if(App.rateSlots.length >= MAX_RATE_CHIP_SLOTS || !mine.length) return;
      if(App.rateSlots.length >= serverQuota()){
        // ใช้ช่องครบโควต้าแล้ว → ต้องซื้อช่องเพิ่มก่อน (หักแต้มที่ฝั่งเซิร์ฟเวอร์)
        buyServerSlotFlow();
        return;
      }
      addRateSlot();
      renderRateChips();
      syncMerchantServersWithRateSlots();
      syncTickerServersWithRateSlots();
      renderMerchantServers();
      renderMrChart();
      renderTickerServerChips();
      return;
    }
    var rmBtn = e.target.closest('[data-remove-rate-slot]');
    if(rmBtn){
      App.rateSlots.splice(parseInt(rmBtn.dataset.removeRateSlot,10), 1);
      saveRateSlots();
      renderRateChips();
      syncMerchantServersWithRateSlots();
      syncTickerServersWithRateSlots();
      renderMerchantServers();
      renderMrChart();
      renderTickerServerChips();
    }
  });

  // ---------- merchant receiving form ----------
  document.getElementById('mrServerChips').addEventListener('click', function(e){
    var chip = e.target.closest('[data-select-server]');
    if(chip){ selectMerchantServer(chip.dataset.selectServer); }
  });

  document.getElementById('mrExRateInput').addEventListener('input', function(){
    var digits = this.value.replace(/[^\d]/g,'');
    this.value = digits ? Number(digits).toLocaleString('th-TH') : '';
    App.merchantExchangeRates[App.currentServerId] = digits || '';
    saveMerchantExchangeRates();
    this.classList.remove('farm-exrate-invalid');
    document.getElementById('mrExRateError').hidden = true;
  });

  document.getElementById('mrAddRowBtn').addEventListener('click', function(){
    var rows = activeRows();
    rows.push(newItemRow(null, null, null, defaultRowCurrency()));
    renderItemRows();
  });

  // ---------- แนบรูปไอเทม: ช่องใหญ่ด้านบน + ปุ่มรูปท้ายช่องชื่อ + ลากวางบนแถว + Ctrl+V ----------
  var mrDropzone = document.getElementById('mrDropzone');
  var mrImageInput = document.getElementById('mrImageInput');
  function filesFrom(list){ return list ? Array.prototype.slice.call(list) : []; }
  function dragHasFiles(e){ return !!(e.dataTransfer && Array.prototype.indexOf.call(e.dataTransfer.types || [], 'Files')!==-1); }
  function rowIdForImage(rowEl){
    var row = rowEl && activeRows().filter(function(r){ return r.rid===rowEl.dataset.rowId; })[0];
    return row && !rowInheritedImagePath(row) ? row.rid : null;
  }
  function openRowImagePicker(rowId){
    pendingImageRowId = rowId || null;
    mrImageInput.click();
  }

  mrDropzone.addEventListener('click', function(){ openRowImagePicker(null); });
  mrDropzone.addEventListener('keydown', function(e){
    if(e.key==='Enter' || e.key===' '){ e.preventDefault(); openRowImagePicker(null); }
  });
  mrImageInput.addEventListener('change', function(e){
    var files = filesFrom(e.target.files);
    var target = pendingImageRowId;
    pendingImageRowId = null;
    e.target.value = '';
    if(files.length) attachImageFiles(files, target);
  });
  mrDropzone.addEventListener('dragover', function(e){ e.preventDefault(); mrDropzone.classList.add('dragover'); });
  mrDropzone.addEventListener('dragleave', function(){ mrDropzone.classList.remove('dragover'); });
  mrDropzone.addEventListener('drop', function(e){
    e.preventDefault();
    mrDropzone.classList.remove('dragover');
    var files = filesFrom(e.dataTransfer && e.dataTransfer.files);
    if(files.length) attachImageFiles(files, null);
  });
  // ลากรูปไปวางบนแถวไหน = แนบให้แถวนั้นเลย
  document.getElementById('mrItemRows').addEventListener('dragover', function(e){
    if(!dragHasFiles(e)) return;
    e.preventDefault();
  });
  document.getElementById('mrItemRows').addEventListener('drop', function(e){
    if(!dragHasFiles(e)) return;
    e.preventDefault();
    var files = filesFrom(e.dataTransfer.files);
    if(files.length) attachImageFiles(files, rowIdForImage(e.target.closest('.mr-item-row')));
  });
  document.addEventListener('paste', function(e){
    if(document.getElementById('view-home').hidden) return;
    if(App.isGuest || isExpiredAccount()) return;
    if(e.target && e.target.closest && e.target.closest('[id$="Overlay"], #authModal, #itemImageLightbox')) return;
    var data = e.clipboardData || window.clipboardData;
    if(!data) return;
    var items = data.items || [];
    var files = [], hasText = false;
    for(var i=0;i<items.length;i++){
      if(items[i].kind==='file' && items[i].type.indexOf('image/')===0){ var f = items[i].getAsFile(); if(f) files.push(f); }
      else if(items[i].type==='text/plain') hasText = true;
    }
    if(!files.length) return;
    var active = document.activeElement;
    var typing = active && /^(INPUT|TEXTAREA)$/.test(active.tagName);
    // ก๊อปมาทั้งข้อความและรูป (เช่นจากหน้าเว็บ) ระหว่างพิมพ์อยู่ = ตั้งใจวางข้อความ ไม่แย่งไปแนบรูป
    if(typing && hasText) return;
    e.preventDefault();
    // วางตอนเคอร์เซอร์อยู่ในแถวไหน = แนบให้แถวนั้น
    attachImageFiles(files, rowIdForImage(active && active.closest ? active.closest('#mrItemRows .mr-item-row') : null));
  });

  // ชี้เมาส์ที่ชื่อไอเทมที่มีรูป = รูปเด้งขึ้นข้างๆ (เฉพาะเมาส์ — จอสัมผัสใช้กดไอคอนแทน)
  document.addEventListener('pointerover', function(e){
    if(e.pointerType && e.pointerType!=='mouse') return;
    var el = e.target.closest ? e.target.closest('[data-img-path],[data-img-row]') : null;
    if(!el){ if(itemImagePopAnchor) hideItemImagePop(); return; }
    if(el===itemImagePopAnchor) return;
    itemImagePopAnchor = el;
    showItemImagePop(el);
  });
  document.addEventListener('pointerout', function(e){
    if(!itemImagePopAnchor) return;
    if(e.relatedTarget && itemImagePopAnchor.contains(e.relatedTarget)) return;
    hideItemImagePop();
  });
  document.addEventListener('scroll', function(){ if(itemImagePopAnchor) hideItemImagePop(); }, true);

  // กดไอคอนรูปในประวัติ/คลัง = เปิดรูปใหญ่
  document.addEventListener('click', function(e){
    var ico = e.target.closest ? e.target.closest('.item-img-ico') : null;
    if(!ico) return;
    e.preventDefault();
    openItemImageLightbox({ path: ico.dataset.imgView, caption: ico.dataset.imgName });
  });
  document.getElementById('itemImageLightbox').addEventListener('click', function(e){
    if(e.target.closest('[data-close-img-lightbox]')) closeItemImageLightbox();
  });
  document.addEventListener('keydown', function(e){
    if(e.key==='Escape' && !document.getElementById('itemImageLightbox').hidden) closeItemImageLightbox();
  });
  document.getElementById('itemImageRemoveBtn').addEventListener('click', function(){
    var row = activeRows().filter(function(r){ return r.rid===itemImageLightboxRowId; })[0];
    closeItemImageLightbox();
    if(!row) return;
    if(row.imagePreviewUrl) URL.revokeObjectURL(row.imagePreviewUrl);
    row.imageBlob = null;
    row.imagePreviewUrl = null;
    refreshRowImageButton(row);
  });
  document.getElementById('itemImageReplaceBtn').addEventListener('click', function(){
    var rowId = itemImageLightboxRowId;
    closeItemImageLightbox();
    openRowImagePicker(rowId);
  });

  document.getElementById('mrItemRows').addEventListener('click', function(e){
    var imgBtn = e.target.closest('[data-row-img]');
    if(imgBtn){
      var imgRow = activeRows().filter(function(r){ return r.rid === imgBtn.dataset.rowImg; })[0];
      if(!imgRow) return;
      if(imgRow.imagePreviewUrl) openItemImageLightbox({ url: imgRow.imagePreviewUrl, rowId: imgRow.rid, caption: imgRow.name.trim() });
      else if(imgBtn.dataset.imgPath) openItemImageLightbox({ path: imgBtn.dataset.imgPath, caption: 'รูปจากตอนบันทึกซื้อ'+(imgRow.name.trim() ? ' · '+imgRow.name.trim() : '') });
      else openRowImagePicker(imgRow.rid);
      return;
    }
    var rmRow = e.target.closest('[data-remove-row]');
    if(rmRow){
      if(rmRow.disabled) return;
      setActiveRows(activeRows().filter(function(r){ return r.rid !== rmRow.dataset.removeRow; }));
      renderItemRows();
      return;
    }
    var rowEl = e.target.closest('.mr-item-row');
    if(!rowEl) return;
    var row = activeRows().filter(function(r){ return r.rid === rowEl.dataset.rowId; })[0];
    if(!row) return;
    if(e.target.closest('.mr-slot-add')){
      row.slots = (row.slots || []).concat('');
      renderItemRows();
      return;
    }
    var rmSlot = e.target.closest('[data-remove-slot]');
    if(rmSlot){
      var slotIdx = parseInt(rmSlot.dataset.removeSlot, 10);
      row.slots = (row.slots || []).filter(function(s, i){ return i !== slotIdx; });
      renderItemRows();
      return;
    }
  });

  document.getElementById('mrItemRows').addEventListener('input', function(e){
    var rowEl = e.target.closest('.mr-item-row');
    if(!rowEl) return;
    var row = activeRows().filter(function(r){ return r.rid === rowEl.dataset.rowId; })[0];
    if(!row) return;
    if(e.target.classList.contains('mr-row-name') && App.merchantCategory!=='zeny'){ row.name = e.target.value; renderNameSuggest(rowEl); }
    if(e.target.classList.contains('mr-row-price')){
      var priceRaw = cleanDecimalInput(e.target.value);
      e.target.value = formatDecimalDisplay(priceRaw);
      row.price = priceRaw;
    }
    if(e.target.classList.contains('mr-row-qty')){
      var qtyRaw = cleanDecimalInput(e.target.value);
      if(row.fromStock && row.stockGroupKey){
        // Stock can change from elsewhere (drops/undo/delete-restore on another page),
        // so read it fresh here instead of the row's own stale snapshot.
        var liveGroup = findSellableGroup(App.currentServerId, App.merchantCategory, row.stockGroupKey);
        var maxAllowed = liveGroup ? liveGroup.qty : 0;
        if(parseFloat(qtyRaw) > maxAllowed){
          qtyRaw = String(maxAllowed);
          showFieldTip(e.target, 'มีในคลังแค่ '+fmtNum(maxAllowed)+' ชิ้น');
        }
      }
      e.target.value = formatDecimalDisplay(qtyRaw);
      row.qty = qtyRaw;
    }
    if(e.target.classList.contains('mr-row-currency')) row.currency = e.target.value;
    if(e.target.classList.contains('mr-slot-input')){
      var idx = parseInt(e.target.dataset.slotIdx, 10);
      row.slots = row.slots || [];
      row.slots[idx] = e.target.value;
    }
    if(e.target.classList.contains('mr-stock-select')){
      var groupKey = e.target.value;
      if(!groupKey){
        row.stockGroupKey = null; row.stockGroup = null;
      } else {
        var group = findSellableGroup(App.currentServerId, App.merchantCategory, groupKey);
        row.stockGroupKey = groupKey;
        row.stockGroup = group;
        if(group){
          row.name = group.name;
          row.price = group.price;
          // M lines are always priced in baht regardless of what currency the Zeny
          // was originally bought with — only Item lines carry the currency over.
          if(App.merchantCategory !== 'zeny') row.currency = group.currency;
          row.slots = (group.slots||[]).slice();
          row.qty = '';
        }
      }
      renderItemRows();
      return;
    }
    updateMerchantTotal();
  });

  document.getElementById('mrItemRows').addEventListener('focusin', function(e){
    if(!e.target.classList.contains('mr-row-name')) return;
    if(App.merchantCategory==='zeny') return; // name field is fixed/readonly — nothing to suggest
    hideAllSuggests();
    renderNameSuggest(e.target.closest('.mr-item-row'));
  });

  document.getElementById('mrItemRows').addEventListener('focusout', function(e){
    if(e.target.classList.contains('mr-row-name')) hideAllSuggests();
  });

  document.getElementById('mrItemRows').addEventListener('mousedown', function(e){
    var pick = e.target.closest('[data-pick]');
    var rmName = e.target.closest('[data-remove-name]');
    if(rmName){
      e.preventDefault();
      var name = rmName.dataset.removeName;
      var cat = App.merchantCategory;
      App.merchantItems[cat] = App.merchantItems[cat].filter(function(n){ return n!==name; });
      saveMerchantItems();
      renderNameSuggest(e.target.closest('.mr-item-row'));
      return;
    }
    if(pick){
      e.preventDefault();
      var rowEl = e.target.closest('.mr-item-row');
      var row = activeRows().filter(function(r){ return r.rid === rowEl.dataset.rowId; })[0];
      if(row){
        row.name = pick.dataset.pick;
        rowEl.querySelector('.mr-row-name').value = row.name;
      }
      rowEl.querySelector('.mr-item-suggest').hidden = true;
    }
  });

  document.addEventListener('click', function(e){
    if(!e.target.closest('.mr-name-wrap')) hideAllSuggests();
  });

  // บันทึกรายการจริง — แยกออกจากปุ่ม เพราะถ้ามีรูปต้องรออัพรูปเสร็จก่อน
  // imagePaths = { rid แถว: path รูปที่อัพขึ้นแล้ว } · คืนค่า path ที่ได้ใช้จริง
  // (บันทึกไม่ผ่าน/แถวนั้นหลุด = ไม่นับ ให้คนเรียกลบรูปที่ไม่ได้ใช้ทิ้ง)
  function commitMerchantEntry(imagePaths){
    imagePaths = imagePaths || {};
    var usedImagePaths = [];
    var previewUrls = {};
    if(!App.currentServerId){ toast('เพิ่มเซิร์ฟเวอร์ก่อนบันทึก'); return usedImagePaths; }
    if(tradeLimitReached()) return usedImagePaths;
    var validRows = activeRows().filter(function(r){
      return r.name.trim() && (parseFloat(r.price)>0) && (parseFloat(r.qty)>0);
    });
    if(!validRows.length){ toast('กรอกชื่อรายการ ราคา และจำนวนอย่างน้อย 1 แถว'); return usedImagePaths; }
    var stockPlans = []; // deferred until after validation — nothing is deducted yet here
    var lines = validRows.map(function(r){
      var name = r.name.trim(), rate = parseFloat(r.price), qty = parseFloat(r.qty), currency = lineCurrency(r);
      var slots = (r.slots || []).map(function(s){ return String(s||'').trim(); }).filter(function(s){ return s; });
      if(App.merchantCategory!=='zeny' && App.merchantItems[App.merchantCategory].indexOf(name)===-1) App.merchantItems[App.merchantCategory].push(name);
      var line = { id: r.lineId||uid(), name:name, rate:rate, qty:qty, currency:currency, total:rate*qty, slots:slots };
      if(imagePaths[r.rid]){
        line.image = imagePaths[r.rid];
        if(r.imagePreviewUrl) previewUrls[line.image] = r.imagePreviewUrl;
      }
      if(App.merchantType==='sell' && r.fromStock && r.stockGroupKey){
        // Stock can have grown/shrunk since the row was set to "from stock" (a
        // drop/undo/delete-restore elsewhere touches the same pool/batch) — read it
        // fresh here so the sale deducts against the current stock, not a stale snapshot.
        var liveGroup = findSellableGroup(App.currentServerId, App.merchantCategory, r.stockGroupKey);
        if(liveGroup) stockPlans.push({ row:r, line:line, tier:liveGroup.tier, records:liveGroup.records, rawAmount: qty });
      }
      return line;
    });
    var exRate = merchantExchangeRate(App.currentServerId);
    var totalZenyPreview = lines.reduce(function(s,l){ return s + (l.currency==='zeny'?l.total:0); }, 0);
    if(totalZenyPreview>0 && !(exRate>0)){
      document.getElementById('mrExRateInput').classList.add('farm-exrate-invalid');
      document.getElementById('mrExRateError').hidden = false;
      showMrRateRequiredPopup();
      return usedImagePaths;
    }
    saveMerchantItems();

    // Validation passed — now it's safe to actually touch the warehouse.
    if(stockPlans.length){
      stockPlans.forEach(function(plan){
        var result = deductWarehouseStock(App.currentServerId, plan.tier, plan.records, plan.rawAmount);
        var taken = result.taken;
        if(taken<=0) return;
        if(taken < plan.rawAmount){
          plan.line.qty = taken;
          plan.line.total = plan.line.rate * taken;
          toast('คลังมีไม่พอ ปรับจำนวน "'+plan.line.name+'" เหลือ '+fmtNum(taken));
        }
        plan.line.warehouseSale = { tier: plan.tier, amount: taken, name: plan.line.name, price: plan.line.rate, currency: plan.line.currency, slots: plan.line.slots,
          sourceLines: result.breakdown.map(function(b){ return { lineId:b.lineId, amount:b.amount }; }) };
        // The sale is committed now — unlink the row from the (now stale) stock group
        // it was picked from, so a lingering form doesn't show yesterday's "remaining".
        plan.row.stockGroupKey = null;
        plan.row.stockGroup = null;
      });
      saveItemWarehouseStock();
      renderItemRows();
    }
    var totalBaht = lines.reduce(function(s,l){ return s + (l.currency==='zeny'?0:l.total); }, 0);
    var totalZeny = lines.reduce(function(s,l){ return s + (l.currency==='zeny'?l.total:0); }, 0);

    lines.forEach(function(l){
      if(!l.image) return;
      usedImagePaths.push(l.image);
      // รูปเพิ่งอัพ: ใช้ไฟล์ในเครื่องโชว์ไปก่อนเลย ไม่ต้องรอขอลิงก์จากเซิร์ฟเวอร์
      if(previewUrls[l.image]) itemImageUrlCache[l.image] = { url: previewUrls[l.image], exp: Infinity };
    });
    var newId = uid();
    var newEntry = { id:newId, ts:Date.now(), serverId:App.currentServerId, lines:lines, totalBaht:totalBaht, totalZeny:totalZeny, exchangeRate: exRate>0 ? exRate : null, type:App.merchantType, category:App.merchantCategory };
    App.merchantLog.push(newEntry);
    saveMerchantLog();
    // ไม่ auto-เปิดการ์ด/กลุ่มวันที่ให้อีกต่อไป (การ์ดเริ่มปิดเสมอ) — ใช้ป้าย "New" 2 ชั้นแทน:
    // ชั้นการ์ดไอเทม (recentNewGroupIds) + ชั้นกลุ่มวันที่ (recentNewTxIds) ดึงความสนใจให้กดเปิดเอง
    lines.forEach(function(l){
      var histKey = newEntry.serverId+'|'+newEntry.category+'|'+l.name+'|'+JSON.stringify(l.slots||[]);
      recentNewGroupIds[histKey] = true;
    });
    saveRecentNewGroupIds();
    recentNewTxIds[newEntry.id] = true;
    saveRecentNewTxIds();
    renderMerchantHistory();
    renderMerchantSummary();
    renderMrChart();
    updateItemsRailBadge();
    var isWarehouseBuy = App.merchantType==='buy' && (App.merchantCategory==='zeny' || App.merchantCategory==='item');
    toast(isWarehouseBuy ? 'รายการซื้อถูกส่งไปคลังไอเทมแล้ว' : 'บันทึก '+lines.length+' รายการแล้ว');
    // Preserve user-selected history expansion and scroll position after saving.
    // Clear the entered rows after a successful save — keep the current
    // เซิร์ฟเวอร์/ประเภท/หมวดหมู่ selection, just don't leave stale text sitting
    // in the fields for the next entry. M is the one exception: its ราคา (the M↔baht
    // rate) usually stays the same across several buys/sells in a row, so it's carried
    // forward — only จำนวน clears, since that's what actually changes each time.
    var keepZenyPrice = App.merchantCategory==='zeny' ? activeRows()[0].price : null;
    setActiveRows(App.merchantCategory==='zeny' ? [newZenyRow(keepZenyPrice)] : [newItemRow(null, null, null, defaultRowCurrency())]);
    renderItemRows();
    return usedImagePaths;
  }

  var mrSaving = false;
  function setMrConfirmBusy(busy){
    var btn = document.getElementById('mrConfirm');
    btn.disabled = busy;
    btn.textContent = busy ? 'กำลังอัพรูป...' : 'ยืนยันและบันทึก';
  }
  function tradeLimitReached(){
    if(freeTradeLeft() > 0) return false;
    showFreeLimitPopup('บัญชีฟรีบันทึกซื้อ–ขายได้ '+FREE_TRADE_DAILY_MAX+' รายการต่อวัน — วันนี้ครบแล้ว'+
      '<span class="confirm-detail">สมัครแพ็กเกจ 2 in 1, 3 in 1 หรือ 4 in 1 เพื่อบันทึกได้ไม่จำกัด (พรุ่งนี้บันทึกแบบฟรีได้อีก '+FREE_TRADE_DAILY_MAX+' รายการ)</span>');
    return true;
  }
  document.getElementById('mrConfirm').addEventListener('click', function(){
    if(mrSaving) return;
    // เช็คลิมิตบัญชีฟรีก่อนอัพรูป — ไม่งั้นรูปขึ้นไปแล้วบันทึกไม่ได้
    if(tradeLimitReached()) return;
    function rowIsValid(r){ return r.name.trim() && (parseFloat(r.price)>0) && (parseFloat(r.qty)>0); }
    var rowsWithImage = activeRows().filter(function(r){ return r.imageBlob && rowIsValid(r); });
    // ไม่มีรูปให้อัพ หรือฟอร์มยังบันทึกไม่ได้ → ไปทางเดิม (commit เป็นคนเตือนเองว่าขาดอะไร)
    if(!rowsWithImage.length || !App.currentServerId){ commitMerchantEntry({}); return; }
    var needsRate = activeRows().some(function(r){ return rowIsValid(r) && lineCurrency(r)==='zeny'; });
    if(needsRate && !(merchantExchangeRate(App.currentServerId)>0)){ commitMerchantEntry({}); return; }
    mrSaving = true;
    setMrConfirmBusy(true);
    uploadRowImages(rowsWithImage).then(function(result){
      mrSaving = false;
      setMrConfirmBusy(false);
      var uploaded = Object.keys(result.paths).map(function(k){ return result.paths[k]; });
      function commitAndCleanup(){
        var used = commitMerchantEntry(result.paths);
        removeItemImages(uploaded.filter(function(p){ return used.indexOf(p)===-1; }));
      }
      if(!result.failed.length){ commitAndCleanup(); return; }
      // อัพไม่ขึ้น: ไม่บันทึกเงียบๆ โดยทิ้งรูป — ถามก่อน (ยกเลิก = แถว/รูปยังอยู่ครบ กดบันทึกใหม่ได้)
      showConfirm('อัพรูปไม่สำเร็จ '+result.failed.length+' จาก '+rowsWithImage.length+' รูป'+
        '<span class="confirm-detail">ยืนยัน = บันทึกรายการเลย (แถวที่อัพไม่ขึ้นจะไม่มีรูป)<br>ยกเลิก = กลับไปกดบันทึกใหม่อีกครั้ง</span>',
        commitAndCleanup,
        function(){ removeItemImages(uploaded); });
    });
  });

  document.getElementById('mrTypeToggle').addEventListener('click', function(e){
    var btn = e.target.closest('[data-type]');
    if(btn) setMerchantType(btn.dataset.type);
  });

  document.getElementById('mrCategoryToggle').addEventListener('click', function(e){
    var btn = e.target.closest('[data-category]');
    if(btn) setMerchantCategory(btn.dataset.category);
  });

  document.getElementById('mrHistoryList').addEventListener('click', function(e){
    var delBtn = e.target.closest('[data-del]');
    if(delBtn){
      var id = delBtn.dataset.del;
      var entry = App.merchantLog.filter(function(x){ return x.id===id; })[0];
      var hasWarehouseSale = !!entry && (entry.lines||[]).some(function(l){ return l.warehouseSale; });
      // A buy entry that's already been dragged into the warehouse: deleting the purchase
      // record should also pull whatever of it is STILL sitting in the warehouse (only
      // "still" — a portion already sold from stock elsewhere is untouched, same as ↩).
      // Once the purchase itself is gone there's no home for it to go back to "pending"
      // under, so this removes it outright rather than routing it there.
      var warehousedLines = [];
      if(entry && entryType(entry)==='buy' && entry.category==='item'){
        var w0 = warehouseStockFor(entry.serverId);
        (entry.lines||[]).forEach(function(l){
          ITEM_WAREHOUSE_TIERS.forEach(function(tier){
            var matched = w0[tier].filter(function(it){ return it.lineId===l.id; });
            if(!matched.length) return;
            var amt = matched.reduce(function(s,it){ return s + (parseFloat(it.qty)||0); }, 0);
            warehousedLines.push({ line:l, tier:tier, amount:amt });
          });
        });
      }
      var hasWarehousedBuy = warehousedLines.length>0;
      var detail = entry ? '<span class="confirm-detail">'+mrEntrySummaryHtml(entry)+'</span>' : '';
      // Rows are shown per item line, but a save can bundle several lines into one
      // record — deleting removes the whole record, so say so when that's the case.
      var multiNote = (entry && (entry.lines||[]).length>1)
        ? '<p class="confirm-warehouse-note">รายการนี้บันทึกรวมกัน '+entry.lines.length+' รายการในครั้งเดียว — จะถูกลบทั้งหมดพร้อมกัน</p>' : '';
      var warnHtml = multiNote + (hasWarehouseSale ? '<p class="confirm-warehouse-note">รายการนี้เชื่อมกับคลัง — จำนวนที่ถูกลบจะถูกคืนกลับเข้าคลัง</p>'
        : hasWarehousedBuy ? '<p class="confirm-warehouse-note">รายการนี้ถูกลงคลังไปแล้ว — ลบรายการนี้จะดึงจำนวนที่ยังอยู่ในคลังออกไปด้วย (ส่วนที่ถูกขายออกไปแล้วจะไม่ถูกแตะ)</p>' : '');
      showConfirm('ยืนยันลบรายการนี้?'+detail+warnHtml, function(){
        if(hasWarehouseSale){
          (entry.lines||[]).forEach(function(l){
            if(l.warehouseSale) restoreWarehouseStock(entry.serverId, l.warehouseSale);
          });
          saveItemWarehouseStock();
          renderItemRows();
        }
        if(warehousedLines.length){
          var w1 = warehouseStockFor(entry.serverId);
          warehousedLines.forEach(function(wl){
            w1[wl.tier] = w1[wl.tier].filter(function(it){ return it.lineId!==wl.line.id; });
            addClaimedQty(entry.serverId, wl.line.id, -wl.amount);
          });
          saveItemWarehouseStock();
          saveItemLineClaimedQty();
          renderItemsPage();
          renderItemRows();
        }
        // ลบเฉพาะรูปที่แนบกับรายการนี้เอง (รูปที่ยืมมาจากตอนซื้อเป็นของรายการซื้อ ไม่แตะ)
        if(entry) removeItemImages((entry.lines||[]).map(function(l){ return l.image; }));
        App.merchantLog = App.merchantLog.filter(function(e){ return e.id!==id; });
        saveMerchantLog();
        renderMerchantHistory();
        renderMerchantSummary();
        renderMrChart();
        updateItemsRailBadge();
        toast('ลบรายการแล้ว');
      });
    }
  });

  document.getElementById('mrHistoryList').addEventListener('mouseover', function(e){
    var editedEl = e.target.closest('.mr-edited-hover');
    if(editedEl){ showMrEditedTooltip(editedEl); return; }
    var rateEl = e.target.closest('.mr-rate-hover');
    if(rateEl) showMrRateTooltip(rateEl);
  });
  document.getElementById('mrHistoryList').addEventListener('mouseout', function(e){
    var editedEl = e.target.closest('.mr-edited-hover');
    if(editedEl){ hideMrEditedTooltip(); return; }
    var rateEl = e.target.closest('.mr-rate-hover');
    if(rateEl) hideMrRateTooltip();
  });

  // Expand/collapse an item card, or reveal more rows in the ตามวัน view. The delete
  // button is handled by the listener above, so it's skipped here.
  // ป้าย "New" ไล่ระดับ: เปิดการ์ดไอเทม/กองขายหมดแล้ว = เคลียร์เฉพาะป้ายชั้นบน (recentNewGroupIds)
  // เปิดกลุ่มวันที่ดูรายการจริง = เคลียร์เฉพาะป้ายชั้นล่าง (recentNewTxIds) ของวันนั้น — คนละชั้น คนละเงื่อนไขหาย
  function clearNewGroupIdsFor(keys){
    var changed = false;
    (keys||[]).forEach(function(k){ if(recentNewGroupIds[k]){ delete recentNewGroupIds[k]; changed = true; } });
    if(changed) saveRecentNewGroupIds();
    return changed;
  }
  function clearNewTxIdsFor(ids){
    var changed = false;
    (ids||[]).forEach(function(id){ if(recentNewTxIds[id]){ delete recentNewTxIds[id]; changed = true; } });
    if(changed) saveRecentNewTxIds();
    return changed;
  }
  document.getElementById('mrHistoryList').addEventListener('click', function(e){
    if(e.target.closest('[data-del]')) return;
    if(e.target.closest('.item-img-ico')) return; // กดไอคอนรูป = เปิดรูป ไม่ใช่กาง/หุบการ์ด
    // กดตรงไหนของการ์ด (หัวข้อ/ซื้อมา/ขายไป/เหลือ/กำไร) ก็กาง-หุบได้หมด ยกเว้นกดในส่วนที่กางออกมาแล้ว
    // (มีปุ่ม/แถวย่อยของตัวเองอยู่ข้างในอยู่แล้ว — ปล่อยให้ตัวจัดการด้านล่างดูแลแทน)
    var card = e.target.closest('.mr-it-row.mr-ic');
    if(card && !e.target.closest('.mr-ic-body')){
      var key = decodeURIComponent(card.dataset.key);
      var open = !historyState.expanded[key];
      historyState.expanded[key] = open;
      card.classList.toggle('open', open);
      card.querySelector('.mr-ic-body').hidden = !open;
      card.querySelector('.mr-ic-head').setAttribute('aria-expanded', open ? 'true' : 'false');
      if(open && clearNewGroupIdsFor([key])) renderMerchantHistory();
      return;
    }
    var dayHead = e.target.closest('.mr-ic-day-head');
    if(dayHead){
      var dayEl = dayHead.closest('.mr-ic-day');
      var dayKey = decodeURIComponent(dayEl.dataset.dayKey);
      var dayOpen = !dayEl.classList.contains('open');
      historyState.expandedDays[dayKey] = dayOpen;
      dayEl.classList.toggle('open', dayOpen);
      dayEl.querySelector('.mr-tx-list').hidden = !dayOpen;
      dayHead.setAttribute('aria-expanded', dayOpen ? 'true' : 'false');
      if(dayOpen && clearNewTxIdsFor(historyDayTxIds[dayKey])) renderMerchantHistory();
      return;
    }
    if(e.target.closest('#mrItSoldToggle')){
      // ป้าย New บนปุ่มนี้คำนวณสดจาก recentNewGroupIds ของไอเทมข้างในเสมอ (ดู soldHasNew ตอน render)
      // ไม่ใช่ธงแยกของตัวเอง — กดเปิดแค่เผยรายการ ไม่เคลียร์อะไร ต้องกดเปิดทีละการ์ดไอเทมข้างในเองถึงจะหาย
      historyState.soldOutOpen = document.getElementById('mrItSoldList').hidden;
      renderMerchantHistory();
      return;
    }
  });

  function onHistoryServerFilterChange(e){
    try{
      historyState.serverId = e.target.value;
      historyState.userChangedServer = true;
      resetMerchantHistoryRange();
      renderMerchantHistory();
    }catch(err){
      console.error('historyServerFilter change failed', err);
      toast('เกิดข้อผิดพลาดในการกรอง: '+err.message);
    }
  }
  document.getElementById('historyServerFilter').addEventListener('change', onHistoryServerFilterChange);
  document.getElementById('historyServerFilter').addEventListener('input', onHistoryServerFilterChange);

  document.getElementById('historyCategoryToggle').addEventListener('click', function(e){
    var btn = e.target.closest('[data-historycat]');
    if(!btn) return;
    historyState.category = btn.dataset.historycat;
    document.querySelectorAll('#historyCategoryToggle .seg-btn').forEach(function(b){
      b.classList.toggle('active', b===btn);
    });
    renderMerchantHistory();
  });

  document.getElementById('mrHistorySearch').addEventListener('input', function(e){
    historyState.search = e.target.value.trim().toLowerCase();
    renderMerchantHistory();
  });

  document.getElementById('mrHistoryRange').addEventListener('change', function(e){
    historyState.range = e.target.value;
    renderMerchantHistory();
  });

  // ---------- คลังไอเทม (item warehouse) ----------
  // Pending items are computed on the fly from App.merchantLog (buy-type M/Item lines
  // not yet claimed by a warehouse) rather than stored separately, so the source of
  // truth for "what was bought" stays the merchant log; only the warehouse assignment
  // (which tier a line's item/money ended up in) is persisted here.
  var ITEM_WAREHOUSE_TIERS = ['A','B','C','D','E','S'];
  var FREE_WAREHOUSE_TIER = 'S';       // คลังเดียวที่บัญชีฟรีใช้ได้ (ที่เหลือล็อกหมด)
  var FREE_WAREHOUSE_MAX_ITEMS = 3;    // จำกัดจำนวนรายการ (นับรวมรายการชื่อซ้ำด้วย ไม่ใช่นับจำนวนชิ้น)

  // ---------- กติกาบัญชีฟรี: บัญชีนักลงทุน / ยอดนักฟาม ----------
  // (ปลดล็อกด้วยแพ็กที่มีระบบนั้น — hasTradePlan / hasFarmPlan · บัญชีเก่าไม่จำกัดกับแอดมินไม่โดน)
  // "ต่อวัน" = นับรายการที่บันทึกตั้งแต่เที่ยงคืนวันนี้ ทุกเซิร์ฟเวอร์รวมกัน · 1 ครั้งที่กดบันทึก = 1 รายการ
  // แก้ไขรายการเดิมไม่นับเพิ่ม · ข้อมูลส่วนนี้เก็บเป็นก้อนเดียวในบัญชี จึงกันที่หน้าเว็บเท่านั้น (แบบเดียวกับคลังไอเทม)
  var FREE_TRADE_DAILY_MAX = 5;        // บันทึกซื้อ–ขายต่อวัน (ซื้อ+ขาย ทุกหมวดรวมกัน)
  var FREE_FARM_DAILY_MAX = 3;         // บันทึกต้นทุนต่อกั้มต่อวัน
  function countLoggedToday(log){
    var t = todayStartTs();
    return (log||[]).filter(function(e){ return e && e.ts >= t; }).length;
  }
  function freeTradeLeft(){ return hasTradePlan() ? Infinity : Math.max(0, FREE_TRADE_DAILY_MAX - countLoggedToday(App.merchantLog)); }
  function freeFarmLeft(){ return hasFarmPlan() ? Infinity : Math.max(0, FREE_FARM_DAILY_MAX - countLoggedToday(App.farmLog)); }
  // กล่องแจ้งครบลิมิต — ใช้กล่องยืนยันตัวเดิม แค่เปลี่ยนชื่อปุ่มชั่วคราว (ดูแพ็กเกจ / ปิด)
  function showFreeLimitPopup(message){
    var ok = document.getElementById('confirmOkBtn'), cancel = document.getElementById('confirmCancelBtn');
    var okText = ok.textContent, cancelText = cancel.textContent;
    ok.textContent = 'ดูแพ็กเกจ'; cancel.textContent = 'ปิด';
    function restore(){ ok.textContent = okText; cancel.textContent = cancelText; }
    showConfirm(message, function(){ restore(); switchPage('pricing'); }, restore);
  }
  // ตัวเลขเหลือกี่รายการใต้ปุ่มบันทึก
  function renderFreeQuotaNotes(){
    var loggedIn = !!App.profile && !App.isGuest;
    [['mrFreeQuota', freeTradeLeft(), FREE_TRADE_DAILY_MAX, 'บันทึกซื้อ–ขาย', 'รายการ'],
     ['farmFreeQuota', freeFarmLeft(), FREE_FARM_DAILY_MAX, 'บันทึกต้นทุนต่อกั้ม', 'ครั้ง']].forEach(function(q){
      var el = document.getElementById(q[0]);
      if(!el) return;
      el.hidden = !loggedIn || q[1] === Infinity;
      if(el.hidden) return;
      el.classList.toggle('is-empty', q[1] === 0);
      el.textContent = q[1] === 0
        ? 'บัญชีฟรี: วันนี้'+q[3]+'ครบ '+q[2]+' '+q[4]+'แล้ว — สมัครแพ็กเกจเพื่อบันทึกไม่จำกัด'
        : 'บัญชีฟรี: วันนี้'+q[3]+'ได้อีก '+q[1]+'/'+q[2]+' '+q[4];
    });
  }
  // ตัวเลือกช่วงเวลาของประวัติ: บัญชีฟรีเลือกได้แค่ "วันนี้" ที่เหลือขึ้น 🔒 กดเลือกไม่ได้
  function lockHistoryRangeSelect(sel, allowed){
    if(!sel) return;
    Array.prototype.forEach.call(sel.options, function(opt){
      if(opt.value === 'today') return;
      if(!opt.dataset.label) opt.dataset.label = opt.textContent;
      opt.disabled = !allowed;
      opt.textContent = opt.dataset.label + (allowed ? '' : ' 🔒');
    });
    if(!allowed && sel.value !== 'today') sel.value = 'today';
    sel.title = allowed ? '' : 'บัญชีฟรีดูประวัติได้แค่วันนี้ — สมัครแพ็กเกจเพื่อดูย้อนหลังทั้งหมด';
  }
  // Warehouse "S" is displayed as "อื่นๆ" (its internal tier code stays 'S' so existing
  // saved warehouse data keeps working without a migration).
  function itemTierLabel(tier){ return tier==='S' ? 'อื่นๆ' : tier; }

  function warehouseStockFor(serverId){
    if(!App.itemWarehouseStock[serverId]) App.itemWarehouseStock[serverId] = {};
    var w = App.itemWarehouseStock[serverId];
    ITEM_WAREHOUSE_TIERS.forEach(function(tier){ if(!w[tier]) w[tier] = []; });
    return w;
  }

  function findMerchantLineById(lineId){
    for(var i=0;i<App.merchantLog.length;i++){
      var e = App.merchantLog[i];
      var lines = e.lines||[];
      for(var j=0;j<lines.length;j++){
        if(lines[j].id===lineId) return { entry:e, line:lines[j] };
      }
    }
    return null;
  }

  // ---------- sell-from-warehouse (used by the "ขาย" merchant form) ----------
  // Groups current warehouse stock into pickable lots, same grouping rules as the
  // คลังไอเทม detail view (live price, name+slots+price+currency identity for items;
  // name-only pool for M since Zeny is fungible regardless of the rate it came in at).
  function sellableItemGroups(serverId){
    var groups = {}, order = [];
    ITEM_WAREHOUSE_TIERS.forEach(function(tier){
      warehouseStockFor(serverId)[tier].forEach(function(it){
        var found = findMerchantLineById(it.lineId);
        var price = found ? found.line.rate : it.price;
        var currency = found ? lineCurrency(found.line) : it.currency;
        var key = tier+'|'+it.name+'|'+JSON.stringify(it.slots||[])+'|'+price+'|'+currency;
        if(!groups[key]){
          groups[key] = { key:key, tier:tier, name:it.name, slots:(it.slots||[]).slice(), price:price, currency:currency, qty:0, records:[] };
          order.push(key);
        }
        var qty = Math.max(1, Math.round(parseFloat(it.qty)||1));
        groups[key].qty += qty;
        groups[key].records.push({ id: it.id, qty: qty, ts: it.ts, lineId: it.lineId });
      });
    });
    order.forEach(function(key){ groups[key].records.sort(function(a,b){ return a.ts-b.ts; }); });
    return order.map(function(key){ return groups[key]; });
  }
  function sellableGroupsFor(serverId, category){
    return sellableItemGroups(serverId);
  }
  function findSellableGroup(serverId, category, key){
    return sellableGroupsFor(serverId, category).filter(function(g){ return g.key===key; })[0] || null;
  }

  // Deducts `amountNeeded` from a group's underlying records (oldest first), mutating
  // the real warehouse arrays. Returns how much was actually taken (may be less than
  // asked if the warehouse changed since the group was read).
  // Returns { taken, breakdown } — breakdown lists which original purchase line(s)
  // each consumed unit came from, so a later restore can put it back under the SAME
  // lineId (otherwise the purchase would look "never warehoused" again and reappear
  // in the pending list even though it was legitimately bought → warehoused → sold).
  function deductWarehouseStock(serverId, tier, records, amountNeeded){
    var w = warehouseStockFor(serverId);
    var arr = w[tier];
    var remaining = amountNeeded;
    var breakdown = [];
    for(var i=0;i<records.length && remaining>0.0000001;i++){
      var idx = -1;
      for(var j=0;j<arr.length;j++){ if(arr[j].id===records[i].id){ idx=j; break; } }
      if(idx===-1) continue;
      var it = arr[idx];
      var available = Math.max(1, Math.round(parseFloat(it.qty)||1));
      var take = Math.min(available, remaining);
      if(take<=0) continue;
      breakdown.push({ id: it.id, lineId: it.lineId, amount: take });
      var left = available - take;
      if(left<=0.0000001){
        arr.splice(idx,1);
      } else {
        it.qty = left;
        it.total = (parseFloat(it.price)||0) * left;
      }
      remaining -= take;
    }
    return { taken: amountNeeded - remaining, breakdown: breakdown };
  }
  // Pushes a fresh stock record back in (used to undo a sale on edit/delete). Doesn't
  // try to restore the exact original record — the stock is fungible within a group.
  // Returns the freshly-created record ids (with their lineId/amount) so a caller that
  // needs to precisely undo this exact restore later (cancelling an edit) can target
  // just these records instead of a generic FIFO pass that might eat into unrelated,
  // never-sold stock that happens to share the same name/price identity.
  function restoreWarehouseStock(serverId, sale){
    var w = warehouseStockFor(serverId);
    // Restore under the ORIGINAL purchase line's id whenever we recorded one, so the
    // pending-list math (which keys off lineId) still sees these units as claimed —
    // otherwise the original purchase would wrongly reappear as "not yet warehoused".
    if(ITEM_WAREHOUSE_TIERS.indexOf(sale.tier)===-1) return []; // unknown/removed tier (e.g. legacy M sale) — nothing to restore into
    var sourceLines = sale.sourceLines && sale.sourceLines.length ? sale.sourceLines : [{ lineId:null, amount:sale.amount }];
    var created = [];
    sourceLines.forEach(function(sl){
      if(!(sl.amount>0)) return;
      var id = uid();
      w[sale.tier].push({ id:id, lineId: sl.lineId||uid(), name:sale.name, qty:sl.amount, price:sale.price,
        total:(parseFloat(sale.price)||0)*sl.amount, currency:sale.currency, ts:Date.now(), slots:(sale.slots||[]).slice() });
      created.push({ id:id, qty:sl.amount });
    });
    return created;
  }
  // "How much of each purchase line is off the pending list" — NOT the same as "how
  // much currently sits in the warehouse right now" (a sale reduces the latter but a
  // legitimately-sold line must never come back as pending, so this reads the
  // separately-tracked claimed-qty ledger instead of summing live stock qty).
  function stockedQtyByLineId(serverId){
    return App.itemLineClaimedQty[serverId] ? Object.assign({}, App.itemLineClaimedQty[serverId]) : {};
  }
  function itemsPendingList(serverId){
    if(!serverId) return [];
    var claimedQty = stockedQtyByLineId(serverId);
    var pending = [];
    App.merchantLog.forEach(function(e){
      if(e.serverId!==serverId || entryType(e)!=='buy') return;
      var cat = e.category || 'zeny';
      if(cat!=='item') return; // only Item purchases go through the warehouse — M and "อื่นๆ" are plain history
      (e.lines||[]).forEach(function(l){
        var totalQty = parseFloat(l.qty)||0;
        var remaining = totalQty - (claimedQty[l.id]||0);
        if(remaining<=0) return;
        pending.push({
          lineId: l.id, entryId: e.id, name: l.name, qty: remaining, rate: l.rate,
          total: l.rate*remaining, currency: lineCurrency(l),
          category: cat, ts: e.ts, slots: l.slots, exchangeRate: e.exchangeRate
        });
      });
    });
    pending.sort(function(a,b){ return b.ts-a.ts; });
    return pending;
  }

  // Total lines still waiting to be dropped into a warehouse tier, across every server —
  // not just the one currently selected on the คลังไอเทม page — so the badge on the rail
  // icon (visible from any page) reflects the whole account, not just what's on screen.
  function totalPendingItemsCount(){
    return historyServerIds().reduce(function(sum, id){ return sum + itemsPendingList(id).length; }, 0);
  }
  function updateItemsRailBadge(){
    var badge = document.getElementById('railItemsBadge');
    if(!badge) return;
    var n = totalPendingItemsCount();
    badge.textContent = n>99 ? '99+' : n;
    badge.hidden = n<=0;
  }

  function warehouseTierCount(serverId, tier){
    return warehouseStockFor(serverId)[tier].reduce(function(s,item){ return s + (parseFloat(item.qty)||0); }, 0);
  }
  // คลังไอเทมเก็บของจริงรายเซิร์ฟ เลยต้องโชว์ทั้งเซิร์ฟที่เล่นอยู่ (ไว้เก็บของใหม่)
  // และเซิร์ฟที่ยังมีของค้างคลังหรือมีประวัติซื้อ-ขาย ไม่งั้นของที่ค้างอยู่จะเข้าไปดูไม่ได้
  function itemsServerIds(){
    var ids = myServerIds().slice();
    historyServerIds().forEach(function(id){ if(ids.indexOf(id)===-1) ids.push(id); });
    Object.keys(App.itemWarehouseStock||{}).forEach(function(id){ if(ids.indexOf(id)===-1) ids.push(id); });
    return ids;
  }
  function populateItemsServerSelect(){
    var sel = document.getElementById('itemsServerSelect');
    var ids = itemsServerIds();
    if(App.itemsServerId==null || ids.indexOf(App.itemsServerId)===-1){
      App.itemsServerId = ids.indexOf(App.currentServerId)!==-1 ? App.currentServerId : (ids[0] || null);
      saveItemsServer();
    }
    sel.innerHTML = ids.map(function(id){
      return '<option value="'+id+'">'+serverLabel(id)+'</option>';
    }).join('');
    sel.value = App.itemsServerId;
  }

  function renderItemsPendingList(){
    var list = document.getElementById('itemsPendingList');
    if(!App.itemsServerId){ list.innerHTML = '<p class="mr-empty">ยังไม่มีเซิร์ฟเวอร์ที่มีรายการซื้อ-ขาย</p>'; return; }
    var pending = itemsPendingList(App.itemsServerId);
    if(!pending.length){ list.innerHTML = '<p class="mr-empty">ไม่มีรายการที่รอลงคลัง</p>'; return; }
    list.innerHTML = pending.map(function(p){
      var isZeny = p.currency==='zeny';
      var hasRate = isZeny && p.exchangeRate>0;
      var dispRate = hasRate ? farmZenyToBaht(p.rate, p.exchangeRate) : p.rate;
      var dispTotal = hasRate ? farmZenyToBaht(p.total, p.exchangeRate) : p.total;
      var unit = (isZeny && !hasRate) ? '<span style="color:'+MR_ZENY_COLOR+'">z</span>' : 'บ';
      var showZenyTag = p.category==='item' && isZeny;
      return '<div class="items-pending-row" draggable="true" data-line-id="'+p.lineId+'">'+
        '<div class="items-pending-row-top"><span class="items-pending-name">'+itemImageNameHtml(lineImagePathById(p.lineId), itemNameWithSlots(p.name, p.slots), p.name)+(showZenyTag?zenyNameTag():'')+'</span><span class="items-pending-amount">'+fmtNum(dispTotal)+' '+unit+'</span></div>'+
        '<div class="items-pending-breakdown">'+fmtNum(p.qty)+' x '+fmtNum(dispRate)+' = '+fmtNum(dispTotal)+' '+unit+'</div>'+
        '<div class="items-pending-date">'+fmtDateTime(p.ts)+'</div>'+
      '</div>';
    }).join('');
  }

  function renderItemsWarehouseCards(){
    var serverId = App.itemsServerId;
    var allowed = hasTradePlan();
    ITEM_WAREHOUSE_TIERS.forEach(function(tier){
      document.getElementById('itemsTierCount'+tier).textContent = fmtNum(warehouseTierCount(serverId, tier)) + ' ชิ้น';
      var card = document.getElementById('itemsCardTier'+tier);
      if(card) card.classList.toggle('items-tier-locked', tier!==FREE_WAREHOUSE_TIER && !allowed);
    });
    var freeNote = document.getElementById('itemsTierFreeNote');
    if(freeNote){
      freeNote.hidden = allowed;
      if(!allowed){
        var used = warehouseStockFor(serverId)[FREE_WAREHOUSE_TIER].length;
        freeNote.textContent = 'แพ็กฟรี: ใส่ได้ '+used+'/'+FREE_WAREHOUSE_MAX_ITEMS+' รายการ';
      }
    }
  }

  function renderItemsDetail(){
    var titleText = document.getElementById('itemsDetailTitleText');
    var headingIcon = document.querySelector('#itemsDetailTitle .inventory-heading-icon');
    var list = document.getElementById('itemsDetailList');
    var tier = App.itemsSelectedTier;
    var detailCard = document.querySelector('#view-items .items-card-b');
    // Visual-only link between the selected warehouse and its detail panel.
    // Item data stays in the existing tier state and rendering path.
    ['a','b','c','d','e','s'].forEach(function(key){ detailCard.classList.toggle('items-detail-tier-'+key, tier===key.toUpperCase()); });
    ITEM_WAREHOUSE_TIERS.forEach(function(tierKey){
      var card = document.getElementById('itemsCardTier'+tierKey);
      if(card) card.classList.toggle('items-tier-selected', tierKey===tier);
    });
    if(!tier){
      titleText.textContent = 'รายการในคลัง';
      headingIcon.src = 'assets/treasure.png';
      list.innerHTML = '<p class="mr-empty">เลือกคลังเพื่อดูไอเทม</p>';
      return;
    }
    titleText.textContent = 'รายการในคลัง '+itemTierLabel(tier);
    // ใช้รูปเดียวกับที่การ์ดคลังนั้นๆ ใช้อยู่แล้ว (single source — ไม่ต้องทำ mapping ซ้ำ)
    var tierCardImg = document.querySelector('#itemsCardTier'+tier+' .items-card-a-art');
    if(tierCardImg) headingIcon.src = tierCardImg.getAttribute('src');
    var items = warehouseStockFor(App.itemsServerId)[tier];
    if(!items.length){ list.innerHTML = '<p class="mr-empty">ยังไม่มีไอเทมในคลังนี้</p>'; return; }
    var groups = {};
    var order = [];
    items.forEach(function(it){
      // Price/currency/exchange-rate are re-read live from the merchant log on every
      // render (falling back to the snapshot if the source line was since deleted) so
      // an edited price in history is reflected here without re-dropping the item.
      var found = findMerchantLineById(it.lineId);
      var price = found ? found.line.rate : it.price;
      var currency = found ? lineCurrency(found.line) : it.currency;
      var exchangeRate = found ? found.entry.exchangeRate : it.exchangeRate;
      var key = it.name+'|'+JSON.stringify(it.slots||[])+'|'+price+'|'+currency;
      if(!groups[key]){
        groups[key] = { name: it.name, slots: it.slots, price: price, currency: currency, qty: 0, latestTs: it.ts, recordIds: [], exchangeRate: exchangeRate };
        order.push(key);
      }
      var g = groups[key];
      if(!g.imagePath && found) g.imagePath = lineImagePath(found.line);
      g.qty += Math.max(1, Math.round(parseFloat(it.qty)||1));
      g.recordIds.push(it.id);
      if(it.ts >= g.latestTs){ g.latestTs = it.ts; g.exchangeRate = exchangeRate; }
    });
    order.sort(function(a,b){ return groups[b].latestTs - groups[a].latestTs; });
    list.innerHTML = order.map(function(key, idx){
      var g = groups[key];
      var isZeny = g.currency==='zeny';
      var rate = g.exchangeRate>0 ? g.exchangeRate : merchantExchangeRate(App.itemsServerId);
      var hasRate = isZeny && rate>0;
      var dispPrice = hasRate ? farmZenyToBaht(g.price, rate) : g.price;
      var total = g.qty * (parseFloat(dispPrice)||0);
      var unit = (isZeny && !hasRate) ? '<span style="color:'+MR_ZENY_COLOR+'">z</span>' : 'บ';
      var zenyBadge = isZeny ? zenyNameTag() : '';
      return '<div class="items-detail-row"><span>'+(idx+1)+'. '+itemImageNameHtml(g.imagePath, itemNameWithSlots(g.name, g.slots), g.name)+zenyBadge+'</span><span>'+fmtNum(g.qty)+' ชิ้น</span><span class="items-detail-right"><span class="items-detail-breakdown">'+fmtNum(g.qty)+' x '+fmtNum(dispPrice)+' = </span><span class="mono">'+fmtNum(total)+' '+unit+'</span><span class="items-detail-date">'+fmtDateTime(g.latestTs)+'</span><button type="button" class="items-undo-btn" data-undo-tier="'+tier+'" data-undo-ids="'+g.recordIds.join(',')+'" title="ย้อนกลับไปที่รายการที่รอลงคลังทั้งหมด">↩</button></span></div>';
    }).join('');
  }

  function renderItemsPage(){
    if(!App.session || !App.session.id) return;
    populateItemsServerSelect();
    renderItemsPendingList();
    renderItemsWarehouseCards();
    renderItemsDetail();
    updateItemsRailBadge();
  }

  function handleItemsDrop(warehouse, lineId){
    if(warehouse!==FREE_WAREHOUSE_TIER && !hasTradePlan()){
      toast('คลัง '+itemTierLabel(warehouse)+' ต้องมีแพ็กเกจที่มีสิทธิ์คลังไอเทม — สมัครเพื่อใช้คลังเพิ่มเติม');
      return;
    }
    var serverId = App.itemsServerId;
    if(warehouse===FREE_WAREHOUSE_TIER && !hasTradePlan() && warehouseStockFor(serverId)[warehouse].length >= FREE_WAREHOUSE_MAX_ITEMS){
      toast('บัญชีฟรีใส่คลังได้สูงสุด '+FREE_WAREHOUSE_MAX_ITEMS+' รายการ — สมัครแพ็กเกจเพื่อไม่จำกัด');
      return;
    }
    var item = itemsPendingList(serverId).filter(function(p){ return p.lineId===lineId; })[0];
    if(!item) return; // already claimed by another drop, or stale drag
    var w = warehouseStockFor(serverId);
    w[warehouse].push({ id:uid(), lineId:item.lineId, name:item.name, qty:item.qty, price:item.rate, total:item.total, currency:item.currency, ts:item.ts, slots:item.slots, exchangeRate:item.exchangeRate });
    addClaimedQty(serverId, item.lineId, parseFloat(item.qty)||0);
    saveItemWarehouseStock();
    saveItemLineClaimedQty();
    renderItemsPage();
    renderItemRows();
    toast('ใส่คลัง Item '+itemTierLabel(warehouse)+' แล้ว');
  }

  function undoWarehouseGroup(tier, ids){
    var w = warehouseStockFor(App.itemsServerId);
    var idSet = {};
    ids.forEach(function(id){ idSet[id] = true; });
    var removed = w[tier].filter(function(it){ return idSet[it.id]; });
    if(!removed.length) return;
    w[tier] = w[tier].filter(function(it){ return !idSet[it.id]; });
    // This is the one legitimate way claimed-qty ever goes back down — the user
    // explicitly said "put this back in the pending list", as opposed to a sale
    // (which keeps it claimed; it left the warehouse because it was sold, not
    // because it needs re-warehousing).
    removed.forEach(function(it){ addClaimedQty(App.itemsServerId, it.lineId, -(parseFloat(it.qty)||0)); });
    saveItemLineClaimedQty();
    saveItemWarehouseStock();
    renderItemsPage();
    renderItemRows();
    toast('ย้ายกลับไปที่รายการที่รอลงคลังแล้วทั้งหมด');
  }

  document.getElementById('itemsDetailList').addEventListener('click', function(e){
    var btn = e.target.closest('[data-undo-ids]');
    if(!btn) return;
    undoWarehouseGroup(btn.dataset.undoTier, btn.dataset.undoIds.split(','));
  });

  document.getElementById('itemsServerSelect').addEventListener('change', function(e){
    App.itemsServerId = e.target.value;
    saveItemsServer();
    App.itemsSelectedTier = null;
    renderItemsPage();
  });

  document.querySelectorAll('[data-view-tier]').forEach(function(btn){
    btn.addEventListener('click', function(){
      App.itemsSelectedTier = btn.dataset.viewTier;
      renderItemsDetail();
    });
  });

  document.getElementById('itemsPendingList').addEventListener('dragstart', function(e){
    var row = e.target.closest('.items-pending-row');
    if(!row) return;
    e.dataTransfer.setData('text/plain', row.dataset.lineId);
    e.dataTransfer.effectAllowed = 'move';
    row.classList.add('items-dragging');
  });
  document.getElementById('itemsPendingList').addEventListener('dragend', function(e){
    var row = e.target.closest('.items-pending-row');
    if(row) row.classList.remove('items-dragging');
  });

  document.querySelectorAll('.items-dropzone').forEach(function(zone){
    zone.addEventListener('dragover', function(e){
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      zone.classList.add('items-drag-over');
    });
    zone.addEventListener('dragleave', function(){
      zone.classList.remove('items-drag-over');
    });
    zone.addEventListener('drop', function(e){
      e.preventDefault();
      zone.classList.remove('items-drag-over');
      var lineId = e.dataTransfer.getData('text/plain');
      if(!lineId) return;
      handleItemsDrop(zone.dataset.warehouse, lineId);
    });
  });

  // ---------- page switching ----------
  var NAV_PAGES = ['home','farm','timers','items','pricing','admin','settings'];
  // อ่านชื่อหน้าจาก URL hash เอาไว้ทำ deep-link/ปุ่ม back-forward — กันไว้ไม่ยุ่งกับ hash ที่จริงๆ
  // เป็น token ของ Supabase (ลิงก์ยืนยันอีเมล/ลืมรหัสผ่าน ก็ใช้ # ต่อท้ายเหมือนกัน)
  function pageFromHash(){
    var h = location.hash.replace(/^#/, '');
    if(!h || /access_token|refresh_token|type=recovery|type=signup|error=/.test(h)) return '';
    return h;
  }
  // เข้าหน้าแรก: ย้าย util-bar (นาฬิกา/แต้ม/เมนูผู้ใช้) เข้าไปในกรอบ banner ให้เป็นพื้นหลังเดียวกับแถบต้อนรับ
  // ออกจากหน้าแรก: ย้ายกลับตำแหน่งเดิม (หน้า #view-home เองที่เป็นจุดอ้างอิงตำแหน่งเดิม อยู่คงที่เสมอ)
  var merchantTfPage = null, merchantTfUser = null;
  var farmTfPage = null, farmTfUser = null;
  // หน้าที่ผู้เยี่ยมชม (ยังไม่ล็อกอิน) เดินดูได้ — ตั้งค่า/แอดมินต้องล็อกอิน (ถูกพากลับหน้าแรก)
  var GUEST_PAGES = ['home','farm','timers','items','pricing'];
  function switchPage(page){
    if((!App.session || !App.session.id) && GUEST_PAGES.indexOf(page)===-1) page = 'home';
    Track.page(page);
    var tfUser = App.session ? App.session.id : null;
    var resetMerchantTf = page==='home' && (merchantTfPage!=='home' || merchantTfUser!==tfUser);
    merchantTfPage = page;
    merchantTfUser = tfUser;
    if(resetMerchantTf){
      resetMerchantHistoryRange();
      mrChartTimeframe = 'today';
      document.getElementById('mrChartTimeframeSelect').value = 'today';
    }
    // Share the existing announcement element without copying its IDs or handlers.
    var announcementPanel = document.getElementById('tickerTrack').closest('.panel-ticker');
    var announcementTarget = document.querySelector(page==='farm' ? '#view-farm .page-scroll' : '#view-home .page-scroll');
    if(announcementPanel.parentElement!==announcementTarget){
      announcementTarget.insertBefore(announcementPanel, announcementTarget.firstChild);
    }
    persist(App.keys.lastPage, page);
    document.getElementById('view-home').hidden = page !== 'home';
    document.getElementById('view-farm').hidden = page !== 'farm';
    document.getElementById('view-timers').hidden = page !== 'timers';
    document.getElementById('view-items').hidden = page !== 'items';
    document.getElementById('view-pricing').hidden = page !== 'pricing';
    document.getElementById('view-admin').hidden = page !== 'admin';
    document.getElementById('view-settings').hidden = page !== 'settings';
    if(page==='home') refreshAnnouncementsIfChanged();
    if(resetMerchantTf){ renderMerchantHistory(); renderMrChart(); }
    var resetFarmTf = page==='farm' && (farmTfPage!=='farm' || farmTfUser!==tfUser);
    farmTfPage = page;
    farmTfUser = tfUser;
    if(resetFarmTf){
      resetFarmTimeframes();
    }
    bossLiveSync();
    if(App.session && App.session.id){
      if(page==='farm') renderFarmPage();
      if(page==='items') renderItemsPage();
      if(page==='pricing') renderPricingPage();
      if(page==='admin') openAdminPage();
      if(page==='settings') renderSettingsPage();
      if(page==='timers') renderPartyPanel();
    } else if(page==='pricing') renderPricingPage();
    document.querySelectorAll('.rail-btn[data-page]').forEach(function(b){
      b.classList.toggle('active', b.dataset.page===page);
    });
    if(location.hash.slice(1) !== page) history.pushState({ page:page }, '', '#'+page);
  }
  // ปุ่ม back/forward ของเบราว์เซอร์: เปลี่ยนหน้าในแอพตาม hash ที่ browser พาไป (ไม่ push ซ้ำ เพราะ hash ตรงกันแล้ว)
  window.addEventListener('popstate', function(){
    if(document.getElementById('appScreen').hidden) return;
    var page = pageFromHash();
    var isAdmin = App.profile && App.profile.role === 'admin';
    if(NAV_PAGES.indexOf(page) === -1 || (page==='admin' && !isAdmin)) page = 'home';
    switchPage(page);
  });

  // ---------- เติมแพ็กเกจ ----------
  // Existing yearly prices are preserved; new packages have approved monthly prices only.
  var PRICING_PLANS = [
    { key:'free', name:'<span class="pricing-card-name-main">— ฟรี —</span><span class="pricing-card-name-sub">ทดลองใช้ทุกระบบ</span>', monthly:0, yearly:0, free:true,
      modules:['investor','items','farm','timers'],
      tagline:'เริ่มต้นทดลองใช้ระบบพื้นฐานได้ฟรี',
      features:[
        {divider:'บัญชีนักลงทุน'},
        'บันทึกรายการซื้อ–ขาย 5 รายการต่อวัน',
        'แสดงรายการทั้งหมดพร้อมคำนวณกำไรสุทธิ 1 วัน',
        'กราฟสรุปยอดแบบละเอียด 1 วัน',
        'จำกัดประวัติย้อนหลัง 1 วัน',
        {divider:'คลังไอเทม'},
        'ได้คลัง 1 กล่อง จำกัด 3 รายการ',
        {divider:'ยอดนักฟาม'},
        'บันทึกต้นทุน กำไร ได้ทั้งแบบ Zeny และบาท ไม่ต้องแยกบันทึก จำกัด 3 ครั้งต่อวัน',
        'กราฟสรุปยอดฟามแบบละเอียดใน 1 วัน',
        'ประวัติย้อนหลัง 1 วัน',
        {divider:'จับเวลาบอส'},
        'เพิ่มบอสได้ 1 ตัว',
        'ระบบเลือกบันทึกไอเทมที่ได้จากบอสแบบส่วนตัว',
        'แสดงยอดเงินที่ขายไอเทมบอส',
        'ประวัติย้อนหลัง',
        'เข้าร่วมปาร์ตี้บอส ดูเวลาบอสได้ไม่จำกัดจำนวนตัว',
        'จำกัดสิทธิการใช้งานในระบบปาร์ตี้',
        'ติดตามดูรายการส่วนแบ่งได้ในประวัติปาร์ตี้',
        'ปักหมุดจุดบอสตายบนแผนที่'
      ] },
    // New monthly-only packages are supported by Production buy_plan.
    { key:'farm', name:'<span class="pricing-card-name-main">— 1 in 1 —</span><span class="pricing-card-name-sub">บัญชียอดนักฟาม</span>', monthly:99, promoMonthly:99, badge:'สายฟาร์ม',
      modules:['farm'],
      tagline:'สายฟามห้ามพลาด', features:[
        'บันทึกยอดฟาม ต้นทุน กำไร ในแต่ละรอบ',
        'บันทึกได้ทั้งแบบ Zeny และบาท ไม่ต้องแยกบันทึก ไม่จำกัด',
        'บันทึกรายการต้นทุนไม่จำกัด',
        'บันทึกรายการไอเทมแรร์ไม่จำกัด',
        'กราฟสรุปยอดฟามแบบละเอียด รายวัน / รายสัปดาห์ / รายเดือน',
        'ระบบคำนวณยอดแบบละเอียดต่อกั้ม',
        'ระบบคำนวณยอดไอเทมแรร์เมื่อขายได้ทีหลัง',
        'ประวัติย้อนหลังไม่จำกัด',
        {divider:'หมวดอื่นๆ ใช้สิทธิ์แบบแพ็กฟรีทั้งหมด'}
      ] },
    { key:'accountItems', name:'<span class="pricing-card-name-main">— 2 in 1 —</span><span class="pricing-card-name-sub">บัญชีนักลงทุน/คลังไอเทม</span>', monthly:149, promoMonthly:149, badge:'จัดการซื้อขาย',
      modules:['investor','items'],
      tagline:'พ่อค้า-แม่ค้าหัวเครดิตและคนทั่วไป', features:[
        'บันทึกรายการซื้อ–ขาย M / ไอเทม / อื่นๆ ไม่จำกัด',
        'ดูรายการทั้งหมดพร้อมคำนวณกำไรสุทธิ',
        'แสดงจำนวนไอเทม ต้นทุนค้าง และราคาเฉลี่ยที่รับมา',
        'เพิ่ม–ตัดสต็อกไอเทมอัตโนมัติเมื่อซื้อเข้า–ขายออก',
        'สรุปยอดซื้อมา–ขายไปแบบครบถ้วนในกรอบเดียว',
        'กราฟสรุปยอดแบบละเอียดยิบ',
        '6 คลังไอเทมแยกสัดส่วนชัดเจน',
        'จัดการไอเทมคงเหลือได้แบบเป็นสัดส่วน',
        'รองรับการเพิ่มจำนวนเซิร์ฟเวอร์ได้ไม่จำกัด',
        'แบ่งแยกข้อมูลบัญชีตามเซิร์ฟเวอร์ชัดเจน',
        'แบ่งคลังแยกได้ไม่จำกัดจำนวนเซิร์ฟเวอร์โดยไม่ซ้ำคลังกัน',
        {divider:'หมวดอื่นๆ ใช้สิทธิ์แบบแพ็กฟรีทั้งหมด'}
      ] },
    { key:'bundle', name:'<span class="pricing-card-name-main">— 3 in 1 —</span><span class="pricing-card-name-sub">บัญชีนักลงทุน/คลังไอเทม/ยอดนักฟาม</span>', monthly:199, yearly:1990, promoMonthly:99, promoYearly:990, badge:'ยอดนิยม',
      // แพ็กรวม: บอกว่าได้ระบบไหนบ้างด้วยแถวระบบ (modules) แทนรายการฟีเจอร์ยาว — ระบบที่ไม่ได้แสดงเป็นสีเทา
      modules:['investor','items','farm'],
      // รายละเอียด (ส่วนที่กดดูได้) = รวมรายการของแพ็กย่อยที่อยู่ในแพ็กนี้ แบ่งหัวข้อตามระบบ
      detailFrom:[['ยอดนักฟาม','farm'],['บัญชีนักลงทุน / คลังไอเทม','accountItems']] },
    { key:'timers', name:'จับเวลาบอส', monthly:199, yearly:1990, promoMonthly:99, promoYearly:990, badge:'สายล่าบอส',
      modules:['timers'],
      tagline:'ระบบล่าบอสครบในทีเดียว',
      features:[
        'เพิ่มบอสได้ไม่จำกัดจำนวน',
        'เพิ่มบอสแบบ Custom ได้ไม่จำกัด',
        'ระบบเสียงแจ้งเตือน',
        'ระบบเลือกบันทึกไอเทมที่ได้จากบอสแบบส่วนตัว/ปาร์ตี้',
        'แสดงยอดเงินที่หารแบบเป็นสัดส่วน ทั้งแบบส่วนตัว/ปาร์ตี้',
        'ประวัติการฆ่าบอสทั้งหมด',
        'ประวัติไอเทมและยอดขายไอเทมบอสทั้งหมด',
        'ไม่จำกัดสิทธิการใช้งานในระบบปาร์ตี้',
        'ติดตามส่วนแบ่งของปาร์ตี้',
        'ปักหมุดจุดบอสตายบนแผนที่'
      ] },
    { key:'all', name:'<span class="pricing-card-name-main">— 4 in 1 —</span><span class="pricing-card-name-sub">บัญชีนักลงทุน/คลังไอเทม/ยอดนักฟาม/จับเวลาบอส</span>', monthly:349, yearly:3490, promoMonthly:175, promoYearly:1750, best:true, badge:'แนะนำ · คุ้มที่สุด',
      modules:['investor','items','farm','timers'],
      detailFrom:[['ยอดนักฟาม','farm'],['บัญชีนักลงทุน / คลังไอเทม','accountItems'],['จับเวลาบอส','timers']] }
  ];
  // แถวระบบในการ์ดแพ็กรวม — ไอคอนชุดเดียวกับเมนูด้านซ้าย (ยอดนักฟาม = ธนู, จับเวลาบอส = นาฬิกา)
  var PRICING_MODULES = [
    { key:'investor', name:'บัญชีนักลงทุน',
      icon:'<rect x="2" y="4" width="17" height="13" rx="2"/><path d="M7 6v10"/><path d="M9 8.3c-.5-.7-1.6-1-2.5-.7-1.3.4-1.7 1.8-.6 2.5.6.4 1.6.5 2.4.7 1.3.4 1.7 1.8.4 2.5-.9.5-2 .3-2.6-.4"/><path d="M12 7.5h5"/><path d="M12 10.5h3"/><path d="M14 21h3l6-6a2 2 0 00-3-3l-6 6z"/><path d="M18.5 13.5l3 3"/>' },
    { key:'items', name:'คลังไอเทม',
      icon:'<path d="M3 8l9-4 9 4-9 4-9-4z"/><path d="M3 8v8l9 4 9-4V8"/>' },
    { key:'farm', name:'ยอดนักฟาม',
      icon:'<path d="M17 3h4v4m0-4L6 18m-3 0h3v3m10.5-1c1.576-1.576 2.5-4.095 2.5-6.5C19 8.69 15.31 5 10.5 5C8.085 5 5.578 5.913 4 7.5z"/>' },
    { key:'timers', name:'จับเวลาบอส',
      icon:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>' }
  ];
  function pricingModulesHtml(p){
    if(!p.modules) return '';
    return '<ul class="pricing-modules">'+PRICING_MODULES.map(function(m){
      var on = p.modules.indexOf(m.key) !== -1;
      // การ์ดฟรี: ได้ทุกระบบแต่จำกัดสิทธิ์ — แถวปกติ ติ๊กสีเหลือง
      var limited = on && p.free;
      return '<li class="pricing-module'+(on?'':' pricing-module-off')+(limited?' pricing-module-limited':'')+'">'+
        '<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+m.icon+'</svg>'+
        '<span class="pricing-module-text"><b>'+m.name+'</b><small>'+(limited ? 'จำกัดสิทธิการใช้งาน' : on ? 'ใช้งานแบบไม่จำกัด' : 'ใช้สิทธิ์แบบแพ็กฟรี')+'</small></span>'+
        '<span class="pricing-module-mark" aria-label="'+(limited?'ได้แบบจำกัด':on?'ได้':'ไม่ได้')+'">'+(on?'✓':'—')+'</span>'+
      '</li>';
    }).join('')+'</ul>';
  }
  var pricingCycle = 'monthly';
  var pricingDetailsOpen = false; // รายละเอียดในการ์ดแพ็กทุกใบ ซ่อนไว้เป็นค่าเริ่มต้น

  // วันสิ้นสุดโปร (ระบุเขตเวลา) — หลังจากนี้หน้าเว็บแสดงราคาปกติ และเซิร์ฟเวอร์ (buy_plan → promo_active) หักราคาปกติ
  // ฝั่งเซิร์ฟเวอร์ตั้งให้สิ้นสุดช้ากว่านี้ 5 นาที กันนาฬิกาเครื่องผู้ใช้เร็วกว่าแล้วโดนหักแพงกว่าราคาที่เห็น
  // ถ้าจะเลื่อนวันโปร ต้องแก้ทั้งค่านี้และฟังก์ชัน promo_active ในฐานข้อมูลให้ตรงกัน
  var PROMO_END_AT = '2026-10-31T23:59:59+07:00';
  function isPromoActive(){
    var end = PROMO_END_AT ? Date.parse(PROMO_END_AT) : NaN;
    return Number.isFinite(end) ? Date.now() <= end : true;
  }
  var promoWasActive = null;
  function updatePricingPromoCountdown(){
    var promoActive = isPromoActive();
    var promoBanner = document.querySelector('#view-pricing .pricing-promo-banner');
    if(promoBanner) promoBanner.style.display = promoActive ? '' : 'none';
    // โปรหมดตอนเปิดหน้านี้ค้างอยู่ → วาดการ์ดราคาใหม่เป็นราคาปกติทันที
    if(promoWasActive !== null && promoWasActive !== promoActive) renderPricingPage();
    promoWasActive = promoActive;
    var status = document.getElementById('pricingPromoStatus');
    var digits = document.getElementById('pricingPromoDigits');
    var end = PROMO_END_AT ? Date.parse(PROMO_END_AT) : NaN;
    if(!Number.isFinite(end)){
      status.textContent = 'รอกำหนดวันสิ้นสุดโปรโมชั่น';
      digits.hidden = true;
      return;
    }
    var remaining = Math.max(0, Math.ceil((end-Date.now())/1000));
    digits.hidden = remaining===0;
    status.textContent = remaining===0 ? 'โปรโมชั่นสิ้นสุดแล้ว' : 'เหลือเวลาอีก';
    var values = [Math.floor(remaining/86400),Math.floor(remaining/3600)%24,Math.floor(remaining/60)%60,remaining%60];
    ['Days','Hours','Minutes','Seconds'].forEach(function(unit,i){
      document.getElementById('pricingPromo'+unit).textContent = String(values[i]).padStart(2,'0');
    });
  }
  updatePricingPromoCountdown();
  setInterval(updatePricingPromoCountdown,1000);

  // แพ็กเกจนี้ "ใช้งานอยู่แล้ว" ถึงเมื่อไหร่ — ใช้เตือนในหน้าเติมแพ็กเกจกันกดซื้อซ้ำโดยไม่รู้ตัว
  // (ไม่บล็อกปุ่มซื้อ เพราะกดซื้อซ้ำจริงๆ ระบบจะต่ออายุเพิ่มให้ ไม่ได้เสียแต้มเปล่า)
  function planActiveUntil(key){
    var p = App.profile; if(!p) return 0;
    if(p.role==='admin' || p.legacy_unlimited===undefined || p.legacy_unlimited) return Infinity;
    var now = Date.now();
    var bundle = new Date(p.plan_bundle_expires_at||0).getTime();
    var timers = new Date(p.plan_timers_expires_at||0).getTime();
    var scoped = p.feature_expiries||{};
    var farm = new Date(scoped.farm||0).getTime();
    var acct = new Date(scoped.accountItems||0).getTime();
    var bundleActive = bundle>now, timersActive = timers>now;
    switch(key){
      case 'bundle': return bundleActive ? bundle : 0;
      case 'timers': return timersActive ? timers : 0;
      case 'all': return (bundleActive && timersActive) ? Math.min(bundle,timers) : 0;
      case 'farm': return Math.max(bundleActive?bundle:0, farm>now?farm:0);
      case 'accountItems': return Math.max(bundleActive?bundle:0, acct>now?acct:0);
      default: return 0;
    }
  }
  function renderPricingPage(){
    var grid = document.getElementById('pricingGrid');
    grid.innerHTML = [PRICING_PLANS[4],PRICING_PLANS[3],PRICING_PLANS[5]].concat(PRICING_PLANS.slice(0,3)).map(function(p){
      var monthly = pricingCycle==='monthly' || (p.yearly == null && p.displayYearly == null);
      var unit = monthly ? '/ เดือน' : '/ ปี';
      // แพ็กรวม (3 in 1 / 4 in 1) ไม่มีรายการของตัวเอง — ดึงรายการของแพ็กย่อยมารวม ใส่หัวข้อระบบคั่น
      // (ตัดบรรทัด "หมวดอื่นๆ ใช้สิทธิ์แบบแพ็กฟรี" ของแพ็กย่อยทิ้ง เพราะแพ็กรวมได้ระบบนั้นครบแล้ว)
      var featureList = p.detailFrom ? p.detailFrom.reduce(function(out, pair){
        var src = PRICING_PLANS.find(function(x){ return x.key===pair[1]; });
        return out.concat([{divider:pair[0]}], ((src && src.features)||[]).filter(function(f){ return !(f && f.divider); }));
      }, []) : (p.features||[]);
      var features = featureList.map(function(f){
        if(f && f.divider) return '<li class="pricing-feature-divider">'+escapeHtml(f.divider)+'</li>';
        if(f && f.no) return '<li class="pricing-feature-no"><span class="pricing-cross">✕</span><span>'+escapeHtml(f.no)+'</span></li>';
        return '<li><span class="pricing-check">✓</span><span>'+escapeHtml(f)+'</span></li>';
      }).join('');
      var taglineHtml = p.tagline ? '<div class="pricing-card-tagline">'+escapeHtml(p.tagline)+'</div>' : '';
      var ownedUntil = p.free ? 0 : planActiveUntil(p.key);
      var priceHtml, ctaHtml;
      if(p.free){
        // โครงเดียวกับการ์ดจ่ายเงิน (ราคา + ป้ายเขียว) ให้แถวระบบ/ปุ่มอยู่ระดับเดียวกับการ์ดข้างๆ
        priceHtml = '<div class="pricing-card-price"><span class="pricing-card-amount">0</span><span class="pricing-card-unit"> บ '+unit+'</span></div>'+
          '<div class="pricing-perday">ใช้ฟรีตลอด ไม่มีวันหมดอายุ</div>';
        ctaHtml = '<button type="button" class="btn btn-ghost btn-block pricing-cta" disabled>เริ่มใช้ฟรี</button>';
      } else {
        var original = monthly ? p.monthly : (p.yearly == null ? p.displayYearly : p.yearly);
        var price = isPromoActive() ? (monthly ? p.promoMonthly : (p.yearly == null ? p.displayPromoYearly : p.promoYearly)) : original;
        var perDay = price / (monthly ? 30 : 365);
        priceHtml = (original > price ? '<div class="pricing-card-price"><span class="pricing-original">'+fmtNum(original)+' บ'+unit+'</span><span class="pricing-promo-badge">ลด 50%</span></div>' : '')+
          '<div class="pricing-card-price"><span class="pricing-card-amount">'+fmtNum(price)+'</span><span class="pricing-card-unit"> บ '+unit+'</span></div>'+
          '<div class="pricing-perday">เฉลี่ย ~'+perDay.toFixed(1)+' บ/วัน</div>';
        // มีแพ็กนี้อยู่แล้ว = กดซื้อคือต่ออายุ — บอกตรงๆ บนปุ่ม พร้อมราคาแต้ม
        var ctaLabel = (ownedUntil ? 'ต่ออายุ' : 'ซื้อเลย')+' · '+fmtNum(price)+' แต้ม';
        // p.name อาจมี <span> ฝังไว้กันตัดคำกลางคำ (การ์ด 4 in 1) — ตัด tag ออกก่อนใส่ใน attribute
        // เพราะ data-plan-name ใช้เป็นข้อความล้วนในกล่องยืนยัน/toast ไม่ใช่ HTML ที่ต้อง render
        var planNamePlain = p.name.replace(/<[^>]*>/g, '');
        ctaHtml = p.yearly==null && pricingCycle==='yearly'
          ? (p.displayYearly != null ? '<small class="pricing-pending-note">รอเปิดใช้งานการซื้อรายปี</small><button type="button" class="btn btn-ghost btn-block pricing-cta" disabled>ยังไม่เปิดซื้อรายปี</button>' : '<small class="pricing-pending-note">แสดงราคาต่อเดือน · ยังไม่มีแพ็กรายปี</small><button type="button" class="btn btn-ghost btn-block pricing-cta" disabled>รองรับเฉพาะรายเดือน</button>')
          : '<button type="button" class="btn btn-ghost btn-block pricing-cta" data-price="'+price+'" data-plan-name="'+escapeHtml(planNamePlain)+'" data-plan-key="'+p.key+'" data-cycle="'+pricingCycle+'">'+ctaLabel+'</button>';
      }
      // มีแพ็กนี้อยู่แล้ว: ป้ายสีเขียวบอกวันหมดอายุ (ไม่บล็อกปุ่ม — กดซื้อซ้ำ = ต่ออายุเพิ่ม)
      var ownedHtml = ownedUntil ? '<div class="pricing-owned-note">✓ ใช้งานอยู่'+(ownedUntil===Infinity ? ' (ไม่จำกัดเวลา)' : ' ถึง '+fmtDate(ownedUntil))+'</div>' : '';
      return '<div class="pricing-card'+(p.best?' pricing-card-best':'')+'" data-plan-key="'+p.key+'">'+
        (p.badge ? '<span class="pricing-badge-best'+(p.best?'':' pricing-badge-secondary')+'">'+escapeHtml(p.badge)+'</span>' : '')+
        (p.key==='bundle' || p.key==='timers' || p.key==='all' ? '<div class="pricing-promo-heading">' : '')+
        '<div class="pricing-card-name">'+p.name+'</div>'+
        taglineHtml+
        (p.key==='bundle' || p.key==='timers' || p.key==='all' ? '</div>' : '')+
        '<div class="pricing-bundle-price">'+priceHtml+'</div>'+
        pricingModulesHtml(p)+
        // รายละเอียดซ่อนไว้ก่อนทุกใบ กดปุ่มเดียวกางพร้อมกันทุกใบ (การ์ดแถวเดียวกันสูงเท่ากันเสมอ)
        (features
          ? '<button type="button" class="pricing-details-toggle" aria-expanded="'+pricingDetailsOpen+'">'+(pricingDetailsOpen ? 'ซ่อนรายละเอียด ▴' : 'ดูรายละเอียด ▾')+'</button>'+
            (pricingDetailsOpen ? '<ul class="pricing-features">'+features+'</ul>' : '<div class="pricing-features-spacer"></div>')
          : '<div class="pricing-features-spacer"></div>')+
        ownedHtml+
        ctaHtml+
      '</div>';
    }).join('');
  }

  document.getElementById('pricingGrid').addEventListener('click', function(e){
    if(!e.target.closest('.pricing-details-toggle')) return;
    pricingDetailsOpen = !pricingDetailsOpen;
    renderPricingPage();
  });

  document.getElementById('pricingCycleToggle').addEventListener('click', function(e){
    var btn = e.target.closest('[data-cycle]');
    if(!btn) return;
    pricingCycle = btn.dataset.cycle;
    document.querySelectorAll('#pricingCycleToggle .seg-btn').forEach(function(b){
      b.classList.toggle('active', b===btn);
    });
    renderPricingPage();
  });

  // ซื้อแพ็กเกจด้วยแต้ม: RPC buy_package หักแต้ม + ต่ออายุ (30/365 วัน ต่อจากวันหมดอายุเดิมถ้ายังไม่หมด) + บันทึกประวัติ
  // ราคาจริงอยู่ฝั่งเซิร์ฟเวอร์ ตัวเลขในหน้านี้ใช้แสดงผลเท่านั้น
  document.getElementById('pricingGrid').addEventListener('click', function(e){
    var btn = e.target.closest('.pricing-cta');
    if(!btn) return;
    var selectedPlan = PRICING_PLANS.find(function(p){ return p.key===btn.dataset.planKey; });
    if(!selectedPlan || selectedPlan.free || selectedPlan.pending || btn.disabled) return;
    if(selectedPlan.yearly==null && btn.dataset.cycle!=='monthly') return;
    var price = parseInt(btn.dataset.price, 10) || 0;
    var planName = btn.dataset.planName, planKey = btn.dataset.planKey, cycle = btn.dataset.cycle;
    var days = cycle === 'yearly' ? 365 : 30;
    var have = App.profile ? (App.profile.points||0) : 0;
    Track.push('buy_click', 'pricing', price, planKey+':'+cycle);
    if(have < price){
      Track.push('buy_insufficient', 'pricing', price, planKey+':'+cycle);
      toast('แต้มไม่พอ ขาดอีก '+fmtNum(price-have)+' แต้ม — เติมแต้มก่อนนะ');
      openTopup();
      return;
    }
    var profile = App.profile || {};
    var scoped = profile.feature_expiries || {};
    var bundleExp = new Date(profile.plan_bundle_expires_at||0).getTime() || 0;
    var timersExp = new Date(profile.plan_timers_expires_at||0).getTime() || 0;
    var expiries = {bundle:bundleExp,timers:timersExp,farm:Math.max(bundleExp,new Date(scoped.farm||0).getTime()||0),accountItems:Math.max(bundleExp,new Date(scoped.accountItems||0).getTime()||0),all:Math.min(bundleExp,timersExp)};
    var curExp = expiries[planKey] || 0;
    function addCycle(base){
      var d=new Date(Math.max(base,Date.now()));
      if(cycle==='yearly') d.setFullYear(d.getFullYear()+1);
      else d.setDate(d.getDate()+30);
      return d.getTime();
    }
    var newExp = addCycle(curExp);
    var expiryText = planKey==='all'
      ? '3 ระบบ: ถึงประมาณ '+fmtDate(addCycle(bundleExp))+'<br>จับเวลาบอส: ถึงประมาณ '+fmtDate(addCycle(timersExp))
      : 'ใช้งานได้ถึงประมาณ '+fmtDate(newExp);
    var discounted = (cycle==='yearly'?selectedPlan.yearly:selectedPlan.monthly)>price;
    showConfirm('ยืนยันสมัคร "'+escapeHtml(planName)+'" ('+(cycle==='yearly' ? 'รายปี +1 ปี' : 'รายเดือน +30 วัน')+') ด้วย '+fmtNum(price)+' แต้ม'+(discounted?' (ราคาโปรลด 50%)':'')+'?<br>'+expiryText, function(){
      supa.rpc('buy_plan', { p_plan_key: planKey, p_cycle: cycle }).then(function(res){
        if(res.error){ toast('ทำรายการไม่สำเร็จ: '+res.error.message); return; }
        Track.push('buy_success', 'pricing', price, planKey+':'+cycle);
        refreshProfile().then(renderPricingPage);
        toast('สมัคร '+planName+' สำเร็จ — '+(planKey==='all'?'ใช้งานครบทุกระบบได้ถึง ':'ใช้งานได้ถึง ')+fmtDate(new Date(res.data).getTime()));
      });
    });
  });

  // ---------- หน้า "ตั้งค่า": ข้อมูลบัญชี / เปลี่ยนรหัสผ่าน / ประวัติเติมแต้ม / ประวัติซื้อแพ็กเกจ ----------
  var fmtFullDate = function(v){ return new Date(v).toLocaleDateString('th-TH', { day:'numeric', month:'long', year:'numeric' }); };
  var TOPUP_STATUS = {
    credited:['สำเร็จ','ok'],
    reversed:['ยกเลิกแล้ว','expired'],
    pending:['รอชำระ','soon'],
    expired:['หมดอายุ','expired'],
    failed:['ไม่สำเร็จ','expired'],
    manual_review:['รอตรวจสอบ','soon']
  };
  var HIST_PAGE = 5;
  var stHistExpanded = { topup:false, purchase:false, points:false, promo:false };
  // Display only: derive package rows from existing entitlement expiries.
  function settingsPackageRows(profile, now){
    var p=profile||{}, scoped=p.feature_expiries||{};
    var expiry=function(value){ var t=new Date(value||0).getTime(); return t>now?t:0; };
    var bundle=expiry(p.plan_bundle_expires_at), timers=expiry(p.plan_timers_expires_at), rows=[];
    if(bundle && timers && bundle===timers) rows.push({name:'4 in 1 — ครบทั้ง 4 ระบบ',expiry:bundle});
    else {
      if(bundle) rows.push({name:'3 in 1',expiry:bundle});
      if(timers) rows.push({name:'จับเวลาบอส',expiry:timers});
    }
    [['farm','1 in 1 — ยอดนักฟาม'],['accountItems','2 in 1 — บัญชีนักลงทุน + คลังไอเทม']].forEach(function(pair){
      var end=expiry(scoped[pair[0]]);
      if(end>bundle) rows.push({name:pair[1],expiry:end});
    });
    return rows.length?rows:[{name:'ฟรี',expiry:0}];
  }
  function renderSettingsPackages(){
    var root=document.getElementById('stPackageList');
    if(!root) return;
    var p=App.profile||{}, now=Date.now();
    root.replaceChildren();
    settingsPackageRows(p,now).forEach(function(plan){
      var row=document.createElement('div'); row.className='settings-package-row';
      var info=document.createElement('div');
      var name=document.createElement('div'); name.className='settings-package-name'; name.textContent=plan.name;
      var meta=document.createElement('div'); meta.className='settings-package-meta';
      var remaining=Math.max(0,plan.expiry-now), soon=plan.expiry && remaining<=7*86400000;
      var badge=document.createElement('span'); badge.className='membership-pill '+(soon?'soon':plan.expiry?'ok':'neutral');
      badge.textContent=plan.expiry?(soon?'ใกล้หมดอายุ':'ใช้งานอยู่'):'ใช้งานฟรี';
      var time=document.createElement('span'); time.className='settings-package-time'+(soon?' soon':'');
      time.textContent=plan.expiry?'คงเหลือ '+Math.floor(remaining/86400000)+' วัน '+(Math.floor(remaining/3600000)%24)+' ชม.':'คงเหลือ: ไม่จำกัด';
      meta.append(badge,time);
      if(plan.expiry){ var date=document.createElement('span'); date.className='settings-package-expiry'; date.textContent='หมดอายุ: '+fmtDate(plan.expiry); meta.append(date); }
      info.append(name,meta);
      var link=document.createElement('a'); link.className='btn btn-ghost btn-sm settings-package-link'+(plan.expiry?'':' settings-package-upgrade'); link.href='#pricing'; link.textContent=plan.expiry?'ดูแพ็กเกจ / ต่ออายุ':'อัปเกรดแพ็กเกจ';
      row.append(info,link); root.append(row);
    });
    var note=document.getElementById('stPackageAccessNote');
    note.hidden=!(p.role==='admin'||p.legacy_unlimited);
    note.textContent=p.role==='admin'?'บัญชีนี้มีสิทธิ์ผู้ดูแลระบบเพิ่มเติมจากแพ็กเกจที่แสดง':'บัญชีนี้มีสิทธิ์เดิมแบบไม่จำกัดเพิ่มเติมจากแพ็กเกจที่แสดง';
  }
  setInterval(function(){ if(!document.getElementById('view-settings').hidden) renderSettingsPackages(); },60000);
  function renderSettingsPage(){
    renderSettingsPackages();
    var p = App.profile || {};
    document.getElementById('stUsername').textContent = p.username || '-';
    document.getElementById('stEmail').textContent = App.session ? App.session.email : '-';
    document.getElementById('stBirth').textContent = p.birth_date ? fmtFullDate(p.birth_date+'T00:00:00') : 'ยังไม่ได้กรอก';
    document.getElementById('stExpires').textContent = p.expires_at ? (isNoExpiry(p.expires_at) ? 'ไม่จำกัด' : fmtDate(new Date(p.expires_at).getTime())) : '-';
    document.getElementById('stDisplayName').value = p.display_name || '';
    document.getElementById('stFacebookUrl').value = p.facebook_url || '';
    // บัญชีเก่าที่สมัครก่อนมีช่องวันเกิด: กรอกได้ครั้งเดียว พอมีค่าแล้วช่องจะหายไป
    document.getElementById('stBirthField').hidden = !!p.birth_date;
    if(p.birth_date) document.getElementById('stBirthInput').value = '';
    renderServerChips(document.getElementById('stServerList'), p.servers||[]);
    updateServersSummary();
    renderRetiredServerVisibility();
    loadTopupHistory();
    loadPurchaseHistory();
    loadPointsHistory();
    loadPromoHistory();
  }
  // ---------- เซิร์ฟเวอร์เก่า (พัก) ที่มีประวัติ: ติ๊กเปิดกลับให้โผล่ใน dropdown ประวัติ/กราฟ ----------
  // (ค่าเริ่มต้นซ่อนหมด — ดู isHistoryServerShown, visibleRetiredServerIds) รวมทั้งเซิร์ฟที่เคยมีประวัติ
  // ซื้อ-ขาย และเคยมีประวัติฟาม เข้าด้วยกัน เพราะติ๊กตัวเดียวคุมทั้งสองหน้า
  function retiredServerHistoryCandidates(){
    var ids = [];
    rawHistoryServerIds().concat(rawFarmServerIds()).forEach(function(id){
      if(isRetiredServer(id) && ids.indexOf(id)===-1) ids.push(id);
    });
    return ids;
  }
  function renderRetiredServerVisibility(){
    var card = document.getElementById('stRetiredServerCard');
    var root = document.getElementById('stRetiredServerList');
    card.hidden = false;
    var candidates = retiredServerHistoryCandidates();
    if(!candidates.length){ root.innerHTML = '<p class="empty-note">ยังไม่มีเซิร์ฟเวอร์เก่าที่มีประวัติ</p>'; return; }
    var visible = visibleRetiredServerIds();
    root.innerHTML = candidates.map(function(id){
      var on = visible.indexOf(id)!==-1;
      var sv = serverRateById(id);
      return '<button type="button" class="share-chip'+(on?' on':'')+'" data-retired-server-pick="'+id+'">'+(on?'✓ ':'')+escapeHtml(sv?sv.name:id)+'</button>';
    }).join('');
  }
  document.addEventListener('click', function(e){
    var chip = e.target.closest('[data-retired-server-pick]');
    if(!chip) return;
    var id = chip.dataset.retiredServerPick;
    var show = !chip.classList.contains('on');
    setRetiredServerVisible(id, show);
    chip.classList.toggle('on', show);
    chip.textContent = (show ? '✓ ' : '') + chip.textContent.replace(/^✓ /, '');
    // ไม่ต้องรีเฟรชหน้าอื่นตรงนี้ — หน้าประวัติ/กราฟ/ฟาม อ่านค่านี้ใหม่เองทุกครั้งที่เข้าไปดู (populateHistoryServerFilter ฯลฯ)
  });
  // ---------- เซิร์ฟเวอร์ที่เล่น: ชิปเลือกได้หลายอัน ใช้ทั้ง popup ตอนสมัคร/ล็อกอินครั้งแรก และหน้าตั้งค่า ----------
  // ปิดให้บริการแล้ว = ไม่โชว์เป็นตัวเลือกใหม่ แต่ถ้าบัญชีนี้มีอยู่แล้วต้องยังเห็น/เอาออกเองได้
  // ✓ สีทอง (var(--warn)) แยกจากสีของชื่อเซิร์ฟ — เก็บชื่อดิบไว้ใน data-server-label เพื่อสลับ ✓
  // เข้า/ออกตอนคลิกโดยไม่ต้องแกะ textContent เดิม (กันเผลอทำ HTML ของ span เพี้ยน)
  function chipLabelHtml(on, label){
    return (on ? '<span class="chip-check-gold">✓</span> ' : '') + escapeHtml(label);
  }
  function renderServerChips(root, selected){
    if(!SERVER_RATES.length){ root.innerHTML = '<p class="empty-note">ยังไม่มีเซิร์ฟเวอร์ในระบบ</p>'; return; }
    var visible = SERVER_RATES.filter(function(s){ return s.active || selected.indexOf(s.id)!==-1; });
    root.innerHTML = visible.map(function(s){
      var on = selected.indexOf(s.id)!==-1;
      var label = s.name+(s.active?'':' (ปิดให้บริการ)');
      return '<button type="button" class="share-chip'+(on?' on':'')+'" data-server-pick="'+s.id+'" data-server-label="'+escapeHtml(label)+'">'+chipLabelHtml(on, label)+'</button>';
    }).join('');
    syncServerPickLimit(root);
  }
  // เลือกได้ไม่เกินโควต้า — พอครบแล้วปิดชิปที่ยังไม่ได้เลือกไว้ก่อน (ฝั่ง DB ก็กันซ้ำอีกชั้น)
  function syncServerPickLimit(root){
    var quota = serverQuota();
    var chips = Array.prototype.slice.call(root.querySelectorAll('[data-server-pick]'));
    var onCount = chips.filter(function(c){ return c.classList.contains('on'); }).length;
    chips.forEach(function(c){
      var full = onCount >= quota && !c.classList.contains('on');
      c.classList.toggle('chip-locked', full);
      c.disabled = full;
      c.title = full ? 'โควต้าเต็ม ('+quota+' เซิร์ฟเวอร์) — ซื้อเพิ่มได้ที่ปุ่ม "+ เพิ่มเซิร์ฟเวอร์" หน้าแรก' : '';
    });
    var hint = root.parentNode && root.parentNode.querySelector('[data-server-quota-hint]');
    if(hint) hint.textContent = 'เลือกได้ '+onCount+'/'+quota+' เซิร์ฟเวอร์';
  }
  function pickedServers(root){
    return Array.prototype.map.call(root.querySelectorAll('.share-chip.on'), function(b){ return b.dataset.serverPick; });
  }
  function updateServersSummary(){
    var el = document.getElementById('stServersSummary');
    var count = (App.profile && App.profile.servers || []).length;
    el.textContent = 'เล่นอยู่ '+count+'/'+serverQuota();
    // ครบเพดานแล้วปิดปุ่มซื้อช่อง กันกดซื้อเกินจนเสียแต้มฟรี
    var btn = document.getElementById('stAddServerSlotBtn');
    var full = serverQuota() >= MAX_RATE_CHIP_SLOTS;
    btn.disabled = full;
    btn.textContent = full ? 'ครบ '+MAX_RATE_CHIP_SLOTS+' ช่องแล้ว' : '+ เพิ่มเซิร์ฟเวอร์';
  }
  document.addEventListener('click', function(e){
    var chip = e.target.closest('[data-server-pick]');
    if(!chip) return;
    if(chip.disabled) return;
    var on = chip.classList.toggle('on');
    chip.innerHTML = chipLabelHtml(on, chip.dataset.serverLabel);
    if(chip.parentNode) syncServerPickLimit(chip.parentNode);
  });
  function saveServers(root, errEl, onDone){
    var ids = pickedServers(root);
    if(!ids.length){ if(errEl) errEl.textContent = 'เลือกอย่างน้อย 1 เซิร์ฟเวอร์'; else toast('เลือกอย่างน้อย 1 เซิร์ฟเวอร์'); return; }
    if(errEl) errEl.textContent = '';
    supa.rpc('set_my_servers', { p_servers: ids }).then(function(res){
      if(res.error){ if(errEl) errEl.textContent = 'บันทึกไม่สำเร็จ: '+res.error.message; else toast('บันทึกไม่สำเร็จ: '+res.error.message); return; }
      return refreshProfile().then(onDone);
    });
  }
  function openServerPick(){
    renderServerChips(document.getElementById('serverPickList'), (App.profile && App.profile.servers) || []);
    document.getElementById('serverPickError').textContent = '';
    document.getElementById('serverPickOverlay').hidden = false;
  }
  document.getElementById('serverPickSaveBtn').addEventListener('click', function(){
    saveServers(document.getElementById('serverPickList'), document.getElementById('serverPickError'), function(){
      document.getElementById('serverPickOverlay').hidden = true;
      updateServersSummary();
      toast('บันทึกเซิร์ฟเวอร์ที่เล่นแล้ว');
    });
  });
  document.getElementById('stSaveServers').addEventListener('click', function(){
    saveServers(document.getElementById('stServerList'), null, function(){
      // เซิร์ฟที่เล่นเปลี่ยน = ทุก dropdown เลือกเซิร์ฟต้องอัปเดตตามทันที ไม่ต้องรีเฟรชหน้า
      pruneServerSelections(true);
      renderSettingsPage();
      renderAll();
      toast('บันทึกเซิร์ฟเวอร์ที่เล่นแล้ว');
    });
  });
  document.getElementById('stAddServerSlotBtn').addEventListener('click', function(){ buyServerSlotFlow(); });
  function loadTopupHistory(){
    var root = document.getElementById('stTopupList'), sum = document.getElementById('stTopupSummary'), moreWrap = document.getElementById('stTopupMoreWrap');
    root.innerHTML = '<p class="admin-topup-empty">กำลังโหลด...</p>'; sum.textContent = ''; moreWrap.hidden = true;
    if(!App.session || !App.session.id){ root.innerHTML = '<p class="admin-topup-empty">กรุณาเข้าสู่ระบบ</p>'; return; }
    supa.from('topup_transactions').select('id, requested_amount, received_amount, points, status, created_at')
      .eq('user_id', App.session.id).order('created_at', { ascending:false }).then(function(res){
        if(res.error){ root.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</p>'; return; }
        var rows = res.data || [];
        if(!rows.length){ root.innerHTML = '<p class="admin-topup-empty">ยังไม่เคยเติมแต้ม</p>'; return; }
        var credited = rows.filter(function(r){ return r.status==='credited'; });
        sum.textContent = 'สำเร็จ '+credited.length+' ครั้ง · รวม '+fmtNum(credited.reduce(function(s,r){ return s+(r.points||0); }, 0))+' แต้ม';
        var shown = stHistExpanded.topup ? rows : rows.slice(0, HIST_PAGE);
        root.innerHTML = shown.map(function(r){
          var st = TOPUP_STATUS[r.status] || [r.status || '-', 'neutral'];
          var amount = r.status==='credited' && r.received_amount!=null ? r.received_amount : r.requested_amount;
          return '<div class="settings-row"><div class="settings-row-main">'+
            '<div class="settings-row-title">'+fmtNum(amount||0)+' บาท · +'+fmtNum(r.points||0)+' แต้ม</div>'+
            '<div class="settings-row-meta">'+fmtDateTime(new Date(r.created_at).getTime())+'</div></div>'+
            '<span class="membership-pill '+st[1]+'">'+st[0]+'</span></div>';
        }).join('');
        if(rows.length > HIST_PAGE){
          moreWrap.hidden = false;
          document.getElementById('stTopupMore').textContent = stHistExpanded.topup ? 'ย่อ' : 'ดูทั้งหมด ('+rows.length+')';
        }
      });
  }
  function loadPurchaseHistory(){
    var root = document.getElementById('stPurchaseList'), sum = document.getElementById('stPurchaseSummary'), moreWrap = document.getElementById('stPurchaseMoreWrap');
    root.innerHTML = '<p class="admin-topup-empty">กำลังโหลด...</p>'; sum.textContent = ''; moreWrap.hidden = true;
    supa.from('package_purchases').select('id, plan_name, cycle, points_spent, days_added, expires_after, created_at')
      .eq('user_id', App.session.id).order('created_at', { ascending:false }).then(function(res){
        if(res.error){ root.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</p>'; return; }
        var rows = res.data || [];
        if(!rows.length){ root.innerHTML = '<p class="admin-topup-empty">ยังไม่เคยซื้อแพ็กเกจ</p>'; return; }
        sum.textContent = rows.length+' รายการ · ใช้ไป '+fmtNum(rows.reduce(function(s,r){ return s+(r.points_spent||0); }, 0))+' แต้ม';
        var shown = stHistExpanded.purchase ? rows : rows.slice(0, HIST_PAGE);
        root.innerHTML = shown.map(function(r){
          return '<div class="settings-row"><div class="settings-row-main">'+
            '<div class="settings-row-title">'+r.plan_name+' <span class="membership-pill neutral">'+(r.cycle==='yearly' ? 'รายปี' : 'รายเดือน')+' +'+r.days_added+' วัน</span></div>'+
            '<div class="settings-row-meta">'+fmtDateTime(new Date(r.created_at).getTime())+' · ใช้งานได้ถึง '+fmtDate(new Date(r.expires_after).getTime())+'</div></div>'+
            '<b class="settings-row-amt">-'+fmtNum(r.points_spent)+' แต้ม</b></div>';
        }).join('');
        if(rows.length > HIST_PAGE){
          moreWrap.hidden = false;
          document.getElementById('stPurchaseMore').textContent = stHistExpanded.purchase ? 'ย่อ' : 'ดูทั้งหมด ('+rows.length+')';
        }
      });
  }
  // ประวัติการใช้แต้ม: ทุกครั้งที่แต้มเปลี่ยน (เติม/ซื้อแพ็กเกจ/ที่นั่งปาร์ตี้/ช่องเซิร์ฟเวอร์/ลงประกาศ/แอดมินปรับ) ฐานข้อมูลบันทึกให้เอง
  var POINTS_REASON = {
    topup:'เติมแต้ม (QR PromptPay)', slip_topup:'เติมแต้ม (สลิป)', admin_confirm_topup:'เติมแต้ม (แอดมินยืนยันรับเงิน)',
    admin_grant:'แอดมินเติมแต้มให้', admin_reverse:'แอดมินยกเลิกรายการเติมเงิน', admin_deduct:'แอดมินหักแต้ม',
    plan_purchase:'ซื้อแพ็กเกจ', server_slot:'ซื้อช่องเซิร์ฟเวอร์เพิ่ม', party_slot:'เพิ่มสมาชิกปาร์ตี้',
    announcement:'ลงประกาศรับ M', spend:'ใช้แต้ม', promo_code:'แลกโค้ดโปรโมชัน', other:'ปรับแต้ม'
  };
  function loadPointsHistory(){
    var root = document.getElementById('stPointsList'), sum = document.getElementById('stPointsSummary'), moreWrap = document.getElementById('stPointsMoreWrap');
    root.innerHTML = '<p class="admin-topup-empty">กำลังโหลด...</p>'; sum.textContent = ''; moreWrap.hidden = true;
    if(!App.session || !App.session.id){ root.innerHTML = '<p class="admin-topup-empty">กรุณาเข้าสู่ระบบ</p>'; return; }
    supa.from('points_ledger').select('id, delta, balance_after, reason, detail, created_at')
      .eq('user_id', App.session.id).order('created_at', { ascending:false }).limit(200).then(function(res){
        if(res.error){ root.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</p>'; return; }
        var rows = res.data || [];
        if(!rows.length){ root.innerHTML = '<p class="admin-topup-empty">ยังไม่มีรายการเปลี่ยนแปลงแต้ม (เริ่มบันทึกตั้งแต่เปิดระบบนี้)</p>'; return; }
        sum.textContent = 'รายการล่าสุด '+fmtNum(rows.length)+' รายการ · แต้มคงเหลือหลังรายการล่าสุด '+fmtNum(rows[0].balance_after)+' แต้ม';
        var shown = stHistExpanded.points ? rows : rows.slice(0, HIST_PAGE);
        root.innerHTML = shown.map(function(r){
          var plus = r.delta > 0;
          var amtHtml = r.delta === 0 ? '' : '<b class="settings-row-amt" style="color:var(--'+(plus?'success':'danger')+')">'+(plus?'+':'')+fmtNum(r.delta)+' แต้ม</b>';
          return '<div class="settings-row"><div class="settings-row-main">'+
            '<div class="settings-row-title">'+escapeHtml(r.detail || POINTS_REASON[r.reason] || POINTS_REASON.other)+'</div>'+
            '<div class="settings-row-meta">'+fmtDateTime(new Date(r.created_at).getTime())+' · คงเหลือ '+fmtNum(r.balance_after)+' แต้ม</div></div>'+
            amtHtml+'</div>';
        }).join('');
        if(rows.length > HIST_PAGE){
          moreWrap.hidden = false;
          document.getElementById('stPointsMore').textContent = stHistExpanded.points ? 'ย่อ' : 'ดูทั้งหมด ('+rows.length+')';
        }
      });
  }
  function loadPromoHistory(){
    var root = document.getElementById('stPromoHistList'), sum = document.getElementById('stPromoHistSummary'), moreWrap = document.getElementById('stPromoHistMoreWrap');
    root.innerHTML = '<p class="admin-topup-empty">กำลังโหลด...</p>'; sum.textContent = ''; moreWrap.hidden = true;
    if(!App.session || !App.session.id){ root.innerHTML = '<p class="admin-topup-empty">กรุณาเข้าสู่ระบบ</p>'; return; }
    supa.rpc('list_my_promo_redemptions').then(function(res){
      if(res.error){ root.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</p>'; return; }
      var rows = res.data || [];
      if(!rows.length){ root.innerHTML = '<p class="admin-topup-empty">ยังไม่เคยใช้โค้ดโปรโมชัน</p>'; return; }
      sum.textContent = 'ใช้ไปแล้วทั้งหมด '+fmtNum(rows.length)+' โค้ด';
      var shown = stHistExpanded.promo ? rows : rows.slice(0, HIST_PAGE);
      root.innerHTML = shown.map(function(r){
        var amtHtml = r.reward_type==='plan_days'
          ? '<b class="settings-row-amt" style="color:#f3d48e">4 in 1 +'+fmtNum(r.plan_days)+' วัน</b>'
          : '<b class="settings-row-amt" style="color:var(--success)">+'+fmtNum(r.points)+' แต้ม</b>';
        return '<div class="settings-row"><div class="settings-row-main">'+
          '<div class="settings-row-title">'+escapeHtml(r.code)+'</div>'+
          '<div class="settings-row-meta">'+fmtDateTime(new Date(r.redeemed_at).getTime())+'</div></div>'+
          amtHtml+'</div>';
      }).join('');
      if(rows.length > HIST_PAGE){
        moreWrap.hidden = false;
        document.getElementById('stPromoHistMore').textContent = stHistExpanded.promo ? 'ย่อ' : 'ดูทั้งหมด ('+rows.length+')';
      }
    });
  }
  document.getElementById('stTopupMore').addEventListener('click', function(){ stHistExpanded.topup = !stHistExpanded.topup; loadTopupHistory(); });
  document.getElementById('stPurchaseMore').addEventListener('click', function(){ stHistExpanded.purchase = !stHistExpanded.purchase; loadPurchaseHistory(); });
  document.getElementById('stPointsMore').addEventListener('click', function(){ stHistExpanded.points = !stHistExpanded.points; loadPointsHistory(); });
  document.getElementById('stPromoHistMore').addEventListener('click', function(){ stHistExpanded.promo = !stHistExpanded.promo; loadPromoHistory(); });
  var ST_HIST_TABS = {
    topup:['ประวัติการเติมแต้ม','sthtabTopup','stHistTopup'],
    purchase:['ประวัติการซื้อแพ็กเกจ','sthtabPurchase','stHistPurchase'],
    points:['ประวัติการใช้แต้ม','sthtabPoints','stHistPoints'],
    promo:['ประวัติการใช้โค้ดโปรโมชัน','sthtabPromo','stHistPromo']
  };
  function setStHistTab(tab){
    document.getElementById('stHistoryTitle').textContent = ST_HIST_TABS[tab][0];
    Object.keys(ST_HIST_TABS).forEach(function(k){
      document.getElementById(ST_HIST_TABS[k][1]).className = k===tab ? 'active' : '';
      document.getElementById(ST_HIST_TABS[k][2]).hidden = k!==tab;
    });
  }
  Object.keys(ST_HIST_TABS).forEach(function(k){
    document.getElementById(ST_HIST_TABS[k][1]).addEventListener('click', function(){ setStHistTab(k); });
  });
  var settingsBusy = false;
  // ต้องขึ้นต้นด้วย facebook.com หรือ fb.com เท่านั้น (มี/ไม่มี http(s):// หรือ www./m. นำหน้าก็ได้)
  // ตรวจซ้ำอีกชั้นฝั่ง DB ใน set_my_facebook_url() อยู่แล้ว อันนี้แค่เตือนไวๆ ก่อนส่ง
  var FB_URL_RE = /^(https?:\/\/)?(www\.|m\.)?(facebook\.com|fb\.com)\/.+/i;
  document.getElementById('stSaveProfile').addEventListener('click', function(){
    if(settingsBusy) return;
    var name = document.getElementById('stDisplayName').value.trim();
    var birthField = document.getElementById('stBirthField');
    var birth = birthField.hidden ? '' : document.getElementById('stBirthInput').value;
    var fbUrl = document.getElementById('stFacebookUrl').value.trim();
    if(!name){ toast('กรอกชื่อที่ใช้แสดง'); return; }
    if(/[<>]/.test(name)){ toast('ชื่อที่ใช้แสดงห้ามมีเครื่องหมาย < หรือ >'); return; }
    if(birth){ var bErr = birthDateError(birth); if(bErr){ toast(bErr); return; } }
    if(fbUrl && !FB_URL_RE.test(fbUrl)){ toast('ลิงก์ Facebook ต้องขึ้นต้นด้วย facebook.com หรือ fb.com เท่านั้น'); return; }
    var go = function(){
      settingsBusy = true;
      Promise.all([
        supa.rpc('update_my_profile', { p_display_name: name, p_birth_date: birth || null }),
        supa.rpc('set_my_facebook_url', { p_url: fbUrl || null })
      ]).then(function(results){
        settingsBusy = false;
        var failedRes = results.filter(function(r){ return r.error; })[0];
        if(failedRes){ toast('บันทึกไม่สำเร็จ: '+failedRes.error.message); return; }
        return refreshProfile().then(function(){ renderSettingsPage(); toast('บันทึกข้อมูลแล้ว'); });
      });
    };
    if(birth) showConfirm('ยืนยันวันเกิด '+fmtFullDate(birth+'T00:00:00')+'? บันทึกแล้วแก้ไขไม่ได้อีก', go); else go();
  });
  var promoCodeBusy = false;
  document.getElementById('stPromoCodeBtn').addEventListener('click', function(){
    if(promoCodeBusy) return;
    var input = document.getElementById('stPromoCodeInput');
    var errEl = document.getElementById('stPromoCodeError');
    var code = input.value.trim();
    errEl.textContent = '';
    if(!code){ errEl.textContent = 'กรุณากรอกโค้ด'; return; }
    promoCodeBusy = true;
    supa.rpc('redeem_promo_code', { p_code: code }).then(function(res){
      promoCodeBusy = false;
      if(res.error){ errEl.textContent = res.error.message; return; }
      input.value = '';
      var data = res.data || {};
      refreshProfile().then(function(){
        if(data.reward_type === 'plan_days'){
          toast('ใช้โค้ดสำเร็จ ได้รับแพ็กเกจ 4 in 1 เพิ่ม '+fmtNum(data.plan_days)+' วัน');
        } else {
          toast('ใช้โค้ดสำเร็จ ได้รับ '+fmtNum(data.points)+' แต้ม');
        }
      });
    });
  });
  document.getElementById('stSavePass').addEventListener('click', function(){
    if(settingsBusy) return;
    var oldP = document.getElementById('stPassOld').value, newP = document.getElementById('stPassNew').value, newP2 = document.getElementById('stPassNew2').value;
    if(!oldP || !newP || !newP2){ toast('กรอกรหัสผ่านให้ครบทุกช่อง'); return; }
    if(newP.length < 6){ toast('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร'); return; }
    if(newP !== newP2){ toast('รหัสผ่านใหม่ทั้งสองช่องไม่ตรงกัน'); return; }
    if(newP === oldP){ toast('รหัสผ่านใหม่ต้องต่างจากรหัสเดิม'); return; }
    settingsBusy = true;
    // เช็ครหัสเดิมด้วยการล็อกอินซ้ำก่อน → เปลี่ยนรหัส → เตะเครื่องอื่นออกตามกติกา 1 เครื่อง
    supa.auth.signInWithPassword({ email: App.session.email, password: oldP }).then(function(res){
      if(res.error) throw new Error('รหัสผ่านเดิมไม่ถูกต้อง');
      return supa.auth.updateUser({ password: newP });
    }).then(function(res){
      if(res.error) throw new Error(mapAuthError(res.error.message));
      return supa.auth.signOut({ scope: 'others' });
    }).then(function(){
      settingsBusy = false;
      ['stPassOld','stPassNew','stPassNew2'].forEach(function(id){ document.getElementById(id).value = ''; });
      toast('เปลี่ยนรหัสผ่านแล้ว');
    }).catch(function(err){
      settingsBusy = false;
      toast(err.message || String(err));
    });
  });

  // ---------- บัญชีหมดอายุ = โหมดดูอย่างเดียว + แจ้งเตือนก่อนหมดอายุ 3/2/1 วัน ----------
  // แอดมินไม่ติดกติกา · ยังทำได้: เติมแต้ม ซื้อแพ็กเกจ ตั้งค่า ออกจากระบบ และการเปลี่ยนมุมมอง/ตัวกรองทุกอย่าง
  // การเขียนข้อมูลบอส/ประวัติ/ปาร์ตี้ถูกกันซ้ำที่ฐานข้อมูล (is_active()) ส่วนข้อมูลในเครื่อง (นักลงทุน/ฟาม/คลัง) กันที่นี่
  // วันหมดอายุบัญชีตั้งเป็นปี 2099 = ไม่จำกัด (คอลัมน์ profiles.expires_at ห้ามเป็นค่าว่าง จึงใช้วันไกลๆ แทน)
  function isNoExpiry(ts){ return !ts || new Date(ts).getFullYear() >= 2090; }
  function accountDaysLeft(){
    if(!App.profile || !App.profile.expires_at) return null;
    return Math.ceil((new Date(App.profile.expires_at).getTime() - Date.now())/86400000);
  }
  function isExpiredAccount(){
    if(!App.profile || App.profile.role === 'admin' || !App.profile.expires_at) return false;
    return new Date(App.profile.expires_at).getTime() <= Date.now();
  }
  // สิทธิ์แยกตามแพ็กเกจ (คนละเรื่องกับ isExpiredAccount ด้านบน — นั่นคือ "บัญชีหมดอายุ = อ่าน
  // อย่างเดียวทั้งหมด" ส่วนนี่คือ "บัญชีฟรี (ไม่เคยซื้อแพ็กเกจนี้) = ใช้ได้แต่จำกัดจำนวน/ช่วงเวลา")
  // legacy_unlimited === undefined หมายถึงยังไม่ได้รัน SQL เพิ่มคอลัมน์ — fail open ไม่จำกัดไปก่อน
  function hasBundlePlan(){
    if(!App.profile) return false;
    if(App.profile.role === 'admin' || App.profile.legacy_unlimited === undefined || App.profile.legacy_unlimited) return true;
    return !!(App.profile.plan_bundle_expires_at && new Date(App.profile.plan_bundle_expires_at).getTime() > Date.now());
  }
  function hasTimersPlan(){
    if(!App.profile) return false;
    if(App.profile.role === 'admin' || App.profile.legacy_unlimited === undefined || App.profile.legacy_unlimited) return true;
    return !!(App.profile.plan_timers_expires_at && new Date(App.profile.plan_timers_expires_at).getTime() > Date.now());
  }
  // สมาชิกปาร์ตี้ (ไม่ใช่หัวปาร์ตี้เอง) ที่บัญชีตัวเองไม่มีแพ็กเกจ "จับเวลาบอส" — เพิ่มบอส/กดตายแล้ว/
  // แก้ไข-ลบประวัติไม่ได้ (ดูอย่างเดียว) ต่างจากเดิมที่ยึดสิทธิ์ตามแพ็กเกจของหัวปาร์ตี้ล้วนๆ — หัวปาร์ตี้
  // เองไม่โดนกฎนี้ ยึดแพ็กเกจของตัวเองตามปกติ (ฝั่งเซิร์ฟเวอร์บังคับจริงด้วย ดู add_boss_capped/record_kill/
  // kill_items_write/kills_party_delete — จุดนี้แค่กันไม่ให้กดง่ายๆ ฝั่งหน้าเว็บ)
  function isFreePartyMember(){ return !!App.viewingHostId && !hasTimersPlan(); }
  function hasScopedPlan(feature){
    if(hasBundlePlan()) return true;
    var expiry = App.profile && App.profile.feature_expiries && App.profile.feature_expiries[feature];
    return !!(expiry && new Date(expiry).getTime()>Date.now());
  }
  function hasFarmPlan(){ return hasScopedPlan('farm'); }
  function hasTradePlan(){ return hasScopedPlan('accountItems'); }
  // สิ่งที่ยังกดได้ตอนหมดอายุ (นอกจากนี้ = ทำรายการ → กัน)
  var RO_ALLOW = [
    '#expiryOverlay', '#expiryBanner', '#serverPickOverlay', '#topupOverlay', '#confirmOverlay', '#farmOcHintOverlay', '#farmRateRequiredOverlay', '#mrRateRequiredOverlay', '#forgotPasswordOverlay', '#recoveryPasswordOverlay',
    '.rail', '.util-bar', '#view-pricing', '#view-settings', '#view-admin',
    // ประวัติการล่า: เปลี่ยนแท็บ/ตัวกรอง/ปิดได้ แต่ลบ/หาร/ขาย/เก็บไว้ไม่ได้
    '.slideover-head', '[data-htab]', '.h-filter', '[data-close-history]', '[data-loot-filter]', '[data-boss-killer]',
    // บัญชีนักลงทุน: กราฟ/ตัวกรอง/ค้นหา/กางการ์ดประวัติ (ไม่รวมฟอร์มรับ-ขาย, ลงประกาศ, แก้/ลบรายการ)
    '#mrChartCategoryToggle', '#mrChartServerSelect', '#mrChartTimeframeSelect', '#mrSeriesDropdownBtn', '#mrSeriesDropdown', '#mrSeriesChips', '#mrChartLegend',
    '#historyCategoryToggle', '#historyServerFilter', '#mrHistorySearch', '#mrHistoryRange', '#mrItSoldToggle', '.mr-ic-head', '.mr-ic-day-head', '.mr-rate-hover', '.mr-edited-hover',
    '#tickerServerChips', '#rateChips',
    // รูปไอเทม: กดไอคอนดูรูปในประวัติ/คลังได้ (แนบ/เปลี่ยน/เอารูปออกในฟอร์ม = ทำรายการ → กัน)
    '.item-img-ico', '#itemImageLightbox',
    // ยอดนักฟาม: เปลี่ยนเซิร์ฟเวอร์/หน่วย/ช่วงเวลา/กราฟ/หน้าประวัติ (ไม่รวมฟอร์มบันทึก, ต้นทุน, เรท, แก้/ลบ)
    '#farmServerSelect', '#farmUnitToggle', '#farmTimeframeSelect', '#farmSeriesDropdownBtn', '#farmSeriesDropdown', '#farmSeriesChips', '#farmChartLegend',
    '#farmHistoryRange', '#farmHistoryPagination', '.farm-cost-hover', '.farm-profit-hover', '.farm-income-hover',
    // จับเวลาบอส: เปิดปาร์ตี้ดู/เปิดประวัติ/พิมพ์ค้นหาได้ (เลือกผลค้นหา = เพิ่มบอส → กัน)
    '#partyPanelToggle', '[data-open-history]', '#searchInput', '#bossSoundControl',
    // คลังไอเทม: ดูตามระดับ/เปลี่ยนเซิร์ฟเวอร์
    '[data-view-tier]', '#itemsServerSelect'
  ].join(',');
  function roAllowed(target){
    if(!target || !target.closest) return true;
    if(document.getElementById('appScreen').hidden) return true;
    return !!target.closest(RO_ALLOW);
  }
  var roNoticeAt = 0;
  function roNotice(){
    var now = Date.now();
    if(now - roNoticeAt < 2500) return;
    roNoticeAt = now;
    toast('บัญชีหมดอายุแล้ว ดูข้อมูลได้อย่างเดียว — สมัครแพ็กเกจเพื่อใช้งานต่อ');
  }
  function roBlock(e){
    if(!isExpiredAccount() || roAllowed(e.target)) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    roNotice();
  }
  // ดักตั้งแต่ชั้น document (capture) ก่อนถึง handler ของแต่ละปุ่ม: คลิก/ลาก/เปลี่ยนค่า/พิมพ์
  ['click','dragstart','drop','change','input','submit'].forEach(function(ev){ document.addEventListener(ev, roBlock, true); });
  document.addEventListener('mousedown', function(e){ // กันเปิด dropdown ของ select ที่ใช้ไม่ได้
    if(isExpiredAccount() && e.target && e.target.tagName === 'SELECT' && !roAllowed(e.target)){ e.preventDefault(); roNotice(); }
  }, true);
  document.addEventListener('focus', function(e){ // ช่องกรอกที่ใช้ไม่ได้: โฟกัสไม่ได้ พิมพ์ไม่ได้ (capture ดักก่อน handler ของช่องนั้นเอง)
    var t = e.target;
    if(!isExpiredAccount() || !t || !/^(INPUT|SELECT|TEXTAREA)$/.test(t.tagName) || roAllowed(t)) return;
    e.stopImmediatePropagation();
    setTimeout(function(){ t.blur(); }, 0); // blur ทันทีในจังหวะ focus ไม่มีผล ต้องรอให้ focus จบก่อน
    roNotice();
  }, true);
  document.addEventListener('keydown', function(e){
    if(isExpiredAccount() && e.target && /^(INPUT|SELECT|TEXTAREA)$/.test(e.target.tagName) && !roAllowed(e.target) && e.key !== 'Tab' && e.key !== 'Escape'){ e.preventDefault(); e.stopImmediatePropagation(); }
  }, true);

  // ---------- โหมดผู้เยี่ยมชม (ยังไม่ล็อกอิน): ดูได้เฉพาะที่ระบุไว้ ที่เหลือกดแล้วเด้ง popup login ทันที ----------
  // GUEST_ALLOW = ตัวฟอร์มล็อกอิน/สมัคร · GUEST_VIEW_ALLOW = ที่ผู้เยี่ยมชมกดดูได้: เมนูซ้ายทุกหน้า (ยกเว้นตั้งค่า),
  // สลับรายเดือน/รายปี + ดูรายละเอียดแพ็กในหน้าเติมแพ็กเกจ, ช่องค้นหาบอส · ปุ่มซื้อแพ็กเกจ/บันทึก/เพิ่มบอส/ตัวกรอง ยังเด้งล็อกอิน
  // (เพิ่มรายการที่ให้ผู้เยี่ยมชมกดได้ ต้องเพิ่มที่นี่เท่านั้น — ค่าเริ่มต้นคือกันทั้งหมด)
  var GUEST_ALLOW = '#authModal, #forgotPasswordOverlay, #recoveryPasswordOverlay, #guestLoginBtn, #guestRegisterBtn';
  var GUEST_VIEW_ALLOW = '.rail-btn:not([data-page="settings"]), #pricingCycleToggle, .pricing-details-toggle, #searchInput, .rail-logo-fb';
  function guestBlock(e){
    if(!App.isGuest || e.target.closest(GUEST_ALLOW) || e.target.closest(GUEST_VIEW_ALLOW)) return;
    // ผู้เยี่ยมชมกดซื้อแพ็กเกจ (ถูกพาไปล็อกอิน) — นับเป็นขั้น "กดซื้อ" ในเส้นทางการซื้อด้วย
    var guestCta = e.type === 'click' && e.target.closest('.pricing-cta[data-plan-key]');
    if(guestCta) Track.push('buy_click_guest', 'pricing', parseInt(guestCta.dataset.price,10)||0, guestCta.dataset.planKey+':'+guestCta.dataset.cycle);
    e.preventDefault();
    e.stopImmediatePropagation();
    openAuthModal(false);
  }
  ['click','dragstart','drop','change','input','submit'].forEach(function(ev){ document.addEventListener(ev, guestBlock, true); });
  document.addEventListener('mousedown', function(e){
    if(App.isGuest && e.target && e.target.tagName === 'SELECT' && !e.target.closest(GUEST_ALLOW)){ e.preventDefault(); openAuthModal(false); }
  }, true);
  document.addEventListener('focus', function(e){
    var t = e.target;
    if(!App.isGuest || !t || !/^(INPUT|SELECT|TEXTAREA)$/.test(t.tagName) || t.closest(GUEST_ALLOW) || t.closest(GUEST_VIEW_ALLOW)) return;
    e.stopImmediatePropagation();
    setTimeout(function(){ t.blur(); }, 0);
    openAuthModal(false);
  }, true);
  document.getElementById('guestLoginBtn').addEventListener('click', function(){ openAuthModal(false); });
  document.getElementById('guestRegisterBtn').addEventListener('click', function(){ openAuthModal(true); });

  function renderExpiryState(){
    var banner = document.getElementById('expiryBanner');
    var expired = isExpiredAccount();
    document.body.classList.toggle('ro-mode', expired);
    var days = accountDaysLeft();
    var bannerBtn = banner.querySelector('[data-go-pricing]');
    if(!App.profile || App.profile.role === 'admin'){ banner.hidden = true; return; }
    if(days !== null){
      var expText = fmtDate(new Date(App.profile.expires_at).getTime());
      if(expired){
        banner.hidden = false; banner.className = 'expiry-banner expired'; bannerBtn.textContent = 'สมัครแพ็กเกจ';
        document.getElementById('expiryBannerText').textContent = 'บัญชีหมดอายุเมื่อ '+expText+' — ตอนนี้ดูข้อมูลได้อย่างเดียว ทำรายการไม่ได้ สมัครแพ็กเกจเพื่อกลับมาใช้งานได้เต็มรูปแบบ';
        return;
      }
      if(days <= 3){
        banner.hidden = false; banner.className = 'expiry-banner soon'; bannerBtn.textContent = 'สมัครแพ็กเกจ';
        document.getElementById('expiryBannerText').textContent = 'เหลืออีก '+days+' วัน บัญชีจะหมดอายุ ('+expText+') — ต่ออายุตอนนี้ วันที่เหลือจะถูกนับต่อ ไม่เสียเปล่า';
        return;
      }
    }
    // วันหมดอายุรวมของบัญชียังไม่ใกล้ (บัญชีใหม่ = 2099) → เช็คแพ็กเกจที่ซื้อไว้แทน
    var soon = packageExpiringSoon();
    if(soon.length){
      banner.hidden = false; banner.className = 'expiry-banner soon'; bannerBtn.textContent = 'ต่ออายุแพ็กเกจ';
      document.getElementById('expiryBannerText').textContent = 'แพ็กเกจใกล้หมดอายุ: '+soon.map(function(s){ return s.name+' เหลืออีก '+s.days+' วัน'; }).join(' · ')+' — ต่ออายุตอนนี้ วันที่เหลือจะถูกนับต่อ ไม่เสียเปล่า';
    } else banner.hidden = true;
  }

  // ---------- เตือนแพ็กเกจที่ซื้อไว้ ----------
  // แยกจากวันหมดอายุรวมของบัญชีด้านบน (บัญชีใหม่ตั้งเป็น 2099 จึงไม่เคยเข้าเงื่อนไขนั้น)
  //   ใกล้หมด = แพ็กที่เหลือไม่เกิน 3 วัน · ใช้รายการชุดเดียวกับหน้าตั้งค่า (แพ็กเล็กที่แพ็กใหญ่ครอบยาวกว่าไม่นับ)
  //   หมดแล้ว = แพ็กที่หมดภายใน 30 วันที่ผ่านมาและยังไม่ได้ต่อ · แจ้งครั้งเดียวต่อการหมดอายุแต่ละครั้ง (จำในเครื่อง)
  // บัญชีรุ่นเดิม (legacy_unlimited) และแอดมินได้สิทธิ์ไม่จำกัดอยู่แล้ว จึงไม่เตือน
  var PKG_WARN_DAYS = 3, PKG_EXPIRED_WINDOW = 30*86400000;
  function packageReminderApplies(){
    return !!App.profile && !App.isGuest && App.profile.role !== 'admin' && !App.profile.legacy_unlimited;
  }
  function packageExpiringSoon(){
    if(!packageReminderApplies()) return [];
    var now = Date.now();
    return settingsPackageRows(App.profile, now).filter(function(r){ return r.expiry > now; }).map(function(r){
      return { name:r.name, expiry:r.expiry, days:Math.ceil((r.expiry-now)/86400000) };
    }).filter(function(r){ return r.days <= PKG_WARN_DAYS; });
  }
  function packageJustExpired(){
    if(!packageReminderApplies()) return [];
    var now = Date.now(), p = App.profile, sc = p.feature_expiries || {};
    var ts = function(v){ return new Date(v||0).getTime() || 0; };
    var b = ts(p.plan_bundle_expires_at), t = ts(p.plan_timers_expires_at), f = ts(sc.farm), a = ts(sc.accountItems);
    var recent = function(x){ return x > 0 && x <= now && now-x <= PKG_EXPIRED_WINDOW; };
    var out = [];
    if(recent(b) && recent(t) && b === t) out.push({ key:'all', name:'4 in 1 — ครบทั้ง 4 ระบบ', expiry:b });
    else {
      if(recent(b)) out.push({ key:'bundle', name:'3 in 1', expiry:b });
      if(recent(t)) out.push({ key:'timers', name:'จับเวลาบอส', expiry:t });
    }
    // ยอดฟาม / 2 in 1 ที่ยังถูก 3 in 1 ครอบอยู่ = ยังใช้ได้ ไม่ต้องแจ้ง
    if(recent(f) && b <= now) out.push({ key:'farm', name:'1 in 1 — ยอดนักฟาม', expiry:f });
    if(recent(a) && b <= now) out.push({ key:'accountItems', name:'2 in 1 — บัญชีนักลงทุน + คลังไอเทม', expiry:a });
    return out;
  }
  function checkPackageReminder(){
    if(!packageReminderApplies()) return;
    // ป๊อปอัปเตือนบัญชีหมดอายุแสดงอยู่ → รอรอบถัดไป (ยังไม่จดว่าแจ้งแล้ว)
    if(!document.getElementById('expiryOverlay').hidden) return;
    var now = Date.now();
    var soon = packageExpiringSoon();
    var seen = store(App.keys.pkgExpiredSeen, []);
    if(!Array.isArray(seen)) seen = [];
    var gone = packageJustExpired().filter(function(g){ return seen.indexOf(g.key+':'+g.expiry) === -1; });
    var soonStamp = soon.length ? todayKey(now)+':'+soon.map(function(s){ return s.name+'='+s.days; }).join('|') : '';
    var showSoon = soon.length > 0 && store(App.keys.pkgWarn, '') !== soonStamp;
    if(!showSoon && !gone.length) return;
    var parts = [];
    if(gone.length){
      parts.push(gone.map(function(g){ return g.name+' หมดอายุเมื่อ '+fmtDate(g.expiry); }).join('\n')+
        '\nตอนนี้ใช้สิทธิ์แบบฟรี ข้อมูลเดิมของคุณไม่ถูกลบ ต่ออายุเมื่อไหร่ก็กลับมาใช้ได้เต็มที่');
    }
    if(showSoon){
      parts.push(soon.map(function(s){ return s.name+' — เหลืออีก '+s.days+' วัน (หมด '+fmtDate(s.expiry)+')'; }).join('\n')+
        '\nต่ออายุตอนนี้ วันที่เหลือจะถูกนับต่อ ไม่เสียเปล่า ถ้าปล่อยให้หมดจะกลับไปใช้สิทธิ์แบบฟรี');
    }
    showExpiryPopup(gone.length && showSoon ? 'แจ้งเตือนแพ็กเกจ' : gone.length ? 'แพ็กเกจหมดอายุแล้ว' : 'แพ็กเกจใกล้หมดอายุ', parts.join('\n\n'));
    if(showSoon) persist(App.keys.pkgWarn, soonStamp);
    if(gone.length) persist(App.keys.pkgExpiredSeen, seen.concat(gone.map(function(g){ return g.key+':'+g.expiry; })).slice(-20));
  }
  function showExpiryPopup(title, msg){
    document.getElementById('expiryTitle').textContent = title;
    document.getElementById('expiryMsg').textContent = msg;
    document.getElementById('expiryOverlay').hidden = false;
  }
  var expiryPopupShownForSession = false;
  // หมดอายุ: popup ทุกครั้งที่เข้าแอป · ใกล้หมด 3/2/1 วัน: popup วันละครั้งต่อบัญชี (จำในเครื่อง)
  function checkExpiryReminder(){
    if(!App.profile || App.profile.role === 'admin') return;
    var days = accountDaysLeft();
    if(days === null) return;
    var expText = fmtDate(new Date(App.profile.expires_at).getTime());
    if(isExpiredAccount()){
      if(expiryPopupShownForSession) return;
      expiryPopupShownForSession = true;
      showExpiryPopup('บัญชีหมดอายุแล้ว', 'บัญชีของคุณหมดอายุเมื่อ '+expText+' ตอนนี้เข้าดูข้อมูลเดิมได้อย่างเดียว ทำรายการใด ๆ ไม่ได้ สมัครแพ็กเกจเพื่อกลับมาใช้งานได้เต็มรูปแบบ');
      return;
    }
    if(days > 3) return;
    var stamp = todayKey(Date.now())+':'+days;
    if(store(App.keys.expiryWarn, '') === stamp) return;
    persist(App.keys.expiryWarn, stamp);
    showExpiryPopup('บัญชีใกล้หมดอายุ', 'เหลืออีก '+days+' วัน บัญชีจะหมดอายุ ('+expText+') ต่ออายุตอนนี้ วันที่เหลือจะถูกนับต่อ ไม่เสียเปล่า ถ้าปล่อยให้หมดอายุจะเข้าดูข้อมูลได้อย่างเดียว');
  }
  document.addEventListener('click', function(e){
    if(e.target.closest('[data-go-pricing]')){ document.getElementById('expiryOverlay').hidden = true; switchPage('pricing'); return; }
    if(e.target.closest('[data-expiry-close]')) document.getElementById('expiryOverlay').hidden = true;
  });
  // เปิดแอปค้างไว้ข้ามวัน: เช็คทุกนาที แถบ/โหมดดูอย่างเดียวจะอัปเดตเอง
  setInterval(function(){ if(App.session && App.profile){ renderExpiryState(); checkExpiryReminder(); checkPackageReminder(); } }, 60000);

  // ---------- อัปเดตแต้ม/แพ็กเกจเบื้องหลัง ----------
  // เดิมโปรไฟล์โหลดใหม่แค่ตอนล็อกอิน/หลังทำรายการเอง — แอดมินยืนยันรายการเติมเงินที่ค้างตรวจ, เติม/หักแต้ม,
  // ยกเลิกรายการ หน้าจอของผู้ใช้คนนั้นไม่รู้จนกว่าจะรีโหลด (เห็นแต้มเก่า กดซื้อแล้วขึ้นแต้มไม่พอ ฯลฯ)
  // ตอนนี้เช็คใหม่ทุก 60 วิ ระหว่างเปิดแท็บดูอยู่ + ทันทีที่กลับมาที่แท็บ (เว้นอย่างน้อย 15 วิ ยกเว้นสั่ง force)
  // สร้างโปรไฟล์ใหม่ให้ครบรวมสิทธิ์แพ็กย่อย (1 in 1 / 2 in 1) ก่อน แล้วค่อยสลับเข้า App.profile ทีเดียว —
  // ไม่ใช้ refreshProfile() ตรงนี้ เพราะตัวนั้นล้าง feature_expiries ก่อนโหลดเสร็จ ช่วงสั้นๆ นั้นคนที่มีแพ็กย่อย
  // จะถูกมองเป็นบัญชีฟรี ถ้ากดบันทึกพอดีจะโดนลิมิตผิดๆ (ของเดิมเกิดแค่ตอนทำรายการเอง ตัวนี้วิ่งทุกนาทีจึงต้องกัน)
  var profileSyncBusy = false, profileSyncAt = 0;
  function profileSyncKey(p){
    return p ? JSON.stringify([p.points, p.role, p.expires_at, p.legacy_unlimited, p.plan_bundle_expires_at,
                               p.plan_timers_expires_at, p.feature_expiries, p.server_quota, p.servers]) : '';
  }
  function profilePlanKey(p){
    return p ? JSON.stringify([p.role, p.expires_at, p.legacy_unlimited, p.plan_bundle_expires_at, p.plan_timers_expires_at, p.feature_expiries]) : '';
  }
  function syncProfileQuietly(force){
    if(!App.session || !App.session.id || App.isGuest || !App.profile) return Promise.resolve(false);
    if(profileSyncBusy || (!force && Date.now() - profileSyncAt < 15000)) return Promise.resolve(false);
    profileSyncBusy = true;
    profileSyncAt = Date.now();
    var uid = App.session.id;
    // withSkewRetry: นาฬิกาเครื่องผู้ใช้เร็วกว่าเซิร์ฟเวอร์ → token "issued at future" ได้ 401 ชั่วคราว ให้ลองซ้ำเหมือน refreshProfile
    return withSkewRetry(function(){ return supa.rpc('my_profile'); }).then(function(res){
      if(res.error || !res.data) return null;
      var data = res.data;
      data.feature_expiries = {};
      return supa.from('package_feature_entitlements').select('feature,expires_at').eq('user_id', uid).then(function(ent){
        if(ent.error) return null; // สิทธิ์แพ็กย่อยโหลดไม่ได้ = ไม่สลับ (ข้อมูลไม่ครบห้ามใช้) รอบหน้าลองใหม่
        (ent.data || []).forEach(function(e){
          if(e.feature==='farm' || e.feature==='accountItems') data.feature_expiries[e.feature] = e.expires_at;
        });
        return data;
      });
    }).then(function(data){
      profileSyncBusy = false;
      if(!data || !App.session || App.session.id !== uid || !App.profile) return false;
      if(profileSyncKey(data) === profileSyncKey(App.profile)) return false;
      var planChanged = profilePlanKey(data) !== profilePlanKey(App.profile);
      App.profile = data;
      document.getElementById('railAdminBtn').hidden = data.role !== 'admin';
      renderUser();
      renderExpiryState();
      renderFreeQuotaNotes();
      if(!document.getElementById('view-pricing').hidden) renderPricingPage();
      if(!document.getElementById('view-settings').hidden) renderSettingsPackages();
      if(planChanged){
        // สิทธิ์แพ็กเปลี่ยน (ซื้อ/หมดอายุ/แอดมินแจกวัน) → วาดส่วนที่ล็อกตามแพ็กของหน้าที่เปิดอยู่ใหม่
        if(!document.getElementById('view-home').hidden) renderMerchantHistory();
        if(!document.getElementById('view-farm').hidden) renderFarmHistory();
        if(!document.getElementById('view-items').hidden) renderItemsPage();
        if(!document.getElementById('view-timers').hidden) renderRoster();
      }
      return true;
    }, function(err){
      profileSyncBusy = false;
      console.warn('profile sync', err);
      return false;
    });
  }
  setInterval(function(){ if(!document.hidden) syncProfileQuietly(); }, 60000);
  document.addEventListener('visibilitychange', function(){ if(!document.hidden) syncProfileQuietly(); });

  // ---------- เติมแต้ม: QR PromptPay ผ่าน TMWEASY Edge Function ----------
  var topupAmount = 500;
  var TOPUP_MIN_AMOUNT = 20;
  var topupQrPollTimer = null;
  var topupQrClockTimer = null;
  var topupQrTransactionId = null;
  var topupQrExpiresAt = 0;
  document.getElementById('topupCustomAmount').min = String(TOPUP_MIN_AMOUNT);
  function stopTopupQrWatch(){
    clearInterval(topupQrPollTimer); clearInterval(topupQrClockTimer);
    topupQrPollTimer = null; topupQrClockTimer = null;
  }
  function setTopupPaymentStatus(kind, text){
    var el = document.getElementById('topupPaymentStatus');
    el.className = 'topup-payment-status '+kind;
    el.textContent = text;
  }
  function resetTopupQrPanel(){
    stopTopupQrWatch();
    topupQrTransactionId = null; topupQrExpiresAt = 0;
    document.getElementById('topupQrPanel').hidden = true;
    document.getElementById('topupQrImage').removeAttribute('src');
    document.getElementById('topupQrExpiry').textContent = '--:--';
    setTopupPaymentStatus('pending','กำลังรอการชำระเงิน...');
  }
  function topupQrSource(value){
    var qr = String(value||'').trim();
    if(!qr) return '';
    if(/^data:image\//i.test(qr) || /^(https?:|blob:)/i.test(qr)) return qr;
    return 'data:image/png;base64,'+qr.replace(/^base64,/i,'').replace(/\s+/g,'');
  }
  function topupPayload(data){
    var outer = data && typeof data==='object' ? data : {};
    return outer.data && typeof outer.data==='object' ? Object.assign({},outer,outer.data) : outer;
  }
  function readTopupCreateResult(data){
    var payload = topupPayload(data), tx = payload.transaction && typeof payload.transaction==='object' ? payload.transaction : {};
    var qrData = payload.qr && typeof payload.qr==='object' ? payload.qr : {};
    var timeout = Number(payload.time_out!=null ? payload.time_out : tx.time_out);
    var expiryRaw = payload.expires_at || payload.qr_expires_at || tx.expires_at || tx.qr_expires_at;
    var expiry = new Date(expiryRaw||0).getTime() || 0;
    if(!expiry && isFinite(timeout) && timeout>0) expiry = Date.now()+timeout*1000;
    var amount = payload.amount_baht!=null ? payload.amount_baht : payload.amount!=null ? payload.amount : tx.amount_baht!=null ? tx.amount_baht : null;
    if(amount==null && payload.amount_check!=null) amount=Number(payload.amount_check)/100;
    return {
      id:payload.transaction_id || payload.transactionId || payload.topup_transaction_id || tx.id || payload.id || payload.id_pay || '',
      qr:payload.qr_image_base64 || payload.qr_base64_image || payload.qr_code_base64 || payload.qr_image || payload.qr_url || payload.qrCode || qrData.image_base64 || qrData.url || tx.qr_image_base64 || tx.qr_code || '',
      amount:Number(amount==null ? topupAmount : amount),
      points:Number(payload.points_added!=null ? payload.points_added : payload.points!=null ? payload.points : tx.points_added!=null ? tx.points_added : topupAmount),
      expiresAt:expiry
    };
  }
  function updateTopupQrClock(){
    if(!topupQrExpiresAt) return;
    var remaining = Math.max(0,topupQrExpiresAt-Date.now());
    var totalSeconds = Math.ceil(remaining/1000);
    document.getElementById('topupQrExpiry').textContent = pad2(Math.floor(totalSeconds/60))+':'+pad2(totalSeconds%60);
    if(remaining<=0){
      stopTopupQrWatch();
      setTopupPaymentStatus('expired','QR หมดอายุ กรุณาสร้างใหม่');
      var button=document.getElementById('topupCreateQrBtn'); button.disabled=false; button.textContent='สร้าง QR ใหม่';
    }
  }
  function handleTopupTransaction(row){
    if(!row) return;
    if(!topupQrExpiresAt){
      var rowExpiry=new Date(row.expires_at||row.qr_expires_at||0).getTime()||0;
      if(rowExpiry){ topupQrExpiresAt=rowExpiry; updateTopupQrClock(); }
    }
    var status=String(row.status||'pending').toLowerCase();
    if(status==='credited'){
      stopTopupQrWatch();
      setTopupPaymentStatus('credited','เติมแต้มสำเร็จ');
      document.getElementById('topupCreateQrBtn').disabled=true;
      refreshProfile().then(function(){ renderUser(); loadTopupHistory(); });
    } else if(status==='failed'){
      stopTopupQrWatch();
      setTopupPaymentStatus('failed','เติมแต้มไม่สำเร็จ กรุณาลองใหม่หรือติดต่อ Admin');
      var failedButton=document.getElementById('topupCreateQrBtn'); failedButton.disabled=false; failedButton.textContent='สร้าง QR ใหม่';
    } else if(status==='manual_review'){
      setTopupPaymentStatus('review','รายการกำลังรอตรวจสอบโดย Admin');
    } else if(status==='expired'){
      stopTopupQrWatch();
      setTopupPaymentStatus('expired','QR หมดอายุ กรุณาสร้างใหม่');
      var expiredButton=document.getElementById('topupCreateQrBtn'); expiredButton.disabled=false; expiredButton.textContent='สร้าง QR ใหม่';
    } else {
      setTopupPaymentStatus('pending','กำลังรอการชำระเงิน...');
    }
  }
  function pollTopupTransaction(){
    if(!topupQrTransactionId || !App.session){ stopTopupQrWatch(); return; }
    supa.from('topup_transactions').select('*').eq('id',topupQrTransactionId).eq('user_id',App.session.id).maybeSingle().then(function(res){
      if(res.error){ console.warn('poll topup_transactions',res.error); return; }
      handleTopupTransaction(res.data);
    });
  }
  function startTopupQrWatch(){
    stopTopupQrWatch();
    updateTopupQrClock(); pollTopupTransaction();
    topupQrClockTimer=setInterval(updateTopupQrClock,1000);
    topupQrPollTimer=setInterval(pollTopupTransaction,3000);
  }
  function updateTopupPreview(){
    var input = document.getElementById('topupCustomAmount');
    var error = document.getElementById('topupAmountError');
    var valid = Number.isSafeInteger(topupAmount) && topupAmount>=TOPUP_MIN_AMOUNT;
    var hasInput = input.value!=='' || input.validity.badInput;
    var message = hasInput && !valid ? 'กรุณาระบุจำนวนเต็มตั้งแต่ '+TOPUP_MIN_AMOUNT+' บาทขึ้นไป' : '';
    error.textContent = message;
    error.hidden = !message;
    input.setAttribute('aria-invalid',message ? 'true' : 'false');
    document.getElementById('topupCreateQrBtn').disabled = !valid;
    document.getElementById('topupBahtPreview').textContent = fmtNum(topupAmount);
    document.getElementById('topupPointsPreview').textContent = fmtNum(topupAmount);
  }
  function openTopup(){
    resetTopupQrPanel();
    topupAmount = 500;
    document.getElementById('topupCustomAmount').value = '';
    document.getElementById('topupSlipInput').value = '';
    document.querySelectorAll('.topup-preset-btn').forEach(function(b){ b.classList.toggle('active', parseInt(b.dataset.amount,10)===topupAmount); });
    document.querySelectorAll('.topup-method-btn').forEach(function(b, i){ b.classList.toggle('active', i===0); });
    updateTopupPreview();
    var createButton=document.getElementById('topupCreateQrBtn'); createButton.textContent='สร้าง QR PromptPay';
    document.getElementById('topupOverlay').hidden = false;
  }
  function closeTopup(){ document.getElementById('topupOverlay').hidden = true; }
  document.getElementById('pointsTopupBtn').addEventListener('click', openTopup);
  document.getElementById('topupCancelBtn').addEventListener('click', closeTopup);
  document.querySelector('#topupOverlay .confirm-backdrop').addEventListener('click', closeTopup);

  document.getElementById('topupPresets').addEventListener('click', function(e){
    var btn = e.target.closest('[data-amount]');
    if(!btn) return;
    topupAmount = parseInt(btn.dataset.amount, 10);
    document.getElementById('topupCustomAmount').value = '';
    document.querySelectorAll('.topup-preset-btn').forEach(function(b){ b.classList.toggle('active', b===btn); });
    updateTopupPreview();
  });
  document.getElementById('topupCustomAmount').addEventListener('input', function(){
    var raw = this.value;
    var n = /^\d+$/.test(raw) ? Number(raw) : NaN;
    document.querySelectorAll('.topup-preset-btn').forEach(function(b){ b.classList.remove('active'); });
    topupAmount = Number.isSafeInteger(n) && n>0 ? n : 0;
    updateTopupPreview();
  });
  document.getElementById('topupMethods').addEventListener('click', function(e){
    var btn = e.target.closest('[data-method]');
    if(!btn) return;
    document.querySelectorAll('.topup-method-btn').forEach(function(b){ b.classList.toggle('active', b===btn); });
  });
  document.getElementById('topupCreateQrBtn').addEventListener('click', function(){
    var button=this;
    if(topupBusy || button.disabled) return;
    if(!App.session){ toast('กรุณาเข้าสู่ระบบก่อนเติมแต้ม'); return; }
    if(!Number.isSafeInteger(topupAmount) || topupAmount<TOPUP_MIN_AMOUNT){ updateTopupPreview(); return; }
    topupBusy=true; resetTopupQrPanel();
    button.disabled=true; button.textContent='กำลังสร้าง QR...';
    // สร้าง QR ได้ไม่เกิน 5 ครั้งต่อชั่วโมง (ฐานข้อมูลบังคับจริง) — เช็กก่อนตรงนี้เพื่อขึ้นข้อความให้เข้าใจ
    // ถ้าเช็กไม่ได้ (เช่นฟังก์ชันยังไม่ถูกสร้าง) ปล่อยผ่านไปให้ฐานข้อมูลตัดสินเอง
    supa.rpc('topup_attempts_left').then(function(lim){
      if(!lim.error && typeof lim.data==='number' && lim.data<=0){ var limitErr = new Error('TOPUP_LIMIT'); limitErr.limit = true; throw limitErr; }
      return supa.functions.invoke('tmweasy-create-pay',{body:{amount:topupAmount,amount_baht:topupAmount}});
    }).then(function(res){
      if(res.error) throw res.error;
      if(res.data && (res.data.status===0 || res.data.success===false)) throw new Error(res.data.msg||res.data.message||'สร้างรายการชำระเงินไม่สำเร็จ');
      var result=readTopupCreateResult(res.data), src=topupQrSource(result.qr);
      if(!result.id) throw new Error((res.data&&res.data.msg)||'Edge Function ไม่ได้ส่ง transaction_id กลับมา');
      if(!src) throw new Error((res.data&&res.data.msg)||'Edge Function ไม่ได้ส่งรูป QR กลับมา');
      topupQrTransactionId=result.id; topupQrExpiresAt=result.expiresAt;
      document.getElementById('topupQrImage').src=src;
      document.getElementById('topupQrAmount').textContent=fmtNum(result.amount);
      document.getElementById('topupQrPoints').textContent=fmtNum(result.points);
      document.getElementById('topupQrPanel').hidden=false;
      setTopupPaymentStatus('pending','กำลังรอการชำระเงิน...');
      button.textContent='กำลังรอชำระเงิน';
      startTopupQrWatch();
    }).catch(function(err){
      button.disabled=false; button.textContent='สร้าง QR PromptPay';
      if(err && err.limit){ showConfirm('<b>คุณทำรายการมากเกินไป</b><br>ติดต่อแอดมินเพื่อทำรายการ', function(){}); return; }
      toast('สร้าง QR ไม่สำเร็จ: '+(err.message||err));
      console.error('tmweasy-create-pay',err);
    }).finally(function(){ topupBusy=false; });
  });
  var topupBusy = false;
  document.getElementById('topupSubmitBtn').addEventListener('click', function(){
    if(topupBusy) return;
    if(!(topupAmount>0)){ toast('กรุณาระบุจำนวนเงิน'); return; }
    var file = document.getElementById('topupSlipInput').files[0];
    if(!file){ toast('กรุณาแนบรูปสลิปโอนเงิน'); return; }
    topupBusy = true;
    var path = App.session.id + '/' + Date.now() + '-' + file.name;
    supa.storage.from('topup-slips').upload(path, file).then(function(uploadRes){
      if(uploadRes.error) throw uploadRes.error;
      return supa.from('topup_requests').insert({
        user_id: App.session.id,
        amount_baht: topupAmount,
        points_added: topupAmount,
        slip_image_url: path
      });
    }).then(function(res){
      topupBusy = false;
      if(res && res.error){ toast('ส่งคำขอไม่สำเร็จ: '+res.error.message); return; }
      closeTopup();
      toast('ส่งคำขอเติมเงินแล้ว รอแอดมินตรวจสอบ');
    }).catch(function(err){
      topupBusy = false;
      toast('ส่งคำขอไม่สำเร็จ: '+(err.message||err));
    });
  });

  // ---------- แอดมิน: โค้ดอยู่ที่ assets/admin-panel.js (โหลดเฉพาะตอนแอดมินเปิดหน้าแอดมินครั้งแรก) ----------
  // ผู้ใช้ทั่วไปไม่ต้องโหลดโค้ดส่วนนี้ · ของที่หน้าแอดมินใช้จาก app.js ส่งไปทาง ctx
  // แก้ admin-panel.js แล้วเปลี่ยนเลข v ใน import ข้างล่าง + เลข v ของ app.js ใน index.html
  var adminPanel = null, adminPanelLoading = null;
  function openAdminPage(){
    if(adminPanel){ adminPanel.openAdminPage(); return; }
    if(!adminPanelLoading){
      adminPanelLoading = import('./admin-panel.js?v=20260924c').then(function(mod){
        adminPanel = mod.initAdminPanel({
          supa:supa, escapeHtml:escapeHtml, fmtNum:fmtNum, fmtDate:fmtDate, fmtDateTime:fmtDateTime,
          toast:toast, showConfirm:showConfirm, loadServers:loadServers,
          settingsPackageRows:settingsPackageRows, POINTS_REASON:POINTS_REASON,
          // หลังแอดมินทำรายการที่แต้มเปลี่ยน — อัปเดตแต้ม/แพ็กของแอดมินเองทันที (เผื่อทำกับบัญชีตัวเอง)
          syncProfile:function(){ syncProfileQuietly(true); },
          // ตัวแปรเดียวกับของ app.js (หน้าแอดมินจัดลำดับเซิร์ฟเวอร์แล้วเขียนกลับ) — ห้ามส่งเป็นค่าคัดลอก
          get SERVER_RATES(){ return SERVER_RATES; },
          set SERVER_RATES(v){ SERVER_RATES = v; }
        });
        return adminPanel;
      });
    }
    adminPanelLoading.then(function(p){ p.openAdminPage(); }, function(err){
      adminPanelLoading = null;
      console.error('admin panel load failed', err);
      Track.error('load', err);
      toast('โหลดหน้าแอดมินไม่สำเร็จ ลองเปิดหน้าแอดมินอีกครั้ง');
    });
  }

  // ---------- การ์ด "ปาร์ตี้" บนหน้าจับเวลาบอส (พับได้) ----------
  // ลิสต์เดียวรวมหัวปาร์ตี้+สมาชิกทั้งหมด — แสดงปาร์ตี้ที่ตัวเองอยู่ตอนนี้เท่านั้น (คนละ 1 ปาร์ตี้ต่อครั้ง)
  var partyPanelMemberCount = 0;
  function updatePartyPanelSummary(){
    var prefix = App.viewingHostId ? ('กำลังดูปาร์ตี้ของ '+(App.viewingHostName||'-')+' · ') : '';
    document.getElementById('partyPanelSummary').textContent =
      prefix+'สมาชิกในปาร์ตี้ '+partyPanelMemberCount+' คน';
    document.getElementById('partyPanel').classList.toggle('viewing-party', !!App.viewingHostId);
  }
  function renderPartyPanel(){
    var listEl = document.getElementById('myPartyList');
    if(!App.session || !App.session.id){
      partyPanelMemberCount = 0;
      if(listEl) listEl.innerHTML = '';
      updatePartyPanelSummary();
      return;
    }
    listEl.innerHTML = '<p class="admin-topup-empty">กำลังโหลด...</p>';
    var amHost = !App.viewingHostId;
    var contextHostId = App.viewingHostId || App.session.id;
    var contextHostName = App.viewingHostId ? App.viewingHostName : ((App.profile && App.profile.display_name) || '-');

    supa.from('party_members').select('member_id, profiles!member_id(display_name)').eq('host_id', contextHostId).is('removed_at', null).then(function(res){
      if(res.error){ listEl.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</p>'; return; }
      var members = res.data || [];
      partyPanelMemberCount = members.length + 1;
      updatePartyPanelSummary();

      var hostRow = '<div class="admin-topup-row party-member-row">'+
        '<div class="admin-topup-main"><div class="admin-topup-user">'+escapeHtml(contextHostName)+' <span class="party-role-tag">หัวปาร์ตี้'+(amHost?' · คุณ':'')+'</span></div></div>'+
        '<div class="admin-topup-actions">'+(!amHost ? '<button type="button" class="btn btn-ghost btn-sm" data-leave-party="'+contextHostId+'">ออกจากปาร์ตี้</button>' : '')+'</div>'+
      '</div>';
      var memberRows = members.map(function(m){
        var name = (m.profiles && m.profiles.display_name) || 'ไม่ทราบชื่อ';
        var isMe = m.member_id === App.session.id;
        return '<div class="admin-topup-row party-member-row">'+
          '<div class="admin-topup-main"><div class="admin-topup-user">'+escapeHtml(name)+(isMe?' <span class="party-role-tag">คุณ</span>':'')+'</div></div>'+
          '<div class="admin-topup-actions">'+(amHost ? '<button type="button" class="btn btn-ghost btn-sm" data-remove-member="'+m.member_id+'">เอาออก</button>' : '')+'</div>'+
        '</div>';
      }).join('');
      listEl.innerHTML = hostRow + memberRows;
    });
  }
  // รูปไอเทมโหลดไม่ได้ (ลิงก์ผิด/ไฟล์ถูกลบ) → กลับไปใช้ช่องติ๊ก ✓ แบบเดิม ไม่ให้เหลือช่องว่างเปล่า
  document.getElementById('roster').addEventListener('error', function(e){
    var img = e.target;
    if(!(img && img.tagName==='IMG' && img.parentNode && img.parentNode.classList && img.parentNode.classList.contains('has-img'))) return;
    var dot = img.parentNode;
    dot.classList.remove('has-img');
    dot.textContent = dot.closest('.item-chip').classList.contains('selected') ? '✓' : '';
  }, true);
  // รูปในการ์ดสถิติโหลดไม่ได้ (ลิงก์เสีย) → ซ่อนช่องรูปไปเลย ไม่ทิ้งกรอบว่างไว้
  document.querySelector('.stats-row').addEventListener('error', function(e){
    var img = e.target;
    if(!(img && img.tagName==='IMG' && img.parentNode && img.parentNode.classList && img.parentNode.classList.contains('stat-thumb'))) return;
    img.parentNode.hidden = true; img.parentNode.innerHTML = '';
  }, true);

  document.getElementById('partyPanelToggle').addEventListener('click', function(){
    var body = document.getElementById('partyPanelBody');
    body.hidden = !body.hidden;
    this.textContent = body.hidden ? 'จัดการปาร์ตี้' : 'ซ่อน';
  });

  document.getElementById('myPartyList').addEventListener('click', function(e){
    var removeBtn = e.target.closest('[data-remove-member]');
    if(removeBtn){
      var memberId = removeBtn.dataset.removeMember;
      showConfirm('เอาเพื่อนคนนี้ออกจากปาร์ตี้? สล็อตนี้จะเสียไปเลย เพิ่มคนใหม่ต้องจ่าย 50 แต้มใหม่', function(){
        supa.rpc('remove_party_member', { target_member_id: memberId }).then(function(res){
          if(res.error){ toast('ทำรายการไม่สำเร็จ: '+res.error.message); return; }
          toast('เอาออกจากปาร์ตี้แล้ว');
          renderPartyPanel();
        });
      });
      return;
    }
    var leaveBtn = e.target.closest('[data-leave-party]');
    if(leaveBtn){
      var leaveHostId = leaveBtn.dataset.leaveParty;
      showConfirm('ออกจากปาร์ตี้ของ '+(App.viewingHostName||'-')+'? สล็อตนี้จะเสียไปเลย หัวปาร์ตี้ต้องจ่าย 50 แต้มใหม่ถ้าจะเพิ่มคุณกลับเข้าปาร์ตี้อีกครั้ง', function(){
        supa.rpc('leave_party', { target_host_id: leaveHostId }).then(function(res){
          if(res.error){ toast('ทำรายการไม่สำเร็จ: '+res.error.message); return; }
          toast('ออกจากปาร์ตี้แล้ว');
          resolvePartyContext().then(function(){
            // ออกจากปาร์ตี้แล้ว = กลับมาดูข้อมูลของตัวเอง
            return Promise.all([ loadUserBosses(), loadKills() ]);
          }).then(function(){ renderRoster(); renderStats(); updatePartyPanelSummary(); renderPartyPanel(); });
        });
      });
    }
  });

  document.getElementById('addPartyMemberBtn').addEventListener('click', function(){
    document.getElementById('addPartyMemberEmail').value = '';
    document.getElementById('addPartyMemberOverlay').hidden = false;
  });
  document.getElementById('addPartyMemberCancelBtn').addEventListener('click', function(){
    document.getElementById('addPartyMemberOverlay').hidden = true;
  });
  document.querySelector('#addPartyMemberOverlay .confirm-backdrop').addEventListener('click', function(){
    document.getElementById('addPartyMemberOverlay').hidden = true;
  });
  var addPartyMemberBusy = false;
  document.getElementById('addPartyMemberConfirmBtn').addEventListener('click', function(){
    if(addPartyMemberBusy) return;
    // รับได้ทั้งอีเมลหรือ username — ฝั่งเซิร์ฟเวอร์ (add_party_member) หาบัญชีจากทั้งสองอย่างเอง
    var email = document.getElementById('addPartyMemberEmail').value.trim().toLowerCase();
    if(!email){ toast('กรุณากรอกอีเมล หรือ Username ของเพื่อน'); return; }
    addPartyMemberBusy = true;
    supa.rpc('add_party_member', { member_email: email }).then(function(res){
      addPartyMemberBusy = false;
      if(res.error){ toast('เพิ่มไม่สำเร็จ: '+res.error.message); return; }
      document.getElementById('addPartyMemberOverlay').hidden = true;
      refreshProfile();
      renderPartyPanel();
      toast('เพิ่มเพื่อนเข้าปาร์ตี้แล้ว');
    });
  });

  document.querySelectorAll('.rail-btn[data-page]').forEach(function(btn){
    btn.addEventListener('click', function(){ switchPage(btn.dataset.page); });
  });
  // Dashboard shortcuts only forward existing navigation or reveal the existing form.
  document.querySelector('#view-home .dashboard-shortcuts').addEventListener('click', function(e){
    var pageButton = e.target.closest('[data-dashboard-page]');
    if(pageButton){
      var navButton = document.querySelector('.rail .rail-btn[data-page="'+pageButton.dataset.dashboardPage+'"]');
      if(navButton) navButton.click();
      return;
    }
    if(e.target.closest('[data-dashboard-section="mrEntryPanel"]')){
      document.getElementById('mrEntryPanel').scrollIntoView({ block:'start', behavior:'auto' });
    }
  });
  // ---------- ticker: which servers' announcements to show (mirrors the rate-chip cards) ----------
  document.getElementById('tickerServerChips').addEventListener('click', function(e){
    var chip = e.target.closest('[data-ticker-server]');
    if(!chip) return;
    var id = chip.dataset.tickerServer;
    var idx = App.tickerSelectedServers.indexOf(id);
    if(idx===-1) App.tickerSelectedServers.push(id); else App.tickerSelectedServers.splice(idx,1);
    saveTickerSelectedServers();
    renderTickerServerChips();
  });

  // ---------- post a rate announcement ----------
  var editingAnnouncementId = null;

  function openPostAnnouncement(entry){
    editingAnnouncementId = entry ? entry.id : null;
    var sel = document.getElementById('postAnnounceServer');
    sel.innerHTML = App.tickerServers.map(function(id){
      var s = serverRateById(id);
      return '<option value="'+id+'">'+(s?s.name:id)+'</option>';
    }).join('');
    var durSel = document.getElementById('postAnnounceDuration');
    // แก้ไขประกาศเดิมไม่เสียแต้ม (ระยะเวลาถูกล็อกไว้ไม่ให้แก้อยู่แล้ว) เลยไม่ต้องโชว์ราคาต่อท้าย
    durSel.innerHTML = ANNOUNCE_DURATION_OPTIONS.map(function(o){
      return '<button type="button" class="announce-duration-btn" data-value="'+o.value+'">'+o.label+(entry ? '' : '<span class="announce-duration-cost">('+o.cost+' แต้ม)</span>')+'</button>';
    }).join('');

    if(entry){
      sel.value = entry.serverId;
      // durationMs คำนวณจาก (expires_at - created_at) ซึ่งคลาดจากค่าใน dropdown อยู่หลักมิลลิวินาที
      // เพราะเวลาเริ่มนับใช้นาฬิกาของเซิร์ฟเวอร์ ไม่ใช่ของเครื่อง — เลยต้องเลือกตัวเลือกที่ใกล้ที่สุด
      // ไม่งั้นช่องนี้จะโชว์ว่างเปล่าตอนกดแก้ไข
      setAnnounceDuration(durSel, ANNOUNCE_DURATION_OPTIONS.reduce(function(a,b){
        return Math.abs(b.value-entry.durationMs) < Math.abs(a.value-entry.durationMs) ? b : a;
      }).value, true);
      document.querySelector('#postAnnounceTitle span').textContent = 'แก้ไขประกาศ';
      document.getElementById('postAnnounceSubmitBtn').textContent = 'บันทึกการแก้ไข';
      document.getElementById('postAnnounceBuyPrice').value = entry.buy!=null ? fmtNum(entry.buy) : '';
    } else {
      setAnnounceDuration(durSel, ANNOUNCE_DURATION_OPTIONS[2].value, false); // default 1 ชม.
      document.querySelector('#postAnnounceTitle span').textContent = 'ลงประกาศ รับ M';
      document.getElementById('postAnnounceSubmitBtn').textContent = 'ลงประกาศ';
      document.getElementById('postAnnounceBuyPrice').value = '';
    }
    document.getElementById('postAnnouncementOverlay').hidden = false;
  }
  // เลือกระยะเวลาด้วยปุ่มแทน <select> เพราะ option ปกติลงสีแค่บางส่วนของข้อความไม่ได้
  function setAnnounceDuration(container, value, disabled){
    container.dataset.value = value;
    container.querySelectorAll('.announce-duration-btn').forEach(function(b){
      b.classList.toggle('active', b.dataset.value===String(value));
      b.disabled = !!disabled;
    });
  }
  document.getElementById('postAnnounceDuration').addEventListener('click', function(e){
    var btn = e.target.closest('.announce-duration-btn');
    if(!btn || btn.disabled) return;
    setAnnounceDuration(this, btn.dataset.value, false);
  });
  function closePostAnnouncement(){
    editingAnnouncementId = null;
    document.getElementById('postAnnouncementOverlay').hidden = true;
  }

  document.getElementById('postAnnouncementBtn').addEventListener('click', function(){ openPostAnnouncement(null); });
  document.getElementById('postAnnounceCancelBtn').addEventListener('click', closePostAnnouncement);
  document.querySelector('#postAnnouncementOverlay .confirm-backdrop').addEventListener('click', closePostAnnouncement);

  document.getElementById('postAnnounceBuyPrice').addEventListener('input', function(){
    var digits = this.value.replace(/[^\d]/g,'');
    this.value = digits ? Number(digits).toLocaleString('th-TH') : '';
  });

  document.getElementById('postAnnounceSubmitBtn').addEventListener('click', function(){
    var serverId = document.getElementById('postAnnounceServer').value;
    var buyVal = parseFloat(document.getElementById('postAnnounceBuyPrice').value.replace(/,/g,''));
    if(!(buyVal>0)){ toast('กรอกราคารับ M'); return; }
    var refSv = serverRateById(serverId);
    if(refSv && refSv.buy>0){
      var deviation = Math.abs(buyVal-refSv.buy)/refSv.buy;
      if(deviation > RATE_MAX_DEVIATION){
        toast('ราคาต่างจากราคาปัจจุบัน ('+fmtNum(refSv.buy)+'บ) เกิน '+Math.round(RATE_MAX_DEVIATION*100)+'% กรุณาตรวจสอบราคาอีกครั้ง');
        return;
      }
    }
    var btn = this;
    btn.disabled = true;
    var done = function(msg){
      btn.disabled = false;
      closePostAnnouncement();
      refreshAnnouncementsIfChanged(true);
      toast(msg);
    };
    var failed = function(err){
      btn.disabled = false;
      console.warn('announcement save', err);
      toast('บันทึกประกาศไม่สำเร็จ ลองใหม่อีกครั้ง');
    };
    if(editingAnnouncementId){
      // แก้ได้แค่เซิร์ฟเวอร์กับราคา — นาฬิกานับถอยหลังไม่รีเซ็ต (ฝั่ง DB ก็ล็อกไว้ด้วย trigger) ไม่เสียแต้มเพิ่ม
      supa.from('announcements').update({ server_id:serverId, buy:buyVal })
        .eq('id', editingAnnouncementId)
        .then(function(res){ if(res.error) return failed(res.error); done('แก้ไขประกาศแล้ว'); }, failed);
    } else {
      var durationMs = parseInt(document.getElementById('postAnnounceDuration').dataset.value, 10);
      // ลงประกาศใหม่เสียแต้มตามระยะเวลา — หักแต้ม+บันทึกประกาศทำในฟังก์ชันเดียวกันฝั่ง DB (atomic)
      // กันแต้มถูกหักแต่ประกาศไม่ขึ้น หรือประกาศขึ้นฟรีโดยไม่หักแต้ม
      supa.rpc('post_announcement', { p_server_id:serverId, p_buy:buyVal, p_duration_ms:durationMs }).then(function(res){
        if(res.error){ btn.disabled = false; toast(res.error.message); return; }
        refreshProfile();
        done('ลงประกาศแล้ว');
      }, failed);
    }
  });

  // ---------- "ลงประกาศ" dropdown → manage my own announcements ----------
  document.getElementById('tickerPostMenuToggle').addEventListener('click', function(e){
    e.stopPropagation();
    var menu = document.getElementById('tickerPostMenu');
    menu.hidden = !menu.hidden;
  });
  document.addEventListener('click', function(e){
    if(!e.target.closest('.ticker-post-group')) document.getElementById('tickerPostMenu').hidden = true;
  });

  function renderMyAnnouncements(){
    var list = document.getElementById('myAnnouncementsList');
    var mine = App.session ? App.session.id : null;
    var now = Date.now();
    var posts = App.rateAnnouncements.filter(function(a){ return a.userId===mine && (a.expiresAt==null || a.expiresAt>now); })
                                      .slice().sort(function(a,b){ return b.ts-a.ts; });
    if(!posts.length){
      list.innerHTML = '<p class="my-announce-empty">คุณยังไม่มีประกาศที่ใช้งานอยู่</p>';
      return;
    }
    list.innerHTML = posts.map(function(a){
      var sv = serverRateById(a.serverId);
      var parts = [];
      if(a.buy!=null) parts.push('<span class="buy">รับ '+fmtNum(a.buy)+'บ</span>');
      return '<div class="my-announce-row" data-my-announce-id="'+a.id+'">'+
        '<div class="my-announce-row-top"><span>'+(sv?sv.name:a.serverId)+' '+parts.join(' / ')+'</span>'+
          '<span class="mr-entry-actions">'+
            '<button type="button" class="mr-edit" data-my-announce-edit="'+a.id+'" title="แก้ไข">✎</button>'+
            '<button type="button" class="mr-del" data-my-announce-del="'+a.id+'" title="ยกเลิกประกาศ">🗑</button>'+
          '</span>'+
        '</div>'+
        '<div class="my-announce-row-sub">เหลือเวลา '+fmtDuration(a.expiresAt-now)+'</div>'+
      '</div>';
    }).join('');
  }

  document.getElementById('openMyAnnouncementsBtn').addEventListener('click', function(){
    document.getElementById('tickerPostMenu').hidden = true;
    renderMyAnnouncements();
    document.getElementById('myAnnouncementsOverlay').hidden = false;
  });
  function closeMyAnnouncements(){ document.getElementById('myAnnouncementsOverlay').hidden = true; }
  document.getElementById('myAnnouncementsCloseBtn').addEventListener('click', closeMyAnnouncements);
  document.querySelector('#myAnnouncementsOverlay .confirm-backdrop').addEventListener('click', closeMyAnnouncements);

  document.getElementById('myAnnouncementsList').addEventListener('click', function(e){
    var editBtn = e.target.closest('[data-my-announce-edit]');
    if(editBtn){
      var entry = App.rateAnnouncements.filter(function(a){ return a.id===editBtn.dataset.myAnnounceEdit; })[0];
      if(entry){ closeMyAnnouncements(); openPostAnnouncement(entry); }
      return;
    }
    var delBtn = e.target.closest('[data-my-announce-del]');
    if(delBtn){
      var id = delBtn.dataset.myAnnounceDel;
      showConfirm('ยืนยันยกเลิกประกาศนี้?', function(){
        supa.from('announcements').delete().eq('id', id).then(function(res){
          if(res.error){ console.warn('announcement delete', res.error); toast('ยกเลิกประกาศไม่สำเร็จ ลองใหม่อีกครั้ง'); return; }
          refreshAnnouncementsIfChanged(true).then(renderMyAnnouncements);
          toast('ยกเลิกประกาศแล้ว');
        }, function(err){ console.warn('announcement delete', err); toast('ยกเลิกประกาศไม่สำเร็จ ลองใหม่อีกครั้ง'); });
      });
    }
  });

  // ---------- ยอดนักฟาม wiring ----------
  document.getElementById('farmServerSelect').addEventListener('change', function(e){
    App.farmServerId = e.target.value;
    saveFarmServer();
    resetFarmTimeframes();
    renderFarmExchangeRate();
    renderFarmMapName();
    renderFarmCostItems();
    renderFarmChart();
    renderFarmHistory();
    // สลับเซิร์ฟแล้วต้องคำนวณใหม่ว่าเซิร์ฟนี้ยังเล่นอยู่ไหม (เปิด/ปิดช่องกรอกตามนั้น)
    renderFarmRetiredState();
  });

  document.getElementById('farmExRateInput').addEventListener('input', function(){
    var digits = this.value.replace(/[^\d]/g,'');
    this.value = digits ? Number(digits).toLocaleString('th-TH') : '';
    App.farmExchangeRates[App.farmServerId] = digits || '';
    saveFarmExchangeRates();
    this.classList.remove('farm-exrate-invalid');
    document.getElementById('farmExRateError').hidden = true;
    updateFarmCostSummary();
  });

  document.getElementById('farmMapInput').addEventListener('input', function(){
    App.farmMapNames[App.farmServerId] = this.value;
    saveFarmMapNames();
  });

  document.getElementById('farmTimeframeSelect').addEventListener('change', function(e){
    farmTimeframe = e.target.value;
    renderFarmChart();
  });

  document.getElementById('farmUnitToggle').addEventListener('click', function(e){
    var btn = e.target.closest('[data-unit]');
    if(!btn) return;
    farmChartUnit = btn.dataset.unit;
    document.querySelectorAll('#farmUnitToggle .seg-btn').forEach(function(b){ b.classList.toggle('active', b===btn); });
    renderFarmChart();
  });

  document.getElementById('farmHistoryRange').addEventListener('change', function(e){
    farmHistoryRange = e.target.value;
    farmHistoryPage = 0;
    renderFarmHistory();
  });
  document.getElementById('farmHistoryPagination').addEventListener('click', function(e){
    if(e.target.closest('#farmHistPrev')){ farmHistoryPage--; renderFarmHistory(); return; }
    if(e.target.closest('#farmHistNext')){ farmHistoryPage++; renderFarmHistory(); return; }
  });
  document.getElementById('farmHistoryPagination').addEventListener('change', function(e){
    if(e.target.id==='farmHistPageSize'){
      FARM_HISTORY_PAGE_SIZE = parseInt(e.target.value, 10) || 5;
      farmHistoryPage = 0;
      renderFarmHistory();
    }
  });

  document.getElementById('farmChartLegend').addEventListener('click', function(e){
    var btn = e.target.closest('[data-farm-legend]');
    if(!btn) return;
    hiddenFarmSeries[btn.dataset.farmLegend] = !hiddenFarmSeries[btn.dataset.farmLegend];
    renderFarmChart();
  });

  document.getElementById('farmSeriesChips').addEventListener('click', function(e){
    var btn = e.target.closest('[data-farm-legend-remove]');
    if(!btn) return;
    hiddenFarmSeries[btn.dataset.farmLegendRemove] = true;
    renderFarmChart();
  });

  document.getElementById('farmSeriesDropdown').addEventListener('click', function(e){
    var btn = e.target.closest('[data-farm-legend-add]');
    if(!btn) return;
    hiddenFarmSeries[btn.dataset.farmLegendAdd] = false;
    renderFarmChart();
    document.getElementById('farmSeriesDropdown').hidden = true;
  });

  document.getElementById('farmSeriesDropdownBtn').addEventListener('click', function(e){
    e.stopPropagation();
    var dd = document.getElementById('farmSeriesDropdown');
    dd.hidden = !dd.hidden;
  });

  document.addEventListener('click', function(e){
    if(!e.target.closest('#farmSeriesFilter')) document.getElementById('farmSeriesDropdown').hidden = true;
  });

  document.getElementById('farmChartSvg').addEventListener('mousemove', handleFarmChartHover);
  document.getElementById('farmChartSvg').addEventListener('mouseleave', hideFarmChartHover);

  document.getElementById('farmCostItems').addEventListener('input', function(e){
    var row = e.target.closest('[data-row-id]');
    if(!row) return;
    var r = farmCostRows(App.farmServerId).filter(function(x){ return x.id===row.dataset.rowId; })[0];
    if(!r) return;
    if(e.target.classList.contains('farm-cost-name')) r.name = e.target.value;
    if(e.target.classList.contains('farm-cost-price')){
      var digits = e.target.value.replace(/[^\d]/g,'');
      r.price = digits;
      e.target.value = digits ? Number(digits).toLocaleString('th-TH') : '';
    }
    if(e.target.classList.contains('farm-cost-qty')) r.qty = e.target.value;
    saveFarmCostItems();
    updateFarmCostSummary();
  });

  document.getElementById('farmCostItems').addEventListener('change', function(e){
    if(!e.target.classList.contains('farm-cost-currency')) return;
    var row = e.target.closest('[data-row-id]');
    if(!row) return;
    var r = farmCostRows(App.farmServerId).filter(function(x){ return x.id===row.dataset.rowId; })[0];
    if(!r) return;
    r.currency = e.target.value;
    saveFarmCostItems();
    updateFarmCostSummary();
  });

  document.getElementById('farmCostItems').addEventListener('click', function(e){
    var btn = e.target.closest('[data-remove-row]');
    if(!btn || btn.disabled) return;
    App.farmCostItems[App.farmServerId] = farmCostRows(App.farmServerId).filter(function(r){ return r.id!==btn.dataset.removeRow; });
    saveFarmCostItems();
    renderFarmCostItems();
  });

  document.getElementById('farmAddCostRowBtn').addEventListener('click', function(){
    farmCostRows(App.farmServerId).push({ id:uid(), name:'', price:'', qty:'', currency:'zeny' });
    saveFarmCostItems();
    renderFarmCostItems();
  });

  document.getElementById('farmRareItems').addEventListener('input', function(e){
    var row = e.target.closest('[data-row-id]');
    if(!row) return;
    var r = farmRareItemRows.filter(function(x){ return x.id===row.dataset.rowId; })[0];
    if(!r) return;
    if(e.target.classList.contains('farm-rare-name')) r.name = e.target.value;
    if(e.target.classList.contains('farm-rare-price')){
      var digits = e.target.value.replace(/[^\d]/g,'');
      e.target.value = digits ? Number(digits).toLocaleString('th-TH') : '';
      r.price = digits;
    }
    if(e.target.classList.contains('farm-rare-qty')) r.qty = e.target.value;
  });

  document.getElementById('farmRareItems').addEventListener('change', function(e){
    if(!e.target.classList.contains('farm-rare-currency')) return;
    var row = e.target.closest('[data-row-id]');
    if(!row) return;
    var r = farmRareItemRows.filter(function(x){ return x.id===row.dataset.rowId; })[0];
    if(!r) return;
    r.currency = e.target.value;
  });

  document.getElementById('farmRareItems').addEventListener('click', function(e){
    var btn = e.target.closest('[data-remove-rare-row]');
    if(!btn || btn.disabled) return;
    farmRareItemRows = farmRareItemRows.filter(function(r){ return r.id!==btn.dataset.removeRareRow; });
    if(!farmRareItemRows.length) farmRareItemRows = [{ id:uid(), name:'', price:'', qty:'', currency:'zeny' }];
    renderFarmRareItems();
  });

  document.getElementById('farmAddRareItemBtn').addEventListener('click', function(){
    farmRareItemRows.push({ id:uid(), name:'', price:'', qty:'', currency:'zeny' });
    renderFarmRareItems();
  });

  // คำใบ้กันกรอกผิดช่อง: ช่องนี้คือยอดรวมทั้งรอบ โชว์ค่าเฉลี่ยต่อกั้มให้เห็นทันทีถ้ากรอกจำนวนกั้ม > 1
  function updateFarmEarnedHint(){
    var hint = document.getElementById('farmEarnedHint');
    var count = parseInt(document.getElementById('farmCountInput').value, 10) || 1;
    var val = parseFloat((document.getElementById('farmEarnedInput').value||'').replace(/,/g,'')) || 0;
    hint.hidden = !(val>0 && count>1);
    if(!hint.hidden) hint.textContent = '≈ '+fmtNum(Math.round(val/count))+' z/กั้ม (ยอดรวม ÷ '+count+' กั้ม)';
  }
  document.getElementById('farmEarnedInput').addEventListener('input', function(){
    var digits = this.value.replace(/[^\d]/g,'');
    this.value = digits ? Number(digits).toLocaleString('th-TH') : '';
    updateFarmEarnedHint();
  });
  document.getElementById('farmCountInput').addEventListener('input', updateFarmEarnedHint);

  document.getElementById('farmEarnedInput').addEventListener('focus', showFarmOcHint);

  document.getElementById('farmOcHintOkBtn').addEventListener('click', function(){
    farmOcHintAcknowledged = true;
    if(document.getElementById('farmOcHintDontShow').checked){
      persist(App.keys.farmOcHint, true);
    }
    document.getElementById('farmOcHintOverlay').hidden = true;
  });
  document.getElementById('farmOcHintCancelBtn').addEventListener('click', function(){
    document.getElementById('farmOcHintOverlay').hidden = true;
  });
  document.querySelector('#farmOcHintOverlay .confirm-backdrop').addEventListener('click', function(){
    document.getElementById('farmOcHintOverlay').hidden = true;
  });

  document.getElementById('farmOcToggle').addEventListener('click', function(){
    farmOcHintAcknowledged = false;
    farmOcActive = !farmOcActive;
    this.classList.toggle('active', farmOcActive);
    var earnedInput = document.getElementById('farmEarnedInput');
    var raw = parseFloat(earnedInput.value.replace(/,/g,'')) || 0;
    if(farmOcActive){
      var boosted = Math.round(raw * 1.24);
      earnedInput.value = boosted ? fmtNum(boosted) : '';
    } else {
      var base = Math.round(raw / 1.24);
      earnedInput.value = base ? fmtNum(base) : '';
    }
    updateFarmEarnedHint();
  });

  document.getElementById('farmLogConfirm').addEventListener('click', function(){
    // บัญชีฟรี: บันทึกใหม่ได้วันละ 3 ครั้ง (แก้ไขรายการเดิมไม่นับ)
    if(!editingFarmId && freeFarmLeft() <= 0){
      showFreeLimitPopup('บัญชีฟรีบันทึกต้นทุนต่อกั้มได้ '+FREE_FARM_DAILY_MAX+' ครั้งต่อวัน — วันนี้ครบแล้ว'+
        '<span class="confirm-detail">สมัครแพ็กเกจ 1 in 1, 3 in 1 หรือ 4 in 1 เพื่อบันทึกได้ไม่จำกัด (พรุ่งนี้บันทึกแบบฟรีได้อีก '+FREE_FARM_DAILY_MAX+' ครั้ง)</span>');
      return;
    }
    var countInput = document.getElementById('farmCountInput');
    var earnedInput = document.getElementById('farmEarnedInput');
    var count = parseInt(countInput.value, 10) || 1;
    var val = parseFloat(earnedInput.value.replace(/,/g,''));
    if(!val || val<=0){ toast('กรอกยอดที่ฟามได้ก่อน'); return; }
    var costBd = farmCostBreakdown(App.farmServerId);
    if(!(costBd.rate>0)){
      var exRateInput = document.getElementById('farmExRateInput');
      exRateInput.classList.add('farm-exrate-invalid');
      document.getElementById('farmExRateError').hidden = false;
      exRateInput.focus();
      showFarmRateRequiredPopup();
      return;
    }
    if(count<1) count = 1;
    var cost = farmCostTotal(App.farmServerId) * count;
    var rareItemsSnapshot = farmRareItemRows
      .filter(function(r){ return (r.name||'').trim() || (parseFloat(r.price)||0)>0; })
      .map(function(r){ return { id:r.id, name:(r.name||'').trim(), price: r.price===''||r.price==null?null:parseFloat(r.price), qty: parseFloat(r.qty)||1, currency: r.currency||'zeny' }; });
    var rareTotal = rareItemsSnapshot.reduce(function(s,r){
      var lineTotal = (r.price||0)*r.qty;
      return s + (r.currency==='baht' ? farmBahtToZeny(lineTotal, costBd.rate) : lineTotal);
    }, 0);
    var totalEarned = val + rareTotal;

    function commitFarmLog(){
      var scrollX = window.scrollX, scrollY = window.scrollY;
      if(editingFarmId){
        var entry = App.farmLog.filter(function(e){ return e.id===editingFarmId; })[0];
        if(entry){
          entry.serverId = App.farmServerId;
          entry.count = count;
          entry.cost = cost;
          entry.earnedBase = val;
          entry.ocApplied = farmOcActive;
          entry.rareItems = rareItemsSnapshot;
          entry.earned = totalEarned;
          entry.profit = totalEarned-cost;
          entry.costItems = farmSnapshotCostRows(App.farmServerId);
          entry.exchangeRate = farmExchangeRate(App.farmServerId) || null;
          entry.mapName = App.farmMapNames[App.farmServerId] || '';
        }
        saveFarmLog();
        resetFarmEditState();
        renderFarmHistory();
        renderFarmChart();
        preserveFarmViewport(scrollX, scrollY);
        toast('แก้ไขรายการแล้ว');
      } else {
        App.farmLog.push({ id:uid(), ts:Date.now(), serverId:App.farmServerId, count:count, cost:cost, earnedBase:val, ocApplied:farmOcActive, rareItems: rareItemsSnapshot, earned:totalEarned, profit:totalEarned-cost, costItems: farmSnapshotCostRows(App.farmServerId), exchangeRate: farmExchangeRate(App.farmServerId) || null, mapName: App.farmMapNames[App.farmServerId] || '' });
        saveFarmLog();
        farmOcHintAcknowledged = false;
        earnedInput.value = '';
        countInput.value = '1';
        updateFarmEarnedHint();
        farmRareItemRows = [{ id:uid(), name:'', price:'', qty:'', currency:'zeny' }];
        renderFarmRareItems();
        renderFarmHistory();
        renderFarmChart();
        toast('บันทึก '+count+' กั้มแล้ว');
      }
    }

    if(editingFarmId){
      showConfirm('ยืนยันบันทึกการแก้ไขรายการนี้?', commitFarmLog);
    } else {
      commitFarmLog();
    }
  });

  document.getElementById('farmCancelEdit').addEventListener('click', cancelFarmEdit);

  // Capture phase, not bubble — so this runs before an in-panel click handler
  // (e.g. "+เพิ่ม Slot") re-renders and detaches e.target from the live document,
  // which would otherwise fail every closest() check below and wrongly treat an
  // inside click as "outside". Clicking anywhere outside the farm-cost panel / the
  // history row being edited while an edit is in progress cancels it.
  document.addEventListener('click', function(e){
    if(!editingFarmId) return;
    if(e.target.closest('[data-farm-edit]')) return;
    if(e.target.closest('[data-farm-del]')) return;
    if(e.target.closest('.panel-farm-cost')) return;
    if(e.target.closest('#confirmOverlay')) return;
    if(e.target.closest('#farmRateRequiredOverlay')) return;
    if(e.target.closest('#farmOcHintOverlay')) return;
    cancelFarmEdit();
  }, true);

  document.getElementById('farmHistoryList').addEventListener('click', function(e){
    var dayToggleBtn = e.target.closest('[data-farm-day-toggle]');
    if(dayToggleBtn){
      var dk = decodeURIComponent(dayToggleBtn.dataset.farmDayToggle);
      var curCollapsed = farmHistoryDayCollapsed.hasOwnProperty(dk) ? farmHistoryDayCollapsed[dk] : true;
      farmHistoryDayCollapsed[dk] = !curCollapsed;
      renderFarmHistory();
      return;
    }
    var editBtn = e.target.closest('[data-farm-edit]');
    if(editBtn){ startEditFarmEntry(editBtn.dataset.farmEdit); return; }
    var btn = e.target.closest('[data-farm-del]');
    if(!btn) return;
    var id = btn.dataset.farmDel;
    showConfirm('ยืนยันลบรายการนี้?', function(){
      App.farmLog = App.farmLog.filter(function(x){ return x.id!==id; });
      saveFarmLog();
      if(editingFarmId===id) cancelFarmEdit();
      renderFarmHistory();
      renderFarmChart();
      toast('ลบรายการแล้ว');
    });
  });

  document.getElementById('farmHistoryList').addEventListener('mouseover', function(e){
    var costEl = e.target.closest('.farm-cost-hover');
    if(costEl){ showFarmCostTooltip(costEl); return; }
    var profitEl = e.target.closest('.farm-profit-hover');
    if(profitEl){ showFarmProfitTooltip(profitEl); return; }
    var incomeEl = e.target.closest('.farm-income-hover');
    if(incomeEl){ showFarmIncomeTooltip(incomeEl); return; }
  });
  document.getElementById('farmHistoryList').addEventListener('mouseout', function(e){
    var el = e.target.closest('.farm-cost-hover, .farm-profit-hover, .farm-income-hover');
    if(!el) return;
    document.getElementById('farmCostTooltip').hidden = true;
  });

  // ---------- search & add from catalog ----------
  var searchInput = document.getElementById('searchInput');
  var searchResults = document.getElementById('searchResults');
  if(CustomAPI){
    var customAddButton=customNode('button','+ เพิ่มบอส');customAddButton.type='button';customAddButton.className='btn btn-primary';customAddButton.id='addCustomBoss';
    customAddButton.onclick=function(){openCustomBossModal(null);};searchInput.closest('.toolbar').append(customAddButton);

  }

  function renderSearchResults(){
    var q = searchInput.value.trim().toLowerCase();
    // เรียง A–Z ไม่สนตัวพิมพ์ (ฐานข้อมูลส่งบอสมาตามลำดับที่บันทึก) บอส Custom เรียงปนกันไป · ชื่อเหมือนกันเรียงตามรหัส
    // ตอนพิมพ์ค้นหา: ชื่อที่ขึ้นต้นด้วยคำที่พิมพ์ขึ้นก่อน แล้วค่อยตามด้วยชื่อที่มีคำนั้นอยู่ตรงอื่น (แต่ละกลุ่มเรียง A–Z)
    var matches = CATALOG.concat(visibleCustomCatalog()).filter(function(b){ return !q || b.name.toLowerCase().indexOf(q)!==-1; })
      .sort(function(a, b){
        if(q){
          var aFirst = a.name.toLowerCase().indexOf(q)===0, bFirst = b.name.toLowerCase().indexOf(q)===0;
          if(aFirst!==bFirst) return aFirst ? -1 : 1;
        }
        return a.name.localeCompare(b.name, 'en', { numeric:true, sensitivity:'base' }) || String(a.id).localeCompare(String(b.id));
      });
    if(!matches.length){
      searchResults.innerHTML = '<p class="search-results-empty">ไม่พบบอสที่ค้นหาในระบบ</p>';
      searchResults.hidden = false;
      return;
    }
    var hint = q ? '' : '<div class="search-results-hint">บอสทั้งหมดในระบบ</div>';
    searchResults.innerHTML = hint + matches.map(function(b){
      var already = App.db.some(function(d){ return d.id===b.id; });
      return '<div class="search-result-row'+(already?' added':'')+'" data-catalog-id="'+b.id+'">'+
        '<div class="search-result-avatar">'+bossAvatarHtml(b)+'</div>'+
        '<div class="search-result-main"><div class="search-result-title">'+escapeHtml(b.name)+(b.custom ? ' <span class="custom-boss-badge">Custom</span>' : '')+'</div><div class="search-result-sub">เกิดใหม่ทุก '+b.minutes+' นาที • '+escapeHtml(b.loc)+'</div></div>'+
        '<div class="search-result-action">'+(already?'เพิ่มแล้ว ✓':'+ เพิ่ม')+'</div>'+
      '</div>';
    }).join('');
    searchResults.hidden = false;
  }

  searchInput.addEventListener('input', renderSearchResults);
  searchInput.addEventListener('focus', renderSearchResults);
  searchInput.addEventListener('keydown', function(e){
    if(e.key==='Escape'){ searchResults.hidden = true; searchInput.blur(); }
  });

  searchResults.addEventListener('click', function(e){
    if(isFreePartyMember()){ toast('แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น'); return; }
    var row = e.target.closest('.search-result-row');
    if(!row || row.classList.contains('added')) return;
    var boss = CATALOG.concat(visibleCustomCatalog()).filter(function(b){ return b.id===row.dataset.catalogId; })[0];
    if(!boss) return;
    App.db.push(boss);
    renderRoster();
    searchInput.value = '';
    searchResults.hidden = true;
    toast('เพิ่ม '+boss.name+' เข้ารายการแล้ว');
    supaAddBoss(boss.id).then(function(res){
      if(res.error){
        console.error('supaAddBoss', res.error);
        App.db = App.db.filter(function(b){ return b.id!==boss.id; });
        renderRoster();
        toast(res.error.message || ('เพิ่ม '+boss.name+' ไม่สำเร็จ ลองใหม่อีกครั้ง'));
      }
    });
  });

  document.addEventListener('click', function(e){
    if(!e.target.closest('.search-wrap')) searchResults.hidden = true;
  });

  // ---------- roster interactions ----------
  document.getElementById('roster').addEventListener('click', function(e){
    var card = e.target.closest('.boss-card');
    if(!card) return;
    var bossId = card.dataset.boss;
    var boss = App.db.filter(function(b){ return b.id===bossId; })[0];
    if(!boss) return;

    var mapEl = e.target.closest('[data-map]');
    if(mapEl){
      var rect = mapEl.getBoundingClientRect();
      var x = ((e.clientX - rect.left) / rect.width) * 100;
      var y = ((e.clientY - rect.top) / rect.height) * 100;
      x = Math.max(0, Math.min(100, x)).toFixed(1);
      y = Math.max(0, Math.min(100, y)).toFixed(1);
      App.markers[bossId] = { x:x, y:y };
      renderRoster();
      supaSetBossMarker(bossId, x, y).then(function(res){
        if(res.error) console.error('supaSetBossMarker', res.error);
      });
      return;
    }

    var chip = e.target.closest('.item-chip');
    if(chip){
      var item = chip.dataset.item;
      var arr = App.pendingItems[bossId] || [];
      var pos = arr.indexOf(item);
      if(pos===-1) arr.push(item); else arr.splice(pos,1);
      App.pendingItems[bossId] = arr;
      chip.classList.toggle('selected');
      var dot = chip.querySelector('.dot');
      if(!dot.classList.contains('has-img')) dot.textContent = chip.classList.contains('selected') ? '✓' : '';
      return;
    }

    var btn = e.target.closest('[data-action]');
    if(!btn) return;
    var action = btn.dataset.action;

    if(action==='custom-edit'){ openCustomBossModal(boss); return; }
    if(action==='custom-archive'){
      showConfirm('Archive '+escapeHtml(boss.name)+'? ประวัติเดิมยังคงอยู่', function(){
        customTask(function(){ return CustomAPI.rpc('archive_custom_boss', {p_boss_id:boss.rawId}); });
      }); return;
    }
    if(action==='remove'){
      App.db = App.db.filter(function(b){ return b.id!==bossId; });
      delete App.active[bossId];
      delete App.markers[bossId];
      delete App.pendingItems[bossId];
      renderRoster();
      toast('เอา '+boss.name+' ออกจากรายการแล้ว');
      supaRemoveBoss(bossId).then(function(res){
        if(res.error) console.error('supaRemoveBoss', res.error);
      });
    } else if(action==='kill'){
      if(isFreePartyMember()){ toast('แพ็กเกจฟรี เข้าร่วมปาร์ตี้ เยี่ยมชมเท่านั้น'); return; }
      var minutesInput = card.querySelector('[data-minutes]');
      var rawTimeInput = minutesInput ? minutesInput.value.trim() : '';
      // Empty field = died right now (unchanged default). A non-empty field must parse
      // into a valid time — เช่น 14.35 หรือ 1435 — or the kill doesn't get recorded with
      // wrong data; the field gets a small warning instead of silently using "now".
      var deathTs = rawTimeInput ? parseDeathTimeInput(rawTimeInput) : Date.now();
      if(deathTs==null){
        showFieldTip(minutesInput, 'รูปแบบเวลาไม่ถูกต้อง เช่น 14.35 หรือ 1435');
        return;
      }
      var items = (App.pendingItems[bossId] || []).slice();
      if(boss.custom){
        customTask(function(){
          return CustomAPI.record(customRef(bossId), activeOwnerId(), TIMERS_SERVER, App.session.id,
            new Date(deathTs).toISOString(), items, JSON.stringify([rawTimeInput, items.slice().sort()]), App.profile && App.profile.display_name);
        }, function(){ delete App.pendingItems[bossId]; fired.warn[bossId]=false; fired.threeMin[bossId]=false; });
        return;
      }
      supa.rpc('record_kill', { p_boss_id: String(boss.id), p_boss_name: boss.name, p_killed_at: new Date(deathTs).toISOString(), p_items: items }).then(function(res){
        if(res.error){ console.error('record_kill', res.error); toast('บันทึกประวัติการฆ่าไม่สำเร็จ: '+res.error.message); return; }
        bossNotifyChanged();
        loadKills().then(function(){ renderStats(); renderRoster(); });
      });

      var startedByName = App.profile ? App.profile.display_name : null;
      // ชดเชยเวลา UI เล็กน้อยทุกครั้งที่กด "MVP ตายแล้ว" ให้รอบใหม่เร็วขึ้น 3 วินาที
      // โดยคง timestamp เวลาตายจริงและข้อมูลประวัติเดิมไว้
      var targetTime = deathTs + boss.minutes*60000 - 3000;
      App.active[bossId] = { targetTime: targetTime, startedBy: startedByName };
      delete App.pendingItems[bossId];
      fired.warn[bossId] = false; fired.threeMin[bossId] = false;
      renderRoster(); renderStats();
      toast('บันทึกการฆ่า '+boss.name+' แล้ว — เริ่มจับเวลารอบใหม่');
      supaSetBossTime(bossId, targetTime, startedByName).then(function(res){
        if(res.error) console.error('supaSetBossTime', res.error);
      });
    } else if(action==='clear-time'){
      // ล้างเวลาที่จับอยู่ทั้งหมด กลับไปเป็น "ยังไม่ได้ฆ่า" — ไม่ใช่แค่เอาส่วนที่ปรับ
      // เวลาออก แต่เลิกจับเวลารอบนี้ทั้งรอบ (เผื่อกดผิดหรืออยากเริ่มนับใหม่)
      delete App.active[bossId];
      fired.warn[bossId] = false; fired.threeMin[bossId] = false;
      renderRoster(); renderStats();
      toast('เคลียร์เวลาของ '+boss.name+' แล้ว');
      supaSetBossTime(bossId, null, null).then(function(res){
        if(res.error) console.error('supaSetBossTime clear', res.error);
      });
    }
  });

  // ---------- inline death-time correction (Enter to apply while active) ----------
  document.getElementById('roster').addEventListener('keydown', function(e){
    if(e.key!=='Enter') return;
    var input = e.target.closest('[data-minutes]');
    if(!input) return;
    var card = input.closest('.boss-card');
    var bossId = card.dataset.boss;
    var boss = App.db.filter(function(b){ return b.id===bossId; })[0];
    var act = App.active[bossId];
    if(!act || !boss) return;
    var raw = input.value.trim();
    if(!raw) return;
    var deathTs = parseDeathTimeInput(raw);
    if(deathTs==null){ showFieldTip(input, 'รูปแบบเวลาไม่ถูกต้อง เช่น 14.35 หรือ 1435'); return; }
    act.targetTime = deathTs + boss.minutes*60000;
    fired.warn[bossId] = false; fired.threeMin[bossId] = false;
    renderRoster();
    toast('ปรับเวลาแล้ว');
    supaSetBossTime(bossId, act.targetTime, act.startedBy).then(function(res){
      if(res.error) console.error('supaSetBossTime adjust', res.error);
    });
  });

  // ---------- history panel ----------
  function openHistory(mode){
    App.historyTab = mode.indexOf('items') === 0 ? 'items' : 'kills';
    document.getElementById('todayOnly').checked = mode.indexOf('today') !== -1;
    document.getElementById('historyOverlay').hidden = false;
    renderHistory();
    loadPartyRoster().then(loadDepartedSharerNames).then(renderHistory);
  }
  document.querySelectorAll('[data-open-history]').forEach(function(btn){
    btn.addEventListener('click', function(){ openHistory(btn.dataset.openHistory); });
  });
  document.querySelectorAll('[data-close-history]').forEach(function(el){
    el.addEventListener('click', function(){ document.getElementById('historyOverlay').hidden = true; });
  });
  document.getElementById('htabKills').addEventListener('click', function(){ App.historyTab='kills'; renderHistory(); });
  document.getElementById('htabItems').addEventListener('click', function(){ App.historyTab='items'; renderHistory(); });
  document.getElementById('htabBoss').addEventListener('click', function(){ App.historyTab='boss'; renderHistory(); });

  // query ต้องต่อท้ายด้วย .select('id') เพื่อให้รู้ว่าลบได้จริงกี่แถว — ถ้า 0 แถว (ไม่มีสิทธิ์/รายการหายไปแล้ว) แจ้งว่าไม่สำเร็จ
  function runHistoryDelete(query, okMsg){
    return query.then(function(res){
      if(res.error){ console.error('history delete', res.error); toast('ลบไม่สำเร็จ: '+res.error.message); return; }
      if(!(res.data||[]).length){ toast('ลบไม่สำเร็จ: ไม่มีสิทธิ์ลบ หรือรายการถูกลบไปแล้ว'); return loadKills().then(function(){ renderHistory(); renderStats(); renderRoster(); }); }
      toast(okMsg);
      bossNotifyChanged();
      return loadKills().then(function(){ renderHistory(); renderStats(); renderRoster(); });
    });
  }
  document.getElementById('historyDeleteAll').addEventListener('click', function(){
    var n = App.kills.length, m = App.kills.reduce(function(s,k){ return s+k.items.length; }, 0);
    if(!n) return;
    showConfirm('ลบประวัติทั้งหมดของปาร์ตี้นี้ '+n+' การฆ่า · '+m+' ไอเทม (รวมข้อมูลหาร/ยอดขาย)? ลบแล้วกู้คืนไม่ได้', function(){
      runHistoryDelete(supa.from('kills').delete().eq('host_id', activeOwnerId()).select('id'), 'ลบประวัติทั้งหมดแล้ว');
    });
  });

  document.getElementById('historyList').addEventListener('click', function(e){
    var dk = e.target.closest('[data-del-kill]');
    if(dk){
      var kill = App.kills.filter(function(k){ return k.id===dk.dataset.delKill; })[0];
      if(!kill) return;
      showConfirm('ลบการฆ่า '+escapeHtml(kill.bossName)+' เมื่อ '+fmtDateTime(kill.ts)+(kill.items.length ? ' พร้อมไอเทม '+kill.items.length+' ชิ้น (รวมข้อมูลหาร/ยอดขาย)' : '')+'? ลบแล้วกู้คืนไม่ได้', function(){
        runHistoryDelete(supa.from('kills').delete().eq('id', kill.id).select('id'), 'ลบรายการแล้ว');
      });
      return;
    }
    var di = e.target.closest('[data-del-item]');
    if(di){
      var item = findKillItem(di.dataset.delItem);
      if(!item) return;
      var pk = App.kills.filter(function(k){ return k.items.indexOf(item)!==-1; })[0];
      showConfirm('ลบไอเทม '+escapeHtml(item.name)+(pk ? ' จาก '+escapeHtml(pk.bossName)+' ('+fmtDateTime(pk.ts)+')' : '')+(item.soldAmount!=null ? ' รวมยอดขาย '+fmtNum(item.soldAmount)+' '+currencyLabel(item.soldCurrency) : '')+'? ลบแล้วกู้คืนไม่ได้', function(){
        runHistoryDelete(supa.from('kill_items').delete().eq('id', item.id).select('id'), 'ลบไอเทมแล้ว');
      });
      return;
    }
    var db = e.target.closest('[data-del-boss]');
    if(db){
      var bid = db.dataset.delBoss;
      var sid = db.dataset.delServer || ''; // '' = การ์ดของรอบเก่าที่ไม่มีเซิร์ฟเวอร์เก็บไว้
      var who = db.dataset.delKiller; // ไม่มี = ทุกคน, 'none' = รอบที่ไม่รู้ว่าใครกด, อื่นๆ = uuid ของคนที่กำลังดูอยู่
      var ks = App.kills.filter(function(k){ return k.bossId===bid && (k.serverId||'')===sid && (who==null || (k.killedById||'none')===who); });
      if(!ks.length) return;
      var itemCount = ks.reduce(function(s,k){ return s+k.items.length; }, 0);
      var scopeText = who==null ? ' ทั้งหมด' : ' เฉพาะรอบที่ '+escapeHtml(killerNameOf(ks[0]))+' กด';
      showConfirm('ลบประวัติ '+escapeHtml(ks[0].bossName)+scopeText+' '+ks.length+' ครั้ง'+(itemCount ? ' พร้อมไอเทม '+itemCount+' ชิ้น (รวมข้อมูลหาร/ยอดขาย)' : '')+(who==null ? '' : ' (ของคนอื่นยังอยู่)')+'? ลบแล้วกู้คืนไม่ได้', function(){
        var q = supa.from('kills').delete().eq('host_id', activeOwnerId()).eq('boss_id', bid);
        q = sid ? q.eq('server_id', sid) : q.is('server_id', null);
        if(who==='none') q = q.is('killed_by', null); else if(who!=null) q = q.eq('killed_by', who);
        runHistoryDelete(q.select('id'), 'ลบประวัติบอสแล้ว');
      });
      return;
    }
    var f = e.target.closest('[data-loot-filter]');
    if(f){ lootFilter = f.dataset.lootFilter; renderHistory(); return; }
    var bk = e.target.closest('[data-boss-killer]');
    if(bk){ bossKillerFilter = bk.dataset.bossKiller; renderHistory(); return; }
    // เก็บไว้ = ไม่หาร ไม่ขาย (ยกเลิกได้ กลับเป็นรอแบ่ง) — ไม่ต้องยืนยันเพราะย้อนกลับได้
    var kp = e.target.closest('[data-keep]');
    if(kp){ updateKillItem(kp.dataset.keep, { kept_at:new Date().toISOString() }); return; }
    var ku = e.target.closest('[data-keep-undo]');
    if(ku){ updateKillItem(ku.dataset.keepUndo, { kept_at:null }); return; }
    var sh = e.target.closest('[data-share-toggle]');
    if(sh){
      var it = findKillItem(sh.dataset.shareToggle);
      if(!it) return;
      var arr = it.sharedWith.slice();
      var pos = arr.indexOf(sh.dataset.member);
      if(pos===-1) arr.push(sh.dataset.member); else arr.splice(pos,1);
      updateKillItem(it.id, { shared: arr.length>0, shared_with: arr });
      return;
    }
    var ed = e.target.closest('[data-sold-edit]');
    if(ed){ lootEditing = ed.dataset.soldEdit; renderHistory(); return; }
    var cl = e.target.closest('[data-sold-clear]');
    if(cl){ lootEditing = null; updateKillItem(cl.dataset.soldClear, { sold_amount:null, sold_at:null }); return; }
    var sv = e.target.closest('[data-sold-save]');
    if(sv){
      var id = sv.dataset.soldSave;
      var inp = document.querySelector('[data-sold-input="'+id+'"]');
      var cur = document.querySelector('[data-sold-currency="'+id+'"]');
      var amt = parseFloat((inp.value||'').replace(/,/g,''));
      if(!(amt>0)){ showFieldTip(inp, 'กรอกจำนวนที่ขายได้'); return; }
      lootEditing = null;
      updateKillItem(id, { sold_amount:amt, sold_currency:cur.value, sold_at:new Date().toISOString(), kept_at:null });
    }
  });
  // ใส่ , คั่นหลักพันให้ช่อง "ขายได้" ระหว่างพิมพ์ เช่น 100000 -> 100,000
  document.getElementById('historyList').addEventListener('input', function(e){
    if(!e.target.classList.contains('sold-amount')) return;
    e.target.value = formatDecimalDisplay(cleanDecimalInput(e.target.value));
  });
  document.getElementById('todayOnly').addEventListener('change', renderHistory);

  // ---------- merchant รับ/ขาย chart controls ----------
  document.getElementById('mrChartTimeframeSelect').addEventListener('change', function(e){
    mrChartTimeframe = e.target.value;
    renderMrChart();
  });
  document.getElementById('mrChartServerSelect').addEventListener('change', function(e){
    mrChartServerId = e.target.value;
    mrChartServerUserChanged = true;
    renderMrChart();
  });
  document.getElementById('mrChartCategoryToggle').addEventListener('click', function(e){
    var btn = e.target.closest('[data-categoryfilter]');
    if(!btn) return;
    mrChartCategoryFilter = btn.dataset.categoryfilter;
    document.querySelectorAll('#mrChartCategoryToggle .seg-btn').forEach(function(b){
      b.classList.toggle('active', b===btn);
    });
    renderMrChart();
  });
  document.getElementById('mrChartLegend').addEventListener('click', function(e){
    var btn = e.target.closest('[data-mr-chart-legend]');
    if(!btn) return;
    hiddenMrChartSeries[btn.dataset.mrChartLegend] = !hiddenMrChartSeries[btn.dataset.mrChartLegend];
    renderMrChart();
  });
  document.getElementById('mrSeriesChips').addEventListener('click', function(e){
    var btn = e.target.closest('[data-mr-legend-remove]');
    if(!btn) return;
    hiddenMrChartSeries[btn.dataset.mrLegendRemove] = true;
    renderMrChart();
  });
  document.getElementById('mrSeriesDropdown').addEventListener('click', function(e){
    var btn = e.target.closest('[data-mr-legend-add]');
    if(!btn) return;
    hiddenMrChartSeries[btn.dataset.mrLegendAdd] = false;
    renderMrChart();
    document.getElementById('mrSeriesDropdown').hidden = true;
  });
  document.getElementById('mrSeriesDropdownBtn').addEventListener('click', function(e){
    e.stopPropagation();
    var dd = document.getElementById('mrSeriesDropdown');
    dd.hidden = !dd.hidden;
  });
  document.addEventListener('click', function(e){
    if(!e.target.closest('#mrSeriesFilter')) document.getElementById('mrSeriesDropdown').hidden = true;
  });
  document.getElementById('mrChartSvg').addEventListener('mousemove', handleMrChartHover);
  document.getElementById('mrChartSvg').addEventListener('mouseleave', hideMrChartHover);

  // ---------- global error surfacing (helps diagnose issues we can't reproduce) ----------
  window.addEventListener('error', function(ev){
    console.error('Unhandled error', ev.error || ev.message);
    try{ toast('เกิดข้อผิดพลาด: '+(ev.message||'unknown')); }catch(e){}
  });

  // ---------- boot ----------
  loadCatalog();
  loadItemImages();
  var serversReady = loadServers().then(function(){
    // dropdown เซิร์ฟเวอร์ในฟอร์มสมัคร (เลือก 1 ตอนสมัคร เพิ่มทีหลังได้ที่ตั้งค่า)
    var sel = document.getElementById('rg-server');
    sel.innerHTML = '<option value="">— เลือกเซิร์ฟเวอร์ —</option>'+SERVER_RATES.filter(function(s){ return s.active; }).map(function(s){ return '<option value="'+escapeHtml(s.id)+'">'+escapeHtml(s.name)+'</option>'; }).join('');
  });
  supa.auth.getSession().then(function(res){
    var session = res.data && res.data.session;
    if(session) enterApp(session.user); else enterGuestPreview();
  });
  setInterval(function(){ tickTimers(); updateClock(); tickTickerCountdowns(); }, 1000);
  // กระดานประกาศเป็นของร่วม — เช็คทุก 60 วิ เพื่อให้เห็นประกาศที่คนอื่นเพิ่งลง (โหลดจริงเฉพาะตอนมีอะไรเปลี่ยน)
  // ข้ามตอนซ่อนแท็บ และตอนอยู่หน้าอื่นที่ไม่มีกระดาน — กลับมาหน้าบัญชีนักลงทุนเมื่อไหร่เช็คให้ทันที
  setInterval(function(){
    if(App.session && !document.hidden) refreshAnnouncementsIfChanged();
  }, 60000);
  document.addEventListener('visibilitychange', function(){
    if(App.session && !document.hidden) refreshAnnouncementsIfChanged();
  });

  window.addEventListener('pageshow', function(){
    if(!App.session) return;
    var svSel = document.getElementById('historyServerFilter');
    if(svSel) svSel.value = historyState.serverId;
    renderMerchantHistory();
  });
})();
