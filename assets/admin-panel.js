/* ============================================================
 โค้ดหน้าแอดมิน (ย้ายออกจาก assets/app.js แบบคำต่อคำ 2026-09-24)
 โหลดเฉพาะตอนแอดมินเปิดหน้าแอดมินครั้งแรก (ดู openAdminPage ใน app.js) — ผู้ใช้ทั่วไปไม่ต้องโหลดไฟล์นี้
 ของที่ใช้จาก app.js ส่งเข้ามาทาง ctx · SERVER_RATES อ่าน/เขียนผ่าน ctx.SERVER_RATES (getter/setter ตัวแปรเดียวกับ app.js)
 แก้ไฟล์นี้แล้วต้องเปลี่ยนเลข ?v= ใน import ของ openAdminPage (app.js) และเลข ?v= ของ app.js ใน index.html ด้วย
 ============================================================ */
export function initAdminPanel(ctx){
  var supa = ctx.supa, escapeHtml = ctx.escapeHtml, fmtNum = ctx.fmtNum, fmtDate = ctx.fmtDate, fmtDateTime = ctx.fmtDateTime,
      toast = ctx.toast, showConfirm = ctx.showConfirm, loadServers = ctx.loadServers,
      settingsPackageRows = ctx.settingsPackageRows, POINTS_REASON = ctx.POINTS_REASON;

  // ---------- แอดมิน: ตรวจสอบ/อนุมัติคำขอเติมเงิน ----------
  function renderAdminTopups(){
    var root = document.getElementById('adminTopupList');
    root.innerHTML = '<p class="admin-topup-empty">กำลังโหลด...</p>';
    supa.from('topup_requests')
      .select('id, amount_baht, points_added, slip_image_url, created_at, profiles!user_id(display_name)')
      .eq('status', 'pending')
      .order('created_at', { ascending: true })
      .then(function(res){
        if(res.error){ root.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</p>'; return; }
        var rows = res.data || [];
        adminBadgeState.slip = rows.length; updateAdminBadge();
        document.getElementById('adminSlipCount').textContent = rows.length ? '('+rows.length+')' : '';
        // แท็บสลิปเก่าโผล่เฉพาะเมื่อมีคำขอค้าง (ระบบสลิปปิดรับคำขอใหม่แล้ว) — ไม่มีก็ซ่อน แล้วถ้าเปิดค้างอยู่ให้กลับไปแท็บรายการ
        document.querySelector('#adminTabs [data-admin-tab="slip"]').hidden = !rows.length;
        if(!rows.length && !document.getElementById('adminSlipPanel').hidden) document.querySelector('#adminTabs [data-admin-tab="qr"]').click();
        if(!rows.length){ root.innerHTML = '<p class="admin-topup-empty">ไม่มีคำขอเติมเงินที่รออนุมัติ</p>'; return; }
        root.innerHTML = rows.map(function(r){
          var name = (r.profiles && r.profiles.display_name) || 'ไม่ทราบชื่อ';
          return '<div class="admin-topup-row" data-request-id="'+r.id+'">'+
            '<div class="admin-topup-main">'+
              '<div class="admin-topup-user">'+escapeHtml(name)+'</div>'+
              '<div class="admin-topup-meta">'+fmtNum(r.amount_baht)+' บ → +'+fmtNum(r.points_added)+' แต้ม • '+fmtDateTime(new Date(r.created_at).getTime())+'</div>'+
              '<a href="#" class="admin-topup-slip-link" data-slip-path="'+escapeHtml(r.slip_image_url)+'">ดูสลิป</a>'+
            '</div>'+
            '<div class="admin-topup-actions">'+
              '<button type="button" class="btn btn-ghost" data-approve-action="reject">ปฏิเสธ</button>'+
              '<button type="button" class="btn btn-primary" data-approve-action="approve">อนุมัติ</button>'+
            '</div>'+
          '</div>';
        }).join('');
      });
  }
  document.getElementById('adminTopupList').addEventListener('click', function(e){
    var slipLink = e.target.closest('.admin-topup-slip-link');
    if(slipLink){
      e.preventDefault();
      supa.storage.from('topup-slips').createSignedUrl(slipLink.dataset.slipPath, 3600).then(function(res){
        if(res.error){ toast('เปิดสลิปไม่สำเร็จ: '+res.error.message); return; }
        window.open(res.data.signedUrl, '_blank');
      });
      return;
    }
    var btn = e.target.closest('[data-approve-action]');
    if(!btn) return;
    var row = btn.closest('.admin-topup-row');
    var requestId = row.dataset.requestId;
    var approve = btn.dataset.approveAction === 'approve';
    row.querySelectorAll('.admin-topup-actions button').forEach(function(b){ b.disabled = true; });
    supa.rpc('approve_topup', { request_id: requestId, approve: approve }).then(function(res){
      if(res.error){ toast('ทำรายการไม่สำเร็จ: '+res.error.message); renderAdminTopups(); return; }
      toast(approve ? 'อนุมัติคำขอแล้ว' : 'ปฏิเสธคำขอแล้ว');
      renderAdminTopups();
    });
  });

  // ---------- แอดมิน: จัดการเติมเงิน (รายการ QR + เติมแต้มให้สมาชิกโดยตรง) ----------
  // ทุกการกระทำทำที่ฐานข้อมูลผ่านฟังก์ชัน admin_* (ตรวจสิทธิ์แอดมิน + ล็อกแถว + เติมครั้งเดียว) หน้านี้เป็นแค่ตัวสั่งงาน
  var ADMIN_TOPUP_STATUS = {
    credited:['สำเร็จ','ok'], reversed:['ยกเลิกแล้ว','expired'], pending:['รอชำระ','soon'], paid:['ชำระแล้ว รอเติมแต้ม','soon'],
    manual_review:['รอตรวจสอบ','soon'], expired:['หมดอายุ / ปิดแล้ว','expired'], failed:['ไม่สำเร็จ','expired']
  };
  // ช่องกรอง: "ต้องดำเนินการ" = รายการที่ยังรออยู่ (รอชำระ/ชำระแล้วรอเติม/รอตรวจสอบ) — เปิดหน้ามาเจอช่องนี้ก่อน
  var ADMIN_QR_FILTERS = [['attention','ต้องดำเนินการ'],['all','ทั้งหมด'],['pending','รอชำระ'],['manual_review','รอตรวจสอบ'],['credited','สำเร็จ'],['manual','แอดมินเติมให้'],['reversed','ยกเลิกแล้ว'],['expired','หมดอายุ / ปิดแล้ว'],['failed','ไม่สำเร็จ']];
  var ADMIN_QR_PAGE = 50;
  var ADMIN_QR_COLS = 'id, provider, ref1, provider_payment_id, requested_amount, received_amount, points, status, created_at, credited_at, profiles!user_id(display_name)';
  var adminBadgeState = { qr:0, slip:0 };
  var adminQrRows = [], adminQrTotal = 0, adminQrCounts = {}, adminQrFilter = 'attention', adminQrTerm = '', adminQrRange = 'all';
  var adminQrBusy = false, adminQrSeq = 0, adminQrSearchTimer = null;
  var adminGrantTarget = null, adminGrantBusy = false;

  function updateAdminBadge(){
    var n = adminBadgeState.qr + adminBadgeState.slip;
    var badge = document.getElementById('railAdminBadge');
    badge.hidden = !n; badge.textContent = n;
  }
  function adminAgeText(ts){
    var mins = Math.max(0, Math.floor((Date.now()-ts)/60000));
    if(mins < 60) return mins+' นาที';
    var hrs = Math.floor(mins/60);
    if(hrs < 48) return hrs+' ชม.';
    return Math.floor(hrs/24)+' วัน';
  }
  // แต้มที่จะเติมเมื่อกดยืนยัน = ยอดที่ TMWEASY แจ้งรับจริง (ถ้ามี) ไม่งั้นยอดที่ขอ (1 บาท = 1 แต้ม) ตรงกับฟังก์ชันฝั่งฐานข้อมูล
  function adminQrPoints(r){ return Math.floor(Number(r.received_amount!=null ? r.received_amount : r.requested_amount)); }
  function adminQrRowHtml(r){
    var isManual = r.provider==='manual';
    var st = isManual ? ['แอดมินเติมให้','ok'] : (ADMIN_TOPUP_STATUS[r.status] || [String(r.status),'neutral']);
    var name = (r.profiles && r.profiles.display_name) || 'ไม่ทราบชื่อ';
    var created = new Date(r.created_at).getTime();
    var req = Number(r.requested_amount);
    var recv = r.received_amount!=null ? Number(r.received_amount) : null;
    var m = (r.manual && typeof r.manual==='object') ? r.manual : null;
    var meta = fmtNum(req)+' บาท → +'+fmtNum(adminQrPoints(r))+' แต้ม • '+fmtDateTime(created);
    // "ค้างมา" แสดงเฉพาะรายการที่ยังรออยู่จริง (รายการที่ปิดแล้ว/หมดอายุ/ไม่สำเร็จ ไม่ต้องบอกว่าค้าง)
    if(r.status==='pending' || r.status==='paid' || r.status==='manual_review') meta += ' • ค้างมา '+adminAgeText(created);
    var refs = isManual ? '' : 'อ้างอิง '+String(r.ref1||'').slice(0,8)+(r.provider_payment_id ? ' • id_pay '+r.provider_payment_id : '');
    var notes = '';
    if(!isManual && recv!=null && recv!==req) notes += '<div class="admin-topup-meta admin-topup-warn">TMWEASY แจ้งรับเงินจริง '+fmtNum(recv)+' บาท ไม่ตรงกับยอดที่ขอ '+fmtNum(req)+' บาท</div>';
    if(m){
      var act = ({grant:'แอดมินเติมแต้มให้โดยตรง', confirm:'ยืนยันรับเงินโดยแอดมิน', close:'ปิดรายการโดยแอดมิน', reverse:'ยกเลิกรายการโดยแอดมิน (หักแต้มคืน)'})[m.action] || 'แอดมินดำเนินการ';
      notes += '<div class="admin-topup-meta">'+act+' • '+fmtDateTime(new Date(m.at).getTime())+(m.note ? ' • หมายเหตุ: '+escapeHtml(m.note) : '')+'</div>';
    } else if(r.status==='credited' && r.credited_at){
      notes += '<div class="admin-topup-meta">เติมแต้มอัตโนมัติ • '+fmtDateTime(new Date(r.credited_at).getTime())+'</div>';
    }
    var canReverse = r.status==='credited';
    var canConfirm = !isManual && ['pending','paid','manual_review','expired','failed'].indexOf(r.status)!==-1;
    var canClose = !isManual && (r.status==='pending' || r.status==='manual_review');
    return '<div class="admin-topup-row" data-tx-id="'+escapeHtml(r.id)+'">'+
      '<div class="admin-topup-main">'+
        '<div class="admin-topup-user">'+escapeHtml(name)+'<span class="membership-pill '+st[1]+'">'+escapeHtml(st[0])+'</span></div>'+
        '<div class="admin-topup-meta">'+meta+'</div>'+
        (refs ? '<div class="admin-topup-meta">'+escapeHtml(refs)+'</div>' : '')+
        notes+
      '</div>'+
      ((canConfirm || canClose || canReverse) ? '<div class="admin-topup-actions">'+
        (canReverse ? '<button type="button" class="btn btn-ghost" data-admin-qr-act="reverse">ยกเลิกรายการ</button>' : '')+
        (canClose ? '<button type="button" class="btn btn-ghost" data-admin-qr-act="close">ปิดรายการ</button>' : '')+
        (canConfirm ? '<button type="button" class="btn btn-primary" data-admin-qr-act="confirm">ยืนยันรับเงิน</button>' : '')+
      '</div>' : '')+
    '</div>';
  }

  // ---- ดึงรายการจากฐานข้อมูลทีละ 50 แถว (ไม่จำกัดจำนวนรวม) พร้อมค้นหา/ช่วงเวลา/ตัวเลขนับของแต่ละช่องกรอง ----
  function adminQrSinceIso(){
    if(adminQrRange==='today'){ var d = new Date(); d.setHours(0,0,0,0); return d.toISOString(); }
    if(adminQrRange==='7' || adminQrRange==='30') return new Date(Date.now()-Number(adminQrRange)*864e5).toISOString();
    return null;
  }
  // ค้นหา: ชื่อสมาชิก (ค้นตารางโปรไฟล์ก่อนแล้วเอา id มาใช้) หรือรหัสอ้างอิง / id_pay — ตัดอักขระที่ทำให้เงื่อนไขพัง
  function adminQrSearchClause(term){
    var t = String(term||'').replace(/[,()*%\\"']/g,' ').trim();
    if(!t) return Promise.resolve(null);
    return supa.from('profiles').select('id').ilike('display_name','%'+t+'%').limit(50).then(function(res){
      var ids = (!res.error && res.data ? res.data : []).map(function(p){ return p.id; });
      var parts = ['ref1.ilike.*'+t+'*', 'provider_payment_id.ilike.*'+t+'*'];
      if(ids.length) parts.push('user_id.in.('+ids.join(',')+')');
      return parts.join(',');
    });
  }
  // ใส่เงื่อนไขของช่องกรอง + ช่วงเวลา + คำค้น ลงใน query (ใช้ทั้งตอนดึงรายการและตอนนับจำนวนของแต่ละช่อง)
  function adminQrApply(q, filter, since, clause){
    if(filter==='attention') q = q.in('status', ['pending','paid','manual_review']).neq('provider','manual');
    else if(filter==='manual') q = q.eq('provider','manual');
    else if(filter!=='all') q = q.eq('status', filter).neq('provider','manual');
    if(since) q = q.gte('created_at', since);
    if(clause) q = q.or(clause);
    return q;
  }
  function paintAdminQr(){
    document.getElementById('adminQrFilter').innerHTML = ADMIN_QR_FILTERS.map(function(f){
      var n = adminQrCounts[f[0]];
      return '<button type="button" class="admin-qr-chip'+(adminQrFilter===f[0]?' active':'')+'" data-admin-qr-filter="'+f[0]+'">'+f[1]+' ('+(n==null ? '-' : fmtNum(n))+')</button>';
    }).join('');
    var root = document.getElementById('adminQrList');
    var moreWrap = document.getElementById('adminQrMoreWrap');
    document.getElementById('adminQrSummary').textContent = adminQrTotal ? 'แสดง '+fmtNum(adminQrRows.length)+' จาก '+fmtNum(adminQrTotal)+' รายการ' : '';
    if(!adminQrRows.length){
      root.innerHTML = '<p class="admin-topup-empty">'+(adminQrFilter==='attention' && !adminQrTerm && adminQrRange==='all' ? 'ไม่มีรายการที่ต้องดำเนินการ' : 'ไม่มีรายการตามเงื่อนไขนี้')+'</p>';
      moreWrap.hidden = true; return;
    }
    root.innerHTML = adminQrRows.map(adminQrRowHtml).join('');
    moreWrap.hidden = adminQrRows.length >= adminQrTotal;
  }
  function refreshAdminQrBadge(){
    supa.from('topup_transactions').select('id', { count:'exact', head:true }).eq('status','manual_review').then(function(r){
      adminBadgeState.qr = r.error ? 0 : (r.count || 0);
      updateAdminBadge();
    });
  }
  // append=true → ดึงชุดถัดไปต่อท้าย (ปุ่ม "ดูเพิ่ม") · ไม่ใส่ → โหลดใหม่ตั้งแต่ต้นตามช่องกรอง/คำค้น/ช่วงเวลาปัจจุบัน
  function loadAdminQr(append){
    var seq = ++adminQrSeq;   // ถ้าระหว่างรอมีการเปลี่ยนช่องกรองอีก ผลของรอบเก่าจะถูกทิ้ง
    var root = document.getElementById('adminQrList');
    if(!append){ adminQrRows = []; root.innerHTML = '<p class="admin-topup-empty">กำลังโหลด...</p>'; refreshAdminQrBadge(); }
    var since = adminQrSinceIso();
    var offset = append ? adminQrRows.length : 0;
    adminQrSearchClause(adminQrTerm).then(function(clause){
      // "ต้องดำเนินการ" เรียงเก่าสุดก่อน (ค้างนานสุดอยู่บนสุด) ช่องอื่นเรียงใหม่สุดก่อน
      var list = adminQrApply(supa.from('topup_transactions').select(ADMIN_QR_COLS, { count:'exact' }), adminQrFilter, since, clause)
        .order('created_at', { ascending: adminQrFilter==='attention' }).range(offset, offset+ADMIN_QR_PAGE-1);
      var counts = append ? Promise.resolve(null) : Promise.all(ADMIN_QR_FILTERS.map(function(f){
        return adminQrApply(supa.from('topup_transactions').select('id', { count:'exact', head:true }), f[0], since, clause)
          .then(function(r){ return r.error ? null : r.count; });
      }));
      return Promise.all([list, counts]);
    }).then(function(rs){
      if(seq !== adminQrSeq) return;
      var res = rs[0];
      if(res.error){ root.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</p>'; return; }
      var fresh = res.data || [];
      adminQrRows = append ? adminQrRows.concat(fresh) : fresh;
      adminQrTotal = res.count!=null ? res.count : adminQrRows.length;
      if(rs[1]){ adminQrCounts = {}; ADMIN_QR_FILTERS.forEach(function(f, i){ adminQrCounts[f[0]] = rs[1][i]; }); }
      paintAdminQr();
      adminQrAttachLogs(fresh);
    }).catch(function(err){
      if(seq === adminQrSeq) root.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(err && err.message || err)+'</p>';
    });
  }
  // บันทึกของแอดมิน (ใครทำอะไรกับรายการนี้ + หมายเหตุ) เก็บในตาราง topup_admin_log ที่สมาชิกอ่านไม่ได้ — ดึงมาแปะทีหลังรายการวาดเสร็จแล้ว
  function adminQrAttachLogs(rows){
    var ids = rows.map(function(r){ return r.id; });
    if(!ids.length) return;
    var seq = adminQrSeq;
    supa.from('topup_admin_log').select('transaction_id, action, points, note, created_at').in('transaction_id', ids)
      .order('created_at', { ascending:true }).then(function(res){
        if(res.error || seq !== adminQrSeq) return;   // ยังไม่มีตาราง/รอบเก่าไปแล้ว → แสดงต่อโดยไม่มีบันทึก
        var byTx = {};
        (res.data || []).forEach(function(l){ byTx[l.transaction_id] = { action:l.action, points:l.points, note:l.note, at:l.created_at }; });
        rows.forEach(function(r){ r.manual = byTx[r.id] || null; });
        paintAdminQr();
      });
  }
  function runAdminQrAction(fn, id, onDone, note){
    adminQrBusy = true;
    supa.rpc(fn, { p_transaction_id: id, p_note: note==null ? null : note }).then(function(res){
      adminQrBusy = false;
      if(res.error){ toast('ทำรายการไม่สำเร็จ: '+res.error.message); loadAdminQr(); return; }
      onDone(res);
      loadAdminQr();
      ctx.syncProfile();
    }).catch(function(err){ adminQrBusy = false; toast('ทำรายการไม่สำเร็จ: '+(err && err.message || err)); });
  }
  function openAdminPage(){ loadAdminQr(); renderAdminTopups(); }

  // ---------- แอดมิน: จัดการเซิร์ฟเวอร์ (เพิ่ม/ซ่อน-เปิดใช้/ลบ/จัดลำดับ) ----------
  // เขียนตาราง servers ตรงๆ ผ่าน supabase-js เลย (ไม่ผ่าน RPC) เพราะมี RLS "servers_admin_write"
  // (for all using is_admin()) อยู่แล้วในระบบ อนุญาตให้แอดมินเขียนได้เต็มที่โดยตรง
  function adminServerRowHtml(s, idx, total){
    return '<div class="admin-topup-row admin-server-row" draggable="true" data-server-id="'+escapeHtml(s.id)+'">'+
      '<span class="admin-server-drag-handle" title="ลากเพื่อจัดลำดับ">⠿</span>'+
      '<div style="flex:1;min-width:160px">'+
        '<b>'+escapeHtml(s.name)+'</b>'+
        '<div class="sub" style="font-size:.78rem;margin-top:.15rem">รหัส: '+escapeHtml(s.id)+'</div>'+
      '</div>'+
      '<div style="font-size:.82rem;color:var(--text-dim);flex:none">ซื้อ '+fmtNum(s.buy)+' / ขาย '+fmtNum(s.sell)+'</div>'+
      '<label style="display:flex;align-items:center;gap:.4rem;font-size:.82rem;flex:none">'+
        '<input type="checkbox" data-server-active'+(s.active?' checked':'')+'> เปิดใช้งาน'+
      '</label>'+
      '<div class="admin-topup-actions">'+
        '<button type="button" class="btn btn-ghost btn-sm" data-server-delete title="ลบเซิร์ฟเวอร์นี้">ลบ</button>'+
      '</div>'+
    '</div>';
  }
  function renderAdminServers(){
    var root = document.getElementById('adminServerList');
    if(!ctx.SERVER_RATES.length){ root.innerHTML = '<p class="admin-topup-empty">ยังไม่มีเซิร์ฟเวอร์ในระบบ</p>'; return; }
    root.innerHTML = ctx.SERVER_RATES.map(function(s, idx){ return adminServerRowHtml(s, idx, ctx.SERVER_RATES.length); }).join('');
  }
  document.getElementById('adminServerAddBtn').addEventListener('click', function(){
    var btn = document.getElementById('adminServerAddBtn');
    var errEl = document.getElementById('adminServerAddError');
    errEl.textContent = '';
    var id = document.getElementById('adminServerNewId').value.trim();
    var name = document.getElementById('adminServerNewName').value.trim();
    var buy = Number(document.getElementById('adminServerNewBuy').value.replace(/,/g,'')) || 0;
    var sell = Number(document.getElementById('adminServerNewSell').value.replace(/,/g,'')) || 0;
    if(!id || !name){ errEl.textContent = 'กรอกรหัสและชื่อให้ครบ'; return; }
    if(ctx.SERVER_RATES.some(function(s){ return s.id===id; })){ errEl.textContent = 'รหัสนี้มีอยู่แล้ว ตั้งรหัสใหม่'; return; }
    var nextSort = ctx.SERVER_RATES.reduce(function(m,s){ return Math.max(m, s.sortOrder||0); }, 0) + 1;
    btn.disabled = true;
    supa.from('servers').insert({ id:id, name:name, buy:buy, sell:sell, sort_order:nextSort, active:true }).then(function(res){
      btn.disabled = false;
      if(res.error){ errEl.textContent = 'เพิ่มไม่สำเร็จ: '+res.error.message; return; }
      document.getElementById('adminServerNewId').value = '';
      document.getElementById('adminServerNewName').value = '';
      document.getElementById('adminServerNewBuy').value = '';
      document.getElementById('adminServerNewSell').value = '';
      toast('เพิ่มเซิร์ฟเวอร์แล้ว');
      loadServers().then(renderAdminServers);
    });
  });
  // ลากสลับลำดับเซิร์ฟเวอร์ (HTML5 drag-and-drop ธรรมดา ไม่ใช้ไลบรารีเพิ่ม) — ลากแล้วปล่อย
  // คำนวณลำดับใหม่ทั้งชุดฝั่งหน้าเว็บก่อน (วาดใหม่ให้ลื่นไหลทันที) แล้วค่อยเขียน sort_order
  // ของทุกแถวใหม่ทั้งหมดเป็นเลขเรียงกัน (0,1,2,...) กันปัญหาเลขลำดับชนกัน/มีช่องว่าง
  var draggedServerId = null;
  var adminServerListEl = document.getElementById('adminServerList');
  adminServerListEl.addEventListener('dragstart', function(e){
    var row = e.target.closest('.admin-server-row');
    if(!row) return;
    draggedServerId = row.dataset.serverId;
    row.classList.add('dragging');
    if(e.dataTransfer) e.dataTransfer.effectAllowed = 'move';
  });
  adminServerListEl.addEventListener('dragend', function(e){
    var row = e.target.closest('.admin-server-row');
    if(row) row.classList.remove('dragging');
    adminServerListEl.querySelectorAll('.drag-over').forEach(function(r){ r.classList.remove('drag-over'); });
    draggedServerId = null;
  });
  adminServerListEl.addEventListener('dragover', function(e){
    var row = e.target.closest('.admin-server-row');
    if(!row || !draggedServerId || row.dataset.serverId===draggedServerId) return;
    e.preventDefault();
    if(e.dataTransfer) e.dataTransfer.dropEffect = 'move';
    adminServerListEl.querySelectorAll('.drag-over').forEach(function(r){ if(r!==row) r.classList.remove('drag-over'); });
    row.classList.add('drag-over');
  });
  adminServerListEl.addEventListener('drop', function(e){
    var row = e.target.closest('.admin-server-row');
    if(!row || !draggedServerId) return;
    e.preventDefault();
    row.classList.remove('drag-over');
    var targetId = row.dataset.serverId;
    if(targetId===draggedServerId) return;
    var fromIdx = ctx.SERVER_RATES.findIndex(function(s){ return s.id===draggedServerId; });
    var toIdx = ctx.SERVER_RATES.findIndex(function(s){ return s.id===targetId; });
    if(fromIdx===-1 || toIdx===-1) return;
    var reordered = ctx.SERVER_RATES.slice();
    var moved = reordered.splice(fromIdx, 1)[0];
    reordered.splice(toIdx, 0, moved);
    ctx.SERVER_RATES = reordered;
    renderAdminServers();
    Promise.all(reordered.map(function(s, i){ return supa.from('servers').update({ sort_order: i }).eq('id', s.id); })).then(function(results){
      var err = results.filter(function(r){ return r.error; })[0];
      if(err) toast('บันทึกลำดับไม่สำเร็จ: '+err.error.message);
      loadServers().then(renderAdminServers);
    });
  });
  document.getElementById('adminServerList').addEventListener('click', function(e){
    var delBtn = e.target.closest('[data-server-delete]');
    if(delBtn){
      var drow = delBtn.closest('[data-server-id]');
      var did = drow.dataset.serverId;
      var srv = ctx.SERVER_RATES.filter(function(s){ return s.id===did; })[0];
      showConfirm('ลบเซิร์ฟเวอร์ "'+escapeHtml(srv?srv.name:did)+'" ออกจากระบบถาวร? ข้อมูลเก่าที่เคยอ้างอิงเซิร์ฟนี้จะโชว์เป็นรหัสดิบแทนชื่อ กู้คืนไม่ได้ — แนะนำใช้ "ปิดใช้งาน" แทนถ้าเซิร์ฟนี้เคยมีคนเลือกใช้ไปแล้ว', function(){
        supa.from('servers').delete().eq('id', did).then(function(res){
          if(res.error){ toast('ลบไม่สำเร็จ: '+res.error.message); return; }
          toast('ลบเซิร์ฟเวอร์แล้ว');
          loadServers().then(renderAdminServers);
        });
      });
    }
  });
  document.getElementById('adminServerList').addEventListener('change', function(e){
    var chk = e.target.closest('[data-server-active]');
    if(!chk) return;
    var row = chk.closest('[data-server-id]');
    var id = row.dataset.serverId;
    chk.disabled = true;
    supa.from('servers').update({ active: chk.checked }).eq('id', id).then(function(res){
      if(res.error){ toast('บันทึกไม่สำเร็จ: '+res.error.message); chk.checked = !chk.checked; }
      chk.disabled = false;
      loadServers();
    });
  });

  // ---------- แอดมิน: โค้ดโปรโมชัน (สร้าง/ลบ — 1 โค้ดใช้ได้ตามจำนวนคนที่กำหนด ไม่ใช่สร้างหลายรหัส) ----------
  // เขียนตาราง promo_codes ตรงๆ ผ่าน RLS "admin เขียนได้เต็มที่" เหมือน servers — ฝั่งผู้ใช้แลกโค้ดผ่าน
  // RPC redeem_promo_code เท่านั้น (ดู migration 20260922001400_promo_codes.sql)
  var adminPromoCodes = [];
  var adminPromoType = 'points';
  document.getElementById('adminPromoTypeMode').addEventListener('click', function(e){
    var btn = e.target.closest('[data-promo-type]');
    if(!btn) return;
    adminPromoType = btn.dataset.promoType;
    document.querySelectorAll('#adminPromoTypeMode button').forEach(function(b){ b.classList.toggle('active', b===btn); });
    document.getElementById('adminPromoPoints').hidden = adminPromoType!=='points';
    document.getElementById('adminPromoPlanDays').hidden = adminPromoType!=='plan_days';
  });
  function adminPromoRowHtml(p){
    var expText = p.expires_at ? fmtDate(new Date(p.expires_at).getTime()) : 'ไม่หมดอายุ';
    var full = p.used_count >= p.max_uses;
    var rewardText = p.reward_type==='plan_days' ? ('แพ็กเกจ 4 in 1 '+fmtNum(p.plan_days)+' วัน/คน') : ('+'+fmtNum(p.points)+' แต้ม/คน');
    return '<div class="admin-topup-row" data-promo-code="'+escapeHtml(p.code)+'">'+
      '<div style="flex:1;min-width:160px">'+
        '<b>'+escapeHtml(p.code)+'</b>'+
        '<div class="sub" style="font-size:.78rem;margin-top:.15rem">'+rewardText+' · ใช้แล้ว '+fmtNum(p.used_count)+'/'+fmtNum(p.max_uses)+' · หมดอายุ: '+expText+(p.note?' · '+escapeHtml(p.note):'')+'</div>'+
        '<div data-promo-redeem-list hidden style="margin-top:.5rem;padding-top:.5rem;border-top:1px dashed var(--border)"></div>'+
      '</div>'+
      (full ? '<span class="membership-pill neutral">ใช้ครบแล้ว</span>' : '<span class="membership-pill ok">ใช้งานได้</span>')+
      '<div class="admin-topup-actions">'+
        (p.used_count > 0 ? '<button type="button" class="btn btn-ghost btn-sm" data-promo-view title="ดูว่าใครใช้โค้ดนี้ไปบ้าง">ดูผู้ใช้</button>' : '')+
        '<button type="button" class="btn btn-ghost btn-sm" data-promo-delete title="ลบโค้ดนี้">ลบ</button>'+
      '</div>'+
    '</div>';
  }
  function renderAdminPromoCodes(){
    var root = document.getElementById('adminPromoList');
    if(!adminPromoCodes.length){ root.innerHTML = '<p class="admin-topup-empty">ยังไม่มีโค้ดโปรโมชัน</p>'; return; }
    root.innerHTML = adminPromoCodes.map(adminPromoRowHtml).join('');
  }
  function loadAdminPromoCodes(){
    var root = document.getElementById('adminPromoList');
    root.innerHTML = '<p class="admin-topup-empty">กำลังโหลด...</p>';
    return supa.from('promo_codes').select('*').order('created_at', { ascending:false }).then(function(res){
      if(res.error){ root.innerHTML = '<p class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</p>'; return; }
      adminPromoCodes = res.data||[];
      renderAdminPromoCodes();
    });
  }
  document.getElementById('adminPromoAddBtn').addEventListener('click', function(){
    var btn = document.getElementById('adminPromoAddBtn');
    var errEl = document.getElementById('adminPromoAddError');
    errEl.textContent = '';
    var code = document.getElementById('adminPromoCode').value.trim().toUpperCase();
    var maxUses = parseInt(document.getElementById('adminPromoMaxUses').value.replace(/,/g,''), 10);
    var expDate = document.getElementById('adminPromoExpires').value;
    var note = document.getElementById('adminPromoNote').value.trim();
    if(!code){ errEl.textContent = 'กรอกรหัสโค้ด'; return; }
    if(!maxUses || maxUses<=0){ errEl.textContent = 'กรอกจำนวนคนใช้ได้ให้ถูกต้อง'; return; }
    var payload = { code:code, max_uses:maxUses, expires_at: expDate ? new Date(expDate+'T23:59:59').toISOString() : null, note:note||null, reward_type:adminPromoType };
    if(adminPromoType === 'plan_days'){
      var days = parseInt(document.getElementById('adminPromoPlanDays').value.replace(/,/g,''), 10);
      if(!days || days<=0){ errEl.textContent = 'กรอกจำนวนวันให้ถูกต้อง'; return; }
      payload.plan_days = days;
      payload.points = null;
    } else {
      var points = parseInt(document.getElementById('adminPromoPoints').value.replace(/,/g,''), 10);
      if(!points || points<=0){ errEl.textContent = 'กรอกจำนวนแต้มให้ถูกต้อง'; return; }
      payload.points = points;
      payload.plan_days = null;
    }
    btn.disabled = true;
    supa.from('promo_codes').insert(payload).then(function(res){
      btn.disabled = false;
      if(res.error){ errEl.textContent = 'สร้างไม่สำเร็จ: '+(res.error.code==='23505' ? 'มีโค้ดนี้อยู่แล้ว' : res.error.message); return; }
      document.getElementById('adminPromoCode').value = '';
      document.getElementById('adminPromoPoints').value = '';
      document.getElementById('adminPromoPlanDays').value = '';
      document.getElementById('adminPromoMaxUses').value = '';
      document.getElementById('adminPromoExpires').value = '';
      document.getElementById('adminPromoNote').value = '';
      toast('สร้างโค้ดแล้ว');
      loadAdminPromoCodes();
    });
  });
  document.getElementById('adminPromoList').addEventListener('click', function(e){
    var delBtn = e.target.closest('[data-promo-delete]');
    if(delBtn){
      var row = delBtn.closest('[data-promo-code]');
      var code = row.dataset.promoCode;
      showConfirm('ลบโค้ด "'+escapeHtml(code)+'" ออกจากระบบถาวร? คนที่ยังไม่ได้ใช้จะใช้โค้ดนี้ไม่ได้อีก กู้คืนไม่ได้', function(){
        supa.from('promo_codes').delete().eq('code', code).then(function(res){
          if(res.error){ toast('ลบไม่สำเร็จ: '+res.error.message); return; }
          toast('ลบโค้ดแล้ว');
          loadAdminPromoCodes();
        });
      });
      return;
    }
    var viewBtn = e.target.closest('[data-promo-view]');
    if(viewBtn){
      var row2 = viewBtn.closest('[data-promo-code]');
      var code2 = row2.dataset.promoCode;
      var listEl = row2.querySelector('[data-promo-redeem-list]');
      if(!listEl.hidden){ listEl.hidden = true; return; }
      listEl.hidden = false;
      listEl.innerHTML = '<div class="admin-topup-meta">กำลังโหลด...</div>';
      supa.rpc('admin_list_promo_redemptions', { p_code: code2 }).then(function(res){
        if(res.error){ listEl.innerHTML = '<div class="admin-topup-meta">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</div>'; return; }
        var rows = res.data || [];
        listEl.innerHTML = rows.length
          ? rows.map(function(r){
              return '<div class="admin-topup-meta">'+fmtDateTime(new Date(r.redeemed_at).getTime())+' · '+escapeHtml(r.display_name||'-')+' (@'+escapeHtml(r.username||'-')+') · '+escapeHtml(r.email||'-')+'</div>';
            }).join('')
          : '<div class="admin-topup-meta">ยังไม่มีคนใช้โค้ดนี้</div>';
      });
    }
  });

  // ---------- แอดมิน: รายชื่อสมาชิกทั้งหมด + แพ็กเกจ/วันหมดอายุ (ไล่ดูได้โดยไม่ต้องรู้ username ก่อน) ----------
  var adminMembersCache = [];
  function adminMemberRowHtml(m, idx){
    var plan = describeMemberPlans(m).replace(/<br>/g, ' · ');
    return '<tr>'+
      '<td class="at-idx">'+(idx+1)+'</td>'+
      '<td><b>'+escapeHtml(m.display_name||'-')+'</b></td>'+
      '<td class="sub">@'+escapeHtml(m.username||'-')+'</td>'+
      '<td class="sub">'+escapeHtml(m.email||'-')+'</td>'+
      '<td class="at-points">'+fmtNum(m.points||0)+'</td>'+
      '<td class="at-plan sub">'+plan+'</td>'+
    '</tr>';
  }
  function renderAdminMembers(){
    var root = document.getElementById('adminMembersList');
    var q = (document.getElementById('adminMembersSearch').value||'').trim().toLowerCase();
    var rows = adminMembersCache.filter(function(m){
      if(!q) return true;
      return (m.display_name||'').toLowerCase().indexOf(q)>=0 || (m.username||'').toLowerCase().indexOf(q)>=0;
    });
    document.getElementById('adminMembersSummary').textContent = 'ทั้งหมด '+fmtNum(adminMembersCache.length)+' คน'+(q ? ' · กรองเหลือ '+fmtNum(rows.length)+' คน' : '');
    root.innerHTML = rows.length ? rows.map(adminMemberRowHtml).join('') : '<tr><td colspan="6" class="admin-topup-empty">ไม่พบสมาชิก</td></tr>';
  }
  function loadAdminMembers(){
    var root = document.getElementById('adminMembersList');
    root.innerHTML = '<tr><td colspan="6" class="admin-topup-empty">กำลังโหลด...</td></tr>';
    return supa.rpc('admin_list_members').then(function(res){
      if(res.error){ root.innerHTML = '<tr><td colspan="6" class="admin-topup-empty">โหลดไม่สำเร็จ: '+escapeHtml(res.error.message)+'</td></tr>'; return; }
      adminMembersCache = res.data || [];
      renderAdminMembers();
    });
  }
  document.getElementById('adminMembersSearch').addEventListener('input', renderAdminMembers);

  document.getElementById('adminTabs').addEventListener('click', function(e){
    var btn = e.target.closest('[data-admin-tab]');
    if(!btn) return;
    var tab = btn.dataset.adminTab;
    document.querySelectorAll('#adminTabs button').forEach(function(b){ b.classList.toggle('active', b===btn); });
    document.getElementById('adminQrPanel').hidden = tab!=='qr';
    document.getElementById('adminGrantPanel').hidden = tab!=='grant';
    document.getElementById('adminServersPanel').hidden = tab!=='servers';
    document.getElementById('adminPromoPanel').hidden = tab!=='promo';
    document.getElementById('adminMembersPanel').hidden = tab!=='members';
    document.getElementById('adminSlipPanel').hidden = tab!=='slip';
    if(tab==='qr') loadAdminQr();
    if(tab==='slip') renderAdminTopups();
    if(tab==='promo') loadAdminPromoCodes();
    if(tab==='servers') loadServers().then(renderAdminServers);
    if(tab==='members') loadAdminMembers();
  });
  document.getElementById('adminQrFilter').addEventListener('click', function(e){
    var btn = e.target.closest('[data-admin-qr-filter]');
    if(!btn) return;
    adminQrFilter = btn.dataset.adminQrFilter; loadAdminQr();
  });
  document.getElementById('adminQrMore').addEventListener('click', function(){ loadAdminQr(true); });
  // ค้นหาชื่อ/รหัสอ้างอิง: พิมพ์แล้วรอ 0.4 วินาทีค่อยค้น (หรือกด Enter) · เปลี่ยนช่วงเวลาแล้วโหลดใหม่ทันที
  document.getElementById('adminQrSearch').addEventListener('input', function(){
    clearTimeout(adminQrSearchTimer);
    var v = this.value;
    adminQrSearchTimer = setTimeout(function(){ adminQrTerm = v.trim(); loadAdminQr(); }, 400);
  });
  document.getElementById('adminQrSearch').addEventListener('keydown', function(e){
    if(e.key!=='Enter') return;
    clearTimeout(adminQrSearchTimer); adminQrTerm = this.value.trim(); loadAdminQr();
  });
  document.getElementById('adminQrRange').addEventListener('change', function(){ adminQrRange = this.value; loadAdminQr(); });
  document.getElementById('adminQrList').addEventListener('click', function(e){
    var btn = e.target.closest('[data-admin-qr-act]');
    if(!btn || adminQrBusy) return;
    var id = btn.closest('.admin-topup-row').dataset.txId;
    var r = adminQrRows.filter(function(x){ return x.id===id; })[0];
    if(!r) return;
    var name = (r.profiles && r.profiles.display_name) || 'ไม่ทราบชื่อ';
    var req = Number(r.requested_amount), recv = r.received_amount!=null ? Number(r.received_amount) : null;
    if(btn.dataset.adminQrAct==='reverse'){
      showConfirm('<b>ยกเลิกรายการเติมเงิน</b> ของ "'+escapeHtml(name)+'" ยอด '+fmtNum(req)+' บาท?<br>จะ <b>หัก '+fmtNum(adminQrPoints(r))+' แต้ม</b> ออกจากสมาชิก (ถ้าสมาชิกใช้แต้มไปแล้วจนไม่พอ ระบบจะไม่ยอมหัก)<br>'+
        '<input type="text" id="adminReverseNote" maxlength="200" autocomplete="off" placeholder="หมายเหตุ (จำเป็น) เช่น โอนผิดยอด คืนเงินลูกค้าแล้ว" style="width:100%;margin-top:.7rem;padding:.55rem .7rem;border-radius:8px;border:1px solid var(--border);background:var(--surface-2);color:var(--text)">', function(){
        var note = ((document.getElementById('adminReverseNote') || {}).value || '').trim();
        if(note.length < 3){ toast('ต้องใส่หมายเหตุอย่างน้อย 3 ตัวอักษร กด "ยกเลิกรายการ" อีกครั้ง'); return; }
        runAdminQrAction('admin_reverse_topup', id, function(res){ toast('ยกเลิกรายการแล้ว หัก '+fmtNum(res.data.points)+' แต้ม'); }, note);
      });
    } else if(btn.dataset.adminQrAct==='confirm'){
      showConfirm('<b>ยืนยันรับเงิน</b> รายการของ "'+escapeHtml(name)+'"?<br>ยอดที่ขอ '+fmtNum(req)+' บาท'+(recv!=null && recv!==req ? '<br>ยอดที่ TMWEASY แจ้งรับจริง '+fmtNum(recv)+' บาท' : '')+
        '<br>จะเติมให้ <b>'+fmtNum(adminQrPoints(r))+' แต้ม</b><br><small>กดเฉพาะเมื่อตรวจยอดโอนเข้าบัญชีจริงแล้วเท่านั้น รายการหนึ่งเติมแต้มได้ครั้งเดียว</small>', function(){
        runAdminQrAction('admin_confirm_topup', id, function(res){ toast('เติม '+fmtNum(res.data.points)+' แต้มให้ '+name+' แล้ว'); });
      });
    } else {
      showConfirm('<b>ปิดรายการ</b> ของ "'+escapeHtml(name)+'" ยอด '+fmtNum(req)+' บาท โดยไม่เติมแต้ม?<br><small>ใช้เมื่อตรวจแล้วว่าไม่มียอดโอนเข้ามา ถ้าเงินเข้ามาทีหลังยังกด "ยืนยันรับเงิน" ย้อนหลังได้</small>', function(){
        runAdminQrAction('admin_close_topup', id, function(){ toast('ปิดรายการแล้ว'); });
      });
    }
  });

  // แปลผลแพ็กเกจของสมาชิกที่แอดมินค้นหาเจอ ใช้ตรรกะเดียวกับ settingsPackageRows() ที่หน้าตั้งค่าของยูเซอเอง
  function describeMemberPlans(d){
    if(d.legacy_unlimited) return 'บัญชีเก่า (ใช้งานได้ไม่จำกัดเวลา)';
    var rows = settingsPackageRows({
      plan_bundle_expires_at: d.plan_bundle_expires_at,
      plan_timers_expires_at: d.plan_timers_expires_at,
      feature_expiries: d.feature_expiries || {}
    }, Date.now());
    if(rows.length===1 && !rows[0].expiry) return 'ฟรี (ไม่มีแพ็กเกจ)';
    return rows.map(function(r){ return escapeHtml(r.name)+' หมดอายุ '+fmtDate(r.expiry); }).join('<br>');
  }
  // เติมแต้มให้สมาชิกโดยตรง (ลูกค้าโอนตรงผ่านเพจ FB): ค้นหาก่อน → เห็นชื่อ/แต้มปัจจุบัน → ใส่จำนวนกับหมายเหตุ → ยืนยัน
  function adminGrantFind(){
    var ident = document.getElementById('adminGrantIdent').value.trim();
    if(ident.length < 3){ toast('กรอก username หรืออีเมลอย่างน้อย 3 ตัวอักษร'); return; }
    if(adminGrantBusy) return;
    adminGrantBusy = true;
    supa.rpc('admin_find_member', { p_identifier: ident }).then(function(res){
      adminGrantBusy = false;
      var found = document.getElementById('adminGrantFound');
      if(res.error){ adminGrantTarget = null; found.hidden = true; toast(res.error.message); return; }
      adminGrantTarget = res.data;
      document.getElementById('adminGrantMember').innerHTML = '<b>'+escapeHtml(res.data.display_name||'-')+'</b> (@'+escapeHtml(res.data.username||'-')+')<br>'+escapeHtml(res.data.email||'')+'<br>แต้มคงเหลือตอนนี้ <b>'+fmtNum(res.data.points||0)+'</b><br>แพ็กเกจ: '+describeMemberPlans(res.data);
      document.getElementById('adminGrantPoints').value = '';
      document.getElementById('adminGrantNote').value = '';
      found.hidden = false;
      adminGrantSetMode('grant');
      adminGrantLoadRecent(res.data.id);
    }).catch(function(err){ adminGrantBusy = false; toast('ค้นหาไม่สำเร็จ: '+(err && err.message || err)); });
  }
  // โหมด "เติมแต้ม / หักแต้ม" และประวัติแต้มล่าสุดของสมาชิกที่เจอ (ไว้ตอบลูกค้าที่ถามว่าแต้มหายไปไหน)
  var adminGrantMode = 'grant';
  function adminGrantSetMode(mode){
    adminGrantMode = mode;
    document.querySelectorAll('#adminGrantMode button').forEach(function(b){ b.classList.toggle('active', b.dataset.grantMode===mode); });
    document.getElementById('adminGrantSubmit').textContent = mode==='deduct' ? 'หักแต้ม' : 'เติมแต้ม';
    document.getElementById('adminGrantPoints').placeholder = mode==='deduct' ? 'จำนวนแต้มที่จะหัก' : 'จำนวนแต้ม (1 บาท = 1 แต้ม)';
  }
  function adminGrantLoadRecent(userId){
    var box = document.getElementById('adminGrantRecent');
    box.innerHTML = '<div class="admin-topup-meta">กำลังโหลดความเคลื่อนไหวแต้ม...</div>';
    supa.from('points_ledger').select('delta, balance_after, reason, created_at').eq('user_id', userId)
      .order('created_at', { ascending:false }).limit(8).then(function(res){
        if(!adminGrantTarget || adminGrantTarget.id !== userId) return;
        if(res.error){ box.innerHTML = ''; return; }
        var rows = res.data || [];
        box.innerHTML = rows.length
          ? '<div class="admin-topup-meta"><b>ความเคลื่อนไหวแต้มล่าสุด</b></div>'+rows.map(function(r){
              return '<div class="admin-topup-meta">'+fmtDateTime(new Date(r.created_at).getTime())+' · '+escapeHtml(POINTS_REASON[r.reason] || POINTS_REASON.other)+' · <b style="color:var(--'+(r.delta>0 ? 'success' : 'danger')+')">'+(r.delta>0 ? '+' : '')+fmtNum(r.delta)+'</b> (คงเหลือ '+fmtNum(r.balance_after)+')</div>';
            }).join('')
          : '<div class="admin-topup-meta">ยังไม่มีบันทึกความเคลื่อนไหวแต้ม</div>';
      });
  }
  document.getElementById('adminGrantMode').addEventListener('click', function(e){
    var b = e.target.closest('[data-grant-mode]');
    if(b) adminGrantSetMode(b.dataset.grantMode);
  });
  document.getElementById('adminGrantFind').addEventListener('click', adminGrantFind);
  document.getElementById('adminGrantIdent').addEventListener('keydown', function(e){ if(e.key==='Enter') adminGrantFind(); });
  // แก้ช่องค้นหาแล้ว ต้องค้นใหม่ก่อนถึงจะเติมได้ (กันเติมผิดคน)
  document.getElementById('adminGrantIdent').addEventListener('input', function(){
    adminGrantTarget = null; document.getElementById('adminGrantFound').hidden = true;
  });
  document.getElementById('adminGrantSubmit').addEventListener('click', function(){
    if(!adminGrantTarget || adminGrantBusy) return;
    var raw = document.getElementById('adminGrantPoints').value.replace(/,/g,'').trim();
    var pts = /^\d+$/.test(raw) ? Number(raw) : NaN;
    var note = document.getElementById('adminGrantNote').value.trim();
    if(!(pts>=1 && pts<=100000)){ toast('จำนวนแต้มต้องเป็นเลขจำนวนเต็ม 1 - 100,000'); return; }
    if(note.length < 3){ toast('กรุณาใส่หมายเหตุอย่างน้อย 3 ตัวอักษร'); return; }
    var t = adminGrantTarget;
    var deduct = adminGrantMode==='deduct';
    showConfirm((deduct ? 'หัก' : 'เติม')+' <b>'+fmtNum(pts)+' แต้ม</b> '+(deduct ? 'ออกจาก' : 'ให้')+'<br><b>'+escapeHtml(t.display_name||'-')+'</b> (@'+escapeHtml(t.username||'-')+') ?<br><small>หมายเหตุ: '+escapeHtml(note)+'<br>'+(deduct ? 'ตรวจให้แน่ใจก่อนหักแต้มของสมาชิก (หักได้ไม่เกินแต้มคงเหลือ)' : 'เติมผิดแก้ได้ด้วยการหักแต้มภายหลัง แต่ตรวจยอดโอนให้ตรงก่อนกดยืนยัน')+'</small>', function(){
      adminGrantBusy = true;
      supa.rpc(deduct ? 'admin_deduct_points' : 'admin_grant_points', { p_user_id: t.id, p_points: pts, p_note: note }).then(function(res){
        adminGrantBusy = false;
        if(res.error){ toast('ทำรายการไม่สำเร็จ: '+res.error.message); return; }
        toast((deduct ? 'หัก ' : 'เติม ')+fmtNum(res.data.points)+' แต้ม'+(deduct ? 'จาก ' : 'ให้ ')+(t.display_name||'สมาชิก')+' แล้ว (คงเหลือ '+fmtNum(res.data.balance)+')');
        adminGrantTarget = null;
        document.getElementById('adminGrantFound').hidden = true;
        document.getElementById('adminGrantIdent').value = '';
        loadAdminQr();
        ctx.syncProfile();
      }).catch(function(err){ adminGrantBusy = false; toast('ทำรายการไม่สำเร็จ: '+(err && err.message || err)); });
    });
  });

  return { openAdminPage: openAdminPage };
}
