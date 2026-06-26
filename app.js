/* ═══════════════════════════════════════════════════════
   Aqari Plus Admin — لوحة إدارة منصة عقاري بلس
   Backend: https://aqari-backend.onrender.com/api
   Version: 2.0 — Full Fix (21 problem areas resolved)
   ═══════════════════════════════════════════════════════ */

const API = 'https://aqari-backend.onrender.com/api';

/* ── Session ─────────────────────────────────────────── */
const Session = {
  get token()  { return localStorage.getItem('aqari_admin_token'); },
  get role()   { return localStorage.getItem('aqari_admin_role'); },
  get name()   { return localStorage.getItem('aqari_admin_name'); },
  get phone()  { return localStorage.getItem('aqari_admin_phone'); },
  get perms()  {
    try { return JSON.parse(localStorage.getItem('aqari_admin_perms') || '[]'); }
    catch { return []; }
  },
  set(token, data) {
    localStorage.setItem('aqari_admin_token', token);
    localStorage.setItem('aqari_admin_role',  data.role || '');
    localStorage.setItem('aqari_admin_name',  data.name || data.full_name || data.phone || '');
    localStorage.setItem('aqari_admin_phone', data.phone || '');
    const perms = data.permissions || [];
    localStorage.setItem('aqari_admin_perms', JSON.stringify(Array.isArray(perms) ? perms : []));
  },
  clear() {
    ['aqari_admin_token','aqari_admin_role','aqari_admin_name','aqari_admin_phone','aqari_admin_perms']
      .forEach(k => localStorage.removeItem(k));
  },
  get isSuperAdmin() { return this.role === 'super_admin'; },
  get isAdmin()      { return this.role === 'admin'; },
  get isSupervisor() { return this.role === 'supervisor'; },
  hasPerm(p)  {
    if (this.isSuperAdmin || this.isAdmin) return true;
    return this.perms.includes(p);
  }
};

/* ── HTTP Helper ─────────────────────────────────────── */
async function api(method, path, body) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json' }
  };
  if (Session.token) opts.headers['Authorization'] = 'Bearer ' + Session.token;
  if (body)          opts.body = JSON.stringify(body);
  const res = await fetch(API + path, opts);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message || data.error || `HTTP ${res.status}`);
  return data;
}
const GET  = (path)       => api('GET', path);
const POST = (path, body) => api('POST', path, body);
const PUT  = (path, body) => api('PUT',  path, body);
const PATCH= (path, body) => api('PATCH', path, body);
const DEL  = (path)       => api('DELETE', path);

/* ── API with fallback endpoints ─────────────────────── */
async function apiWithFallback(endpoints) {
  for (const ep of endpoints) {
    try {
      const res = await fetch(API + ep, {
        headers: {
          'Content-Type': 'application/json',
          ...(Session.token ? { 'Authorization': 'Bearer ' + Session.token } : {})
        }
      });
      if (res.ok) {
        const data = await res.json().catch(() => ({}));
        return data;
      }
    } catch (e) { /* try next */ }
  }
  throw new Error('تعذر الوصول إلى البيانات. تحقق من الاتصال بالشبكة.');
}

/* ── Toast ───────────────────────────────────────────── */
function toast(msg, type = '') {
  let el = document.getElementById('toast-el');
  if (!el) {
    el = document.createElement('div');
    el.id = 'toast-el';
    el.className = 'toast';
    document.body.appendChild(el);
  }
  el.textContent = msg;
  el.className = 'toast show ' + type;
  clearTimeout(el._t);
  el._t = setTimeout(() => { el.className = 'toast'; }, 3500);
}

/* ── Login Flow ──────────────────────────────────────── */
let otpSent = false;
let sentPhone = '';

async function sendOtp() {
  const phone = document.getElementById('phone-input').value.trim();
  if (!phone || phone.replace(/\D/g,'').length < 9) {
    showLoginError('أدخل رقم هاتف صحيح (9 أرقام على الأقل)');
    return;
  }
  setLoginLoading('send-otp', true);
  clearLoginMessages();
  try {
    await POST('/auth/send-otp', { phone });
    otpSent = true;
    sentPhone = phone;
    const otpGroup = document.getElementById('otp-group');
    otpGroup.style.opacity = '1';
    otpGroup.style.pointerEvents = 'auto';
    document.getElementById('otp-helper').textContent = '';
    showLoginStatus('✅ تم إرسال رمز التحقق إلى رقم الجوال.');
  } catch(e) {
    showLoginError(e.message || 'تعذر إرسال رمز التحقق');
  }
  setLoginLoading('send-otp', false);
}

async function login() {
  if (!otpSent) { showLoginError('أرسل رمز التحقق أولاً'); return; }
  const phone = document.getElementById('phone-input').value.trim();
  const otp   = document.getElementById('otp-input').value.trim();
  if (!otp) { showLoginError('أدخل رمز التحقق'); return; }
  setLoginLoading('login', true);
  clearLoginMessages();
  try {
    const res = await POST('/auth/verify-otp', { phone, otp });
    const role = res.user?.role || res.userData?.role || res.role || '';
    if (!['admin','super_admin','supervisor'].includes(role)) {
      throw new Error('هذا الحساب لا يمتلك صلاحيات الإدارة.');
    }
    const token    = res.token || res.access_token || '';
    const userData = res.user || res.userData || {};
    Session.set(token, { ...userData, role });
    initAdminPanel();
  } catch(e) {
    showLoginError(e.message || 'تعذر تسجيل الدخول');
  }
  setLoginLoading('login', false);
}

function showLoginStatus(msg) {
  const el = document.getElementById('login-status');
  el.textContent = msg; el.classList.remove('hidden');
}
function showLoginError(msg) {
  const el = document.getElementById('login-error');
  el.textContent = msg; el.classList.remove('hidden');
}
function clearLoginMessages() {
  document.getElementById('login-status').classList.add('hidden');
  document.getElementById('login-error').classList.add('hidden');
}
function setLoginLoading(which, loading) {
  if (which === 'send-otp') {
    document.getElementById('send-otp-text').classList.toggle('hidden', loading);
    document.getElementById('send-otp-spinner').classList.toggle('hidden', !loading);
    document.getElementById('send-otp-btn').disabled = loading;
  } else {
    document.getElementById('login-text').classList.toggle('hidden', loading);
    document.getElementById('login-spinner').classList.toggle('hidden', !loading);
    document.getElementById('login-btn').disabled = loading;
  }
}

function logout() {
  Session.clear();
  document.getElementById('admin-panel').classList.add('hidden');
  document.getElementById('login-screen').classList.remove('hidden');
  otpSent = false;
  document.getElementById('phone-input').value = '';
  document.getElementById('otp-input').value = '';
  document.getElementById('otp-group').style.opacity = '0.5';
  document.getElementById('otp-group').style.pointerEvents = 'none';
  clearLoginMessages();
}

/* ── Sidebar Nav Items ───────────────────────────────── */
const ALL_NAV = [
  { label:'لوحة التحكم',          route:'dashboard',            perm: null,                   icon:'📊' },
  { label:'العقارات',              route:'properties',           perm:'manage_properties',     icon:'🏠' },
  { label:'العقارات المميزة',      route:'featured-properties',  perm:'manage_properties',     icon:'⭐' },
  { label:'الملاك',                route:'owners',               perm:'manage_users',          icon:'👤' },
  { label:'المكاتب العقارية',      route:'offices',              perm:'manage_users',          icon:'🏢' },
  { label:'الباحثون',              route:'seekers',              perm:'manage_users',          icon:'🔍' },
  { label:'طلبات الباحثين',        route:'seeker-requests',      perm:'manage_requests',       icon:'📋' },
  { label:'المشرفون والصلاحيات',   route:'supervisors',          perm:'manage_users',          icon:'👮' },
  { label:'الباقات',               route:'packages',             perm:'manage_subscriptions',  icon:'📦' },
  { label:'الباقات والاشتراكات',   route:'subscriptions',        perm:'manage_subscriptions',  icon:'🌟' },
  { label:'المدفوعات',             route:'payments',             perm:'manage_subscriptions',  icon:'💰' },
  { label:'مراجعة المدفوعات',      route:'payment-reviews',      perm:'manage_subscriptions',  icon:'💳' },
  { label:'طلبات التوثيق',         route:'verifications',        perm:'manage_users',          icon:'✅' },
  { label:'إدارة الموظفين',        route:'all-employees',        perm:'manage_employees',      icon:'👔' },
  { label:'الإشعارات',             route:'notifications',        perm:'manage_settings',       icon:'🔔' },
  { label:'إدارة المحادثات',       route:'chats-management',     perm:'manage_requests',       icon:'💬' },
  { label:'البلاغات والشكاوى',     route:'complaints',           perm:'manage_requests',       icon:'🚩' },
  { label:'الرسائل والدعم',        route:'messages-support',     perm:'manage_requests',       icon:'📩' },
  { label:'التقييمات',             route:'ratings',              perm:'manage_settings',       icon:'⭐' },
  { label:'إدارة المحتوى',         route:'content-pages',        perm:'manage_content',        icon:'📄' },
  { label:'التقارير والإحصائيات',  route:'reports',              perm:'manage_reports',        icon:'📈' },
  { label:'سجل الأنشطة',           route:'activity-logs',        perm:'manage_settings',       icon:'📜' },
  { label:'الإعدادات',             route:'settings',             perm:'manage_settings',       icon:'⚙️' },
  { label:'المواقع الجغرافية',     route:'locations',            perm:'manage_cities',         icon:'📍' },
  { label:'أنواع العقارات',        route:'property-types',       perm:'manage_settings',       icon:'🏗️' },
  { label:'مراقبة النظام',         route:'monitoring',           perm:'manage_settings',       icon:'🖥️' },
  { label:'الإعلانات',             route:'ads',                  perm:'manage_ads',            icon:'📣' },
  { label:'النسخ الاحتياطي',       route:'backup',               perm:'manage_settings',       icon:'💾' },
  { label:'إدارة الأمان',          route:'security',             perm:'manage_security',       icon:'🔒' },
  { label:'مركز الطوارئ',          route:'emergency',            perm:'manage_settings',       icon:'🚨' },
  { label:'إعدادات التطبيق',       route:'app-config',           perm:'manage_settings',       icon:'🔧' },
  { label:'إدارة التحديثات',       route:'app-updates',          perm:'manage_settings',       icon:'📱' },
  { label:'دليل الاستخدام',         route:'user-guide',           perm: null,                   icon:'📖' },
];

/* ── Init Panel ──────────────────────────────────────── */
function initAdminPanel() {
  document.getElementById('login-screen').classList.add('hidden');
  document.getElementById('admin-panel').classList.remove('hidden');

  // User info in sidebar
  const name  = Session.name  || Session.phone || 'مستخدم';
  const phone = Session.phone || '';
  const role  = Session.role  || '';
  document.getElementById('sidebar-user-name').textContent  = name;
  document.getElementById('sidebar-user-phone').textContent = phone;
  document.getElementById('sidebar-avatar').textContent     = name.charAt(0).toUpperCase();

  const roleLabel = { super_admin:'مدير النظام', admin:'أدمن', supervisor:'مشرف' };
  document.getElementById('sidebar-role-badge').textContent = roleLabel[role] || role;

  // Build sidebar nav
  const nav = document.getElementById('sidebar-nav');
  nav.innerHTML = '';
  ALL_NAV.forEach(item => {
    if (item.perm && !Session.hasPerm(item.perm)) return;
    const el = document.createElement('a');
    el.className = 'nav-item';
    el.dataset.route = item.route;
    el.href = '#' + item.route;
    el.innerHTML = `<span>${item.icon}</span><span>${item.label}</span><span class="nav-dot hidden"></span>`;
    el.addEventListener('click', e => {
      e.preventDefault();
      navigateTo(item.route);
      closeSidebar();
    });
    nav.appendChild(el);
  });

  navigateTo('dashboard');
}

/* ── Router ──────────────────────────────────────────── */
let currentRoute = '';
function navigateTo(route) {
  currentRoute = route;
  document.querySelectorAll('.nav-item').forEach(el => {
    const isActive = el.dataset.route === route;
    el.classList.toggle('active', isActive);
    el.querySelector('.nav-dot')?.classList.toggle('hidden', !isActive);
  });
  const main = document.getElementById('main-content');
  const pages = {
    'dashboard':            renderDashboard,
    'properties':           renderProperties,
    'featured-properties':  renderFeaturedProperties,
    'owners':               () => renderUsersTable('owners'),
    'offices':              () => renderUsersTable('offices'),
    'seekers':              () => renderUsersTable('seekers'),
    'seeker-requests':      renderSeekerRequests,
    'supervisors':          renderSupervisors,
    'packages':             renderPackages,
    'subscriptions':        renderSubscriptions,
    'payments':             renderPayments,
    'payment-reviews':      renderPaymentReviews,
    'verifications':        renderVerifications,
    'all-employees':        renderAllEmployees,
    'notifications':        renderNotifications,
    'chats-management':     renderChats,
    'complaints':           renderComplaints,
    'messages-support':     renderMessagesSupport,
    'ratings':              renderRatings,
    'content-pages':        renderContentPages,
    'reports':              renderReports,
    'activity-logs':        renderActivityLogs,
    'settings':             renderSettings,
    'locations':            renderLocations,
    'property-types':       renderPropertyTypes,
    'monitoring':           renderMonitoring,
    'ads':                  renderAds,
    'backup':               renderBackup,
    'security':             renderSecurity,
    'emergency':            renderEmergency,
    'app-config':           renderAppConfig,
    'app-updates':          renderAppUpdates,
    'user-guide':           renderUserGuide,
  };
  if (pages[route]) {
    main.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>جاري التحميل...</p></div>`;
    pages[route]();
  } else {
    main.innerHTML = pageHeader('الصفحة غير موجودة', '') +
      `<div class="card"><p style="text-align:center;padding:40px;color:#6B7280">لم يتم العثور على الصفحة المطلوبة.</p></div>`;
  }
}

/* ── Helpers ─────────────────────────────────────────── */
function pageHeader(title, subtitle, actions = '') {
  return `<div class="page-header">
    <div class="page-header-text"><h2>${title}</h2>${subtitle?`<p>${subtitle}</p>`:''}</div>
    <div class="page-header-actions">${actions}</div>
  </div>`;
}
function loadingHtml() {
  return `<div class="loading-state"><div class="spinner"></div><p>جاري التحميل...</p></div>`;
}
function emptyHtml(icon, title, msg='') {
  return `<div class="empty-state"><div class="empty-icon">${icon}</div><h3>${title}</h3>${msg?`<p>${msg}</p>`:''}</div>`;
}
function errorHtml(msg, retry='') {
  return `<div class="empty-state"><div class="empty-icon">⚠️</div><h3>خطأ</h3><p>${msg}</p>${retry?`<br><button class="btn-action btn-view" onclick="${retry}">إعادة المحاولة</button>`:''}</div>`;
}
function badgeForStatus(status) {
  const map = {
    active:'badge-green', approved:'badge-green', verified:'badge-green', open:'badge-green',
    pending:'badge-yellow', pending_review:'badge-yellow', under_review:'badge-yellow',
    rejected:'badge-red', inactive:'badge-red', closed:'badge-red', suspended:'badge-red',
    featured:'badge-purple',
    deactivated:'badge-gray', draft:'badge-gray',
  };
  const labelMap = {
    active:'نشط', approved:'مقبول', verified:'موثق', pending:'معلق',
    pending_review:'قيد المراجعة', under_review:'تحت المراجعة', rejected:'مرفوض',
    inactive:'غير نشط', featured:'مميز', deactivated:'محذوف', draft:'مسودة',
    open:'مفتوح', closed:'مغلق', suspended:'موقوف',
  };
  const cls = map[status] || 'badge-gray';
  const label = labelMap[status] || status || '—';
  return `<span class="badge ${cls}">${label}</span>`;
}
function fmtDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('ar-SA', { year:'numeric', month:'short', day:'numeric' });
}
function fmtNum(n) {
  if (n == null || n === '') return '—';
  return Number(n).toLocaleString('ar');
}

/* helper: safe encode for onclick attrs */
function safeEncode(str) {
  return encodeURIComponent(str || '');
}

/* ── Image Viewer Modal ─────────────────────────────── */
function openImageModal(urls) {
  const imgArr = Array.isArray(urls) ? urls : [urls];
  const validUrls = imgArr.filter(u => u && typeof u === 'string' && u.startsWith('http'));
  if (!validUrls.length) { toast('لا توجد صور للعرض','error'); return; }
  let idx = 0;
  const renderImg = () => `
    <div style="text-align:center">
      <img src="${validUrls[idx]}" alt="صورة ${idx+1}"
        style="max-width:100%;max-height:65vh;border-radius:12px;object-fit:contain;background:#111"
        onerror="this.src='https://via.placeholder.com/400x300?text=لا+توجد+صورة'">
      <p style="margin-top:8px;color:#888;font-size:13px">${idx+1} / ${validUrls.length}</p>
    </div>`;
  const update = () => {
    document.getElementById('img-modal-body').innerHTML = renderImg();
    document.getElementById('img-prev').disabled = idx === 0;
    document.getElementById('img-next').disabled = idx === validUrls.length - 1;
  };

  openModal('عرض الصور',
    `<div id="img-modal-body">${renderImg()}</div>
    <div style="display:flex;gap:10px;justify-content:center;margin-top:12px">
      <button id="img-prev" class="btn-action btn-view btn-sm" onclick="imgNav(-1)" ${idx===0?'disabled':''}>❮ السابق</button>
      <button id="img-next" class="btn-action btn-approve btn-sm" onclick="imgNav(1)" ${idx===validUrls.length-1?'disabled':''}>التالي ❯</button>
    </div>`,
    null
  );
  window._imgUrls = validUrls;
  window._imgIdx = 0;
}
function imgNav(dir) {
  const urls = window._imgUrls || [];
  window._imgIdx = Math.max(0, Math.min(urls.length - 1, window._imgIdx + dir));
  const idx = window._imgIdx;
  document.getElementById('img-modal-body').innerHTML = `
    <div style="text-align:center">
      <img src="${urls[idx]}" alt="صورة ${idx+1}"
        style="max-width:100%;max-height:65vh;border-radius:12px;object-fit:contain;background:#111"
        onerror="this.src='https://via.placeholder.com/400x300?text=لا+توجد+صورة'">
      <p style="margin-top:8px;color:#888;font-size:13px">${idx+1} / ${urls.length}</p>
    </div>`;
  document.getElementById('img-prev').disabled = idx === 0;
  document.getElementById('img-next').disabled = idx === urls.length - 1;
}

/* ══════════════════════════════════════════════════════
   PAGE: DASHBOARD
══════════════════════════════════════════════════════ */
async function renderDashboard() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/stats');
    const s = data;
    const cards = [
      { icon:'🏠', label:'إجمالي العقارات',  value: fmtNum(s.totalProperties||s.total_properties),      color:'#C59D50' },
      { icon:'✅', label:'العقارات النشطة',    value: fmtNum(s.activeProperties||s.active_properties),    color:'#5C8A3C' },
      { icon:'⏳', label:'بانتظار المراجعة',  value: fmtNum(s.pendingProperties||s.pending_properties),   color:'#B8860B' },
      { icon:'⭐', label:'العقارات المميزة',   value: fmtNum(s.featuredProperties||s.featured_properties), color:'#C59D50' },
      { icon:'🔑', label:'المؤجرة',           value: fmtNum(s.rentedProperties||s.rented_properties),     color:'#7B5E3C' },
      { icon:'💰', label:'المُباعة',          value: fmtNum(s.soldProperties||s.sold_properties),         color:'#8B5E3C' },
      { icon:'👤', label:'الملاك',            value: fmtNum((s.users_by_role||{}).owner||s.ownersCount||s.owners_count||0),   color:'#5C3A1E' },
      { icon:'🏢', label:'المكاتب',           value: fmtNum((s.users_by_role||{}).office||s.officesCount||s.offices_count||0),color:'#3A230F' },
      { icon:'🔍', label:'الباحثون',          value: fmtNum((s.users_by_role||{}).seeker||s.seekersCount||s.seekers_count||0),color:'#C59D50' },
      { icon:'👮', label:'المشرفون',          value: fmtNum(s.supervisorsCount||s.supervisors_count||0),   color:'#3A230F' },
    ];
    const grid = cards.map(c => `
      <div class="stat-card">
        <div class="stat-icon" style="background:${c.color}18">${c.icon}</div>
        <div class="stat-value">${c.value||'0'}</div>
        <div class="stat-label">${c.label}</div>
      </div>`).join('');
    main.innerHTML = pageHeader('لوحة التحكم','نظرة مباشرة على مؤشرات الأداء.',
      `<button class="btn-white" onclick="renderDashboard()">🔄 تحديث</button>`) +
      `<div class="stats-grid">${grid}</div>`;
  } catch(e) {
    main.innerHTML = pageHeader('لوحة التحكم','') +
      `<div class="card">${errorHtml(e.message,'renderDashboard')}</div>`;
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: PROPERTIES — FIXED with images, detail view, full actions
══════════════════════════════════════════════════════ */
async function renderProperties() {
  const main = document.getElementById('main-content');
  const perm = Session.hasPerm('manage_properties');
  try {
    const data = await GET('/admin/properties');
    let rows = data.properties || data.data || data || [];
    if (!Array.isArray(rows)) rows = [];

    const thead = `<tr>
      <th>الصورة</th><th>العنوان</th><th>النوع</th><th>المدينة</th>
      <th>السعر</th><th>الحالة</th><th>التاريخ</th><th>الإجراءات</th>
    </tr>`;

    const tbody = rows.length
      ? rows.map(p => {
          const imgs = p.images || p.photos || [];
          const firstImg = Array.isArray(imgs) && imgs.length
            ? (typeof imgs[0] === 'string' ? imgs[0] : imgs[0]?.url || imgs[0]?.path || '')
            : (p.image || p.thumbnail || p.cover_image || '');
          const thumbHtml = firstImg
            ? `<img src="${firstImg}" alt="صورة" class="prop-thumb" onclick="openImageModal(${JSON.stringify(Array.isArray(imgs)?imgs.map(i=>typeof i==='string'?i:i?.url||i?.path||''):[firstImg]).replace(/"/g,"'")})" style="cursor:pointer">`
            : `<div class="prop-thumb-empty">🏠</div>`;
          const isFeatured = p.is_featured || p.featured || p.status === 'featured';
          const actBtns = perm ? `
            <div class="action-btns-wrap">
              <button class="btn-action btn-view btn-sm" onclick="viewPropertyDetail(${p.id})">عرض</button>
              <button class="btn-action btn-approve btn-sm" onclick="approveProperty(${p.id})">قبول</button>
              <button class="btn-action btn-reject btn-sm" onclick="rejectProperty(${p.id})">رفض</button>
              ${isFeatured
                ? `<button class="btn-action btn-warn btn-sm" onclick="unfeatureProperty(${p.id})">إلغاء التمييز</button>`
                : `<button class="btn-action btn-gold btn-sm" onclick="featureProperty(${p.id})">تمييز ⭐</button>`}
              <button class="btn-action btn-delete btn-sm" onclick="deleteProperty(${p.id})">حذف</button>
            </div>` : '—';
          return `<tr>
            <td data-label="الصورة">${thumbHtml}</td>
            <td data-label="العنوان"><strong>${p.title||p.property_type||'عقار'}</strong></td>
            <td data-label="النوع">${p.property_type||'—'}<br><small style="color:#888">${p.operation_type||p.offer_type||''}</small></td>
            <td data-label="المدينة">${p.city||'—'}</td>
            <td data-label="السعر">${fmtNum(p.price)}${p.currency?' '+p.currency:''}</td>
            <td data-label="الحالة">${badgeForStatus(p.status)}</td>
            <td data-label="التاريخ">${fmtDate(p.created_at)}</td>
            <td data-label="الإجراءات" class="actions-cell">${actBtns}</td>
          </tr>`;
        }).join('')
      : `<tr><td colspan="8" class="empty-cell">${emptyHtml('🏠','لا توجد عقارات')}</td></tr>`;

    main.innerHTML = pageHeader('العقارات','إدارة ومراجعة جميع العقارات.',
      `<button class="btn-white" onclick="renderProperties()">🔄 تحديث</button>`) +
      `<div class="card">
        <div class="table-container">
          <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
        </div>
        <p style="padding:12px 16px 0;color:#6B7280;font-size:13px">إجمالي: ${rows.length} عقار</p>
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader('العقارات','') +
      `<div class="card">${errorHtml(e.message,'renderProperties')}</div>`;
  }
}

async function viewPropertyDetail(id) {
  try {
    const data = await GET(`/admin/properties/${id}`);
    const p = data.property || data.data || data;
    const imgs = p.images || p.photos || [];
    const imgList = Array.isArray(imgs)
      ? imgs.map(i => typeof i === 'string' ? i : (i?.url || i?.path || '')).filter(Boolean)
      : [];
    const galleryHtml = imgList.length
      ? `<div class="img-gallery">
          ${imgList.map((u,i) => `<img src="${u}" class="gallery-img" onclick="openImageModal(${JSON.stringify(imgList).replace(/"/g,"'")})" alt="صورة ${i+1}">`).join('')}
        </div>`
      : '<p style="color:#888;text-align:center;padding:12px">لا توجد صور لهذا العقار</p>';

    openModal(`تفاصيل العقار #${id}`, `
      ${galleryHtml}
      <div class="detail-grid">
        <div class="detail-item"><span class="detail-label">العنوان</span><span class="detail-val">${p.title||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">النوع</span><span class="detail-val">${p.property_type||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">العملية</span><span class="detail-val">${p.operation_type||p.offer_type||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">المدينة</span><span class="detail-val">${p.city||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">السعر</span><span class="detail-val">${fmtNum(p.price)} ${p.currency||''}</span></div>
        <div class="detail-item"><span class="detail-label">المساحة</span><span class="detail-val">${p.area||p.size||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">الغرف</span><span class="detail-val">${p.rooms||p.bedrooms||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">الحالة</span><span class="detail-val">${badgeForStatus(p.status)}</span></div>
        <div class="detail-item"><span class="detail-label">المالك</span><span class="detail-val">${p.owner_name||p.user_name||p.owner_id||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">تاريخ الإضافة</span><span class="detail-val">${fmtDate(p.created_at)}</span></div>
      </div>
      ${p.description ? `<div style="margin-top:12px"><strong>الوصف:</strong><p style="margin-top:6px;line-height:1.7;color:#555">${p.description}</p></div>` : ''}
    `, null);
  } catch(e) {
    toast('تعذر تحميل تفاصيل العقار: ' + e.message, 'error');
  }
}

/* ── Property Actions ─────────────────────────────────── */
async function approveProperty(id) {
  if (!confirm('هل تريد الموافقة على هذا العقار؟')) return;
  try {
    await PATCH(`/admin/properties/${id}/status`, { status:'approved' });
    toast('تمت الموافقة على العقار ✅','success');
    renderProperties();
  } catch(e) { toast(e.message,'error'); }
}
async function rejectProperty(id) {
  const reason = prompt('سبب الرفض (اختياري):');
  if (reason === null) return;
  try {
    await PATCH(`/admin/properties/${id}/status`, { status:'rejected', rejection_reason:reason });
    toast('تم رفض العقار','success');
    renderProperties();
  } catch(e) { toast(e.message,'error'); }
}
async function deleteProperty(id) {
  if (!confirm('هل تريد حذف هذا العقار نهائياً؟')) return;
  try {
    await DEL(`/admin/properties/${id}`);
    toast('تم حذف العقار','success');
    renderProperties();
  } catch(e) { toast(e.message,'error'); }
}
async function featureProperty(id) {
  if (!confirm('تمييز هذا العقار كعقار مميز؟')) return;
  try {
    await PATCH(`/admin/properties/${id}/featured`, { featured: true });
    toast('تم تمييز العقار ⭐','success');
    renderProperties();
  } catch(e) {
    try {
      await POST(`/admin/properties/${id}/feature`, {});
      toast('تم تمييز العقار ⭐','success');
      renderProperties();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function unfeatureProperty(id) {
  if (!confirm('إلغاء تمييز هذا العقار؟')) return;
  try {
    await PATCH(`/admin/properties/${id}/featured`, { featured: false });
    toast('تم إلغاء التمييز','success');
    renderProperties();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: FEATURED PROPERTIES
══════════════════════════════════════════════════════ */
async function renderFeaturedProperties() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/properties/featured');
    const list = data.properties || data.data || data || [];
    const rows = Array.isArray(list) ? list.map(p => {
      const imgs = p.images || p.photos || [];
      const firstImg = Array.isArray(imgs) && imgs.length
        ? (typeof imgs[0] === 'string' ? imgs[0] : imgs[0]?.url || '')
        : (p.image || p.thumbnail || '');
      const thumbHtml = firstImg
        ? `<img src="${firstImg}" alt="صورة" class="prop-thumb" style="cursor:pointer" onclick="openImageModal(['${firstImg}'])">`
        : `<div class="prop-thumb-empty">🏠</div>`;
      return `<tr>
        <td data-label="الصورة">${thumbHtml}</td>
        <td data-label="#"><strong>#${p.id||'-'}</strong></td>
        <td data-label="العقار">${p.title||p.name||'-'}</td>
        <td data-label="المالك">${p.owner_name||p.user_name||'-'}</td>
        <td data-label="السعر">${p.price?fmtNum(p.price):'-'} ${p.currency||''}</td>
        <td data-label="الحالة"><span class="badge badge-purple">مميّز ⭐</span></td>
        <td data-label="إجراء" class="actions-cell"><div class="action-btns">
          <button class="btn-action btn-view btn-sm" onclick="viewPropertyDetail(${p.id})">عرض</button>
          <button class="btn-action btn-delete btn-sm" onclick="removeFeatured(${p.id})">إلغاء التمييز</button>
        </div></td>
      </tr>`;
    }).join('') : '';
    main.innerHTML = pageHeader('العقارات المميزة','العقارات المعروضة بشكل مميز في التطبيق.',
      `<button class="btn-white" onclick="renderFeaturedProperties()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead><tr><th>الصورة</th><th>#</th><th>العقار</th><th>المالك</th><th>السعر</th><th>الحالة</th><th>إجراء</th></tr></thead>
        <tbody>${rows || `<tr><td colspan="7" class="empty-cell">${emptyHtml('⭐','لا توجد عقارات مميزة')}</td></tr>`}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('العقارات المميزة','') + `<div class="card">${errorHtml(e.message,'renderFeaturedProperties')}</div>`;
  }
}
async function removeFeatured(id) {
  if (!confirm('إلغاء تمييز هذا العقار؟')) return;
  try {
    await PATCH(`/admin/properties/${id}/featured`, { featured: false });
    toast('تم إلغاء التمييز','success'); renderFeaturedProperties();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   USERS TABLE — Owners / Offices / Seekers (FIXED with full actions & profile modal)
══════════════════════════════════════════════════════ */
const PAGE_CFG = {
  owners: {
    title:'الملاك', subtitle:'إدارة حسابات الملاك.', endpoint:'/admin/users?role=owner',
    cols: ['الصورة','الاسم','الهاتف','الحالة','العقارات','تاريخ التسجيل','الإجراءات'],
    row: (p) => {
      const photo = p.profile_photo || p.avatar || p.photo || '';
      const thumb = photo
        ? `<img src="${photo}" class="user-thumb" onclick="openImageModal(['${photo}'])" style="cursor:pointer">`
        : `<div class="user-thumb-empty">👤</div>`;
      return [
        thumb,
        `<strong>${p.name||p.full_name||'—'}</strong>`,
        p.phone||'—',
        badgeForStatus(p.status||'active'),
        fmtNum(p.properties_count||0),
        fmtDate(p.created_at),
        `<div class="user-actions-menu">
          <button class="btn-action btn-view btn-sm" onclick="viewUserProfile('owner',${p.id})">الملف الشخصي</button>
          <div class="dropdown-wrap">
            <button class="btn-action btn-more btn-sm" onclick="toggleDropdown(this)">⋮ المزيد</button>
            <div class="dropdown-menu">
              ${p.status==='suspended'
                ? `<button onclick="activateUser(${p.id},'owner')">✅ تفعيل الحساب</button>`
                : `<button onclick="suspendUser(${p.id},'owner')">🚫 إيقاف الحساب</button>`}
              <button onclick="rejectUser(${p.id},'owner')">❌ رفض الحساب</button>
              <button onclick="deleteUser(${p.id},'owner')" style="color:#dc2626">🗑 حذف نهائي</button>
            </div>
          </div>
        </div>`
      ];
    }
  },
  offices: {
    title:'المكاتب العقارية', subtitle:'إدارة حسابات المكاتب.', endpoint:'/admin/users?role=office',
    cols: ['الصورة','الاسم','الهاتف','الحالة','الموظفون','تاريخ التسجيل','الإجراءات'],
    row: (p) => {
      const photo = p.profile_photo || p.office_logo || p.avatar || p.photo || '';
      const thumb = photo
        ? `<img src="${photo}" class="user-thumb" onclick="openImageModal(['${photo}'])" style="cursor:pointer">`
        : `<div class="user-thumb-empty">🏢</div>`;
      const isVerified = p.is_verified || p.verified || p.status === 'verified';
      return [
        thumb,
        `<strong>${p.name||p.full_name||p.office_name||'—'}</strong>`,
        p.phone||'—',
        badgeForStatus(p.status||'active'),
        fmtNum(p.employees_count||0),
        fmtDate(p.created_at),
        `<div class="user-actions-menu">
          <button class="btn-action btn-view btn-sm" onclick="viewUserProfile('office',${p.id})">الملف الشخصي</button>
          <div class="dropdown-wrap">
            <button class="btn-action btn-more btn-sm" onclick="toggleDropdown(this)">⋮ المزيد</button>
            <div class="dropdown-menu">
              ${isVerified
                ? `<button onclick="unverifyOffice(${p.id})">🔓 إلغاء التوثيق</button>`
                : `<button onclick="verifyOffice(${p.id})">✅ توثيق المكتب</button>`}
              ${p.status==='suspended'
                ? `<button onclick="activateUser(${p.id},'office')">✅ تفعيل الحساب</button>`
                : `<button onclick="suspendUser(${p.id},'office')">🚫 إيقاف الحساب</button>`}
              <button onclick="deleteUser(${p.id},'office')" style="color:#dc2626">🗑 حذف نهائي</button>
            </div>
          </div>
        </div>`
      ];
    }
  },
  seekers: {
    title:'الباحثون', subtitle:'إدارة حسابات الباحثين.', endpoint:'/admin/users?role=seeker',
    cols: ['الصورة','الاسم','الهاتف','الحالة','تاريخ التسجيل','الإجراءات'],
    row: (p) => {
      const photo = p.profile_photo || p.avatar || p.photo || '';
      const thumb = photo
        ? `<img src="${photo}" class="user-thumb" onclick="openImageModal(['${photo}'])" style="cursor:pointer">`
        : `<div class="user-thumb-empty">🔍</div>`;
      return [
        thumb,
        `<strong>${p.name||p.full_name||'—'}</strong>`,
        p.phone||'—',
        badgeForStatus(p.status||'active'),
        fmtDate(p.created_at),
        `<div class="user-actions-menu">
          <button class="btn-action btn-view btn-sm" onclick="viewUserProfile('seeker',${p.id})">الملف الشخصي</button>
          <div class="dropdown-wrap">
            <button class="btn-action btn-more btn-sm" onclick="toggleDropdown(this)">⋮ المزيد</button>
            <div class="dropdown-menu">
              <button onclick="approveUser(${p.id},'seeker')">✅ قبول الحساب</button>
              <button onclick="rejectUser(${p.id},'seeker')">❌ رفض الحساب</button>
              ${p.status==='suspended'
                ? `<button onclick="activateUser(${p.id},'seeker')">🔄 إعادة تفعيل</button>`
                : `<button onclick="suspendUser(${p.id},'seeker')">🚫 إيقاف الحساب</button>`}
              <button onclick="deleteUser(${p.id},'seeker')" style="color:#dc2626">🗑 حذف نهائي</button>
            </div>
          </div>
        </div>`
      ];
    }
  },
};

function toggleDropdown(btn) {
  const menu = btn.nextElementSibling;
  // Close all other dropdowns
  document.querySelectorAll('.dropdown-menu.open').forEach(m => {
    if (m !== menu) m.classList.remove('open');
  });
  menu.classList.toggle('open');
  // Close when clicking outside
  setTimeout(() => {
    document.addEventListener('click', function handler(e) {
      if (!btn.contains(e.target) && !menu.contains(e.target)) {
        menu.classList.remove('open');
        document.removeEventListener('click', handler);
      }
    });
  }, 10);
}

async function renderUsersTable(type) {
  const main = document.getElementById('main-content');
  const cfg  = PAGE_CFG[type];
  try {
    let data = await GET(cfg.endpoint);
    let rows = data[type]||data.users||data.data||data||[];
    if (!Array.isArray(rows)) rows = [];

    const thead = `<tr>${cfg.cols.map(c=>`<th>${c}</th>`).join('')}</tr>`;
    const tbody = rows.length
      ? rows.map(r => {
          const cells = cfg.row(r);
          return `<tr>${cells.map((c,i) => {
            const isLast = i === cells.length - 1;
            const cellClass = isLast ? ' class="actions-cell"' : '';
            return `<td data-label="${cfg.cols[i]||''}"${cellClass}>${c}</td>`;
          }).join('')}</tr>`;
        }).join('')
      : `<tr><td colspan="${cfg.cols.length}" class="empty-cell">${emptyHtml('📂','لا توجد بيانات')}</td></tr>`;

    main.innerHTML = pageHeader(cfg.title, cfg.subtitle,
      `<button class="btn-white" onclick="renderUsersTable('${type}')">🔄 تحديث</button>`) +
      `<div class="card">
        <div class="table-container">
          <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
        </div>
        <p style="padding:12px 16px 0;color:#6B7280;font-size:13px">إجمالي: ${rows.length} سجل</p>
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader(cfg.title,'') +
      `<div class="card">${errorHtml(e.message,`()=>renderUsersTable('${type}')`)}</div>`;
  }
}

/* ── User Profile Modal ─────────────────────────────── */
async function viewUserProfile(type, id) {
  try {
    const data = await GET(`/admin/users/${id}`);
    const u = data.user || data.data || data;

    const photo = u.profile_photo || u.avatar || u.photo || u.office_logo || '';
    const idFront = u.id_front || u.national_id_front || u.id_photo_front || u.id_image || '';
    const idBack  = u.id_back  || u.national_id_back  || u.id_photo_back  || '';
    const commReg = u.commercial_registration || u.commercial_reg || u.cr_photo || '';

    const allIdPhotos = [idFront, idBack, commReg].filter(Boolean);

    const photoHtml = photo
      ? `<div style="text-align:center;margin-bottom:16px">
          <img src="${photo}" alt="صورة الحساب" style="width:100px;height:100px;border-radius:50%;object-fit:cover;border:3px solid var(--gold);cursor:pointer"
               onclick="openImageModal(['${photo}'])">
        </div>`
      : `<div style="text-align:center;margin-bottom:16px">
          <div style="width:100px;height:100px;border-radius:50%;background:var(--beige-mid);display:inline-flex;align-items:center;justify-content:center;font-size:40px">
            ${type==='office'?'🏢':type==='seeker'?'🔍':'👤'}
          </div>
        </div>`;

    const idPhotosHtml = allIdPhotos.length
      ? `<div style="margin-top:12px">
          <strong>صور الهوية والوثائق:</strong>
          <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px">
            ${allIdPhotos.map((url,i) => `<img src="${url}" alt="وثيقة ${i+1}"
              style="width:120px;height:80px;object-fit:cover;border-radius:8px;border:1px solid #ddd;cursor:pointer"
              onclick="openImageModal(${JSON.stringify(allIdPhotos).replace(/"/g,"'")})">`).join('')}
          </div>
        </div>`
      : '';

    openModal(`الملف الشخصي — ${u.name || u.full_name || '#'+id}`, `
      ${photoHtml}
      <div class="detail-grid">
        <div class="detail-item"><span class="detail-label">الاسم</span><span class="detail-val">${u.name||u.full_name||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">الهاتف</span><span class="detail-val">${u.phone||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">البريد</span><span class="detail-val">${u.email||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">الحالة</span><span class="detail-val">${badgeForStatus(u.status||'active')}</span></div>
        <div class="detail-item"><span class="detail-label">الدور</span><span class="detail-val">${u.role||type}</span></div>
        ${type==='office' ? `
        <div class="detail-item"><span class="detail-label">اسم المكتب</span><span class="detail-val">${u.office_name||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">التوثيق</span><span class="detail-val">${u.is_verified||u.verified ? '<span class="badge badge-green">موثق ✅</span>' : '<span class="badge badge-gray">غير موثق</span>'}</span></div>
        ` : ''}
        <div class="detail-item"><span class="detail-label">تاريخ التسجيل</span><span class="detail-val">${fmtDate(u.created_at)}</span></div>
        ${u.properties_count != null ? `<div class="detail-item"><span class="detail-label">العقارات</span><span class="detail-val">${fmtNum(u.properties_count)}</span></div>` : ''}
      </div>
      ${idPhotosHtml}
    `, null);
  } catch(e) {
    toast('تعذر تحميل الملف الشخصي: ' + e.message,'error');
  }
}

/* ── User Actions ─────────────────────────────────────── */
async function suspendUser(id, type) {
  if (!confirm('هل تريد إيقاف هذا الحساب؟')) return;
  try {
    await PATCH(`/admin/users/${id}/status`, { status:'suspended' });
    toast('تم إيقاف الحساب','success');
    renderUsersTable(type);
  } catch(e) {
    try {
      await PUT(`/admin/users/${id}`, { status:'suspended' });
      toast('تم إيقاف الحساب','success');
      renderUsersTable(type);
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function activateUser(id, type) {
  if (!confirm('هل تريد إعادة تفعيل هذا الحساب؟')) return;
  try {
    await PATCH(`/admin/users/${id}/status`, { status:'active' });
    toast('تم تفعيل الحساب ✅','success');
    renderUsersTable(type);
  } catch(e) {
    try {
      await PUT(`/admin/users/${id}`, { status:'active' });
      toast('تم تفعيل الحساب ✅','success');
      renderUsersTable(type);
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function approveUser(id, type) {
  if (!confirm('هل تريد قبول هذا الحساب؟')) return;
  try {
    await PATCH(`/admin/users/${id}/status`, { status:'approved' });
    toast('تم قبول الحساب ✅','success');
    renderUsersTable(type);
  } catch(e) { toast(e.message,'error'); }
}
async function rejectUser(id, type) {
  const reason = prompt('سبب الرفض (اختياري):');
  if (reason === null) return;
  try {
    await PATCH(`/admin/users/${id}/status`, { status:'rejected', reason });
    toast('تم رفض الحساب','success');
    renderUsersTable(type);
  } catch(e) { toast(e.message,'error'); }
}
async function deleteUser(id, type) {
  if (!confirm('هل تريد حذف هذا الحساب نهائياً؟ لا يمكن التراجع عن هذا الإجراء.')) return;
  try {
    await DEL(`/admin/users/${id}`);
    toast('تم حذف الحساب','success');
    renderUsersTable(type);
  } catch(e) { toast(e.message,'error'); }
}
async function verifyOffice(id) {
  if (!confirm('هل تريد توثيق هذا المكتب؟')) return;
  try {
    await PATCH(`/admin/users/${id}/verify`, { verified: true });
    toast('تم توثيق المكتب ✅','success');
    renderUsersTable('offices');
  } catch(e) {
    try {
      await PUT(`/admin/offices/${id}/verify`, {});
      toast('تم توثيق المكتب ✅','success');
      renderUsersTable('offices');
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function unverifyOffice(id) {
  if (!confirm('هل تريد إلغاء توثيق هذا المكتب؟')) return;
  try {
    await PATCH(`/admin/users/${id}/verify`, { verified: false });
    toast('تم إلغاء التوثيق','success');
    renderUsersTable('offices');
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: SEEKER REQUESTS
══════════════════════════════════════════════════════ */
async function renderSeekerRequests() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/requests');
    const rows = data.requests||data.data||[];
    const thead = `<tr><th>رقم الطلب</th><th>الباحث</th><th>المدينة</th><th>النوع</th><th>الميزانية</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td data-label="رقم الطلب">${r.id}</td>
          <td data-label="الباحث">${r.user_name||r.seeker_name||r.phone||'—'}</td>
          <td data-label="المدينة">${r.city||'—'}</td>
          <td data-label="النوع">${r.property_type||'—'}</td>
          <td data-label="الميزانية">${fmtNum(r.budget)||fmtNum(r.max_price)||'—'}</td>
          <td data-label="الحالة">${badgeForStatus(r.status||'active')}</td>
          <td data-label="التاريخ">${fmtDate(r.created_at)}</td>
          <td data-label="إجراءات" class="actions-cell"><div class="action-btns"><button class="btn-action btn-delete btn-sm" onclick="deleteRequest(${r.id})">حذف</button></div></td>
        </tr>`).join('')
      : `<tr><td colspan="8" class="empty-cell">${emptyHtml('📋','لا توجد طلبات')}</td></tr>`;
    main.innerHTML = pageHeader('طلبات الباحثين','جميع طلبات البحث عن العقارات.',
      `<button class="btn-white" onclick="renderSeekerRequests()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('طلبات الباحثين','') +
      `<div class="card">${errorHtml(e.message,'renderSeekerRequests')}</div>`;
  }
}
async function deleteRequest(id) {
  if (!confirm('حذف هذا الطلب؟')) return;
  try {
    await DEL(`/admin/requests/${id}`);
    toast('تم حذف الطلب','success');
    renderSeekerRequests();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: SUPERVISORS — FIXED with 11 permissions
══════════════════════════════════════════════════════ */
const PERM_LABELS = {
  manage_properties:   'إدارة العقارات',
  manage_users:        'إدارة المستخدمين',
  manage_subscriptions:'إدارة الاشتراكات',
  manage_requests:     'إدارة الطلبات',
  manage_settings:     'إدارة الإعدادات',
  manage_employees:    'إدارة الموظفين',
  manage_cities:       'إدارة المدن',
  manage_ads:          'إدارة الإعلانات',
  manage_reports:      'إدارة التقارير',
  manage_content:      'إدارة المحتوى',
  manage_security:     'إدارة الأمان',
};
const ALL_PERMS = Object.keys(PERM_LABELS);

async function renderSupervisors() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/supervisors');
    const rows = data.supervisors||data.data||[];
    const thead = `<tr><th>الاسم</th><th>الهاتف</th><th>الصلاحيات</th><th>تاريخ الإنشاء</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>{
          const perms = Array.isArray(r.permissions)?r.permissions:[];
          return `<tr>
            <td data-label="الاسم"><strong>${r.name||'—'}</strong></td>
            <td data-label="الهاتف">${r.phone||'—'}</td>
            <td data-label="الصلاحيات"><div style="display:flex;flex-wrap:wrap;gap:4px">${perms.map(p=>`<span class="badge badge-gold" style="margin:2px">${PERM_LABELS[p]||p}</span>`).join('')||'<span style="color:#888">لا توجد صلاحيات</span>'}</div></td>
            <td data-label="تاريخ الإنشاء">${fmtDate(r.created_at)}</td>
            <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
              <button class="btn-action btn-view btn-sm" onclick="editSupervisor(${r.id},'${(r.name||'').replace(/'/g,'')}','${r.phone||''}',${JSON.stringify(perms)})">تعديل الصلاحيات</button>
              <button class="btn-action btn-delete btn-sm" onclick="deleteSupervisor(${r.id})">حذف</button>
            </div></td>
          </tr>`;
        }).join('')
      : `<tr><td colspan="5" class="empty-cell">${emptyHtml('👮','لا يوجد مشرفون','أضف مشرفاً أولاً')}</td></tr>`;
    main.innerHTML = pageHeader('المشرفون والصلاحيات','إدارة حسابات المشرفين وصلاحياتهم.',
      `<button class="btn-white" onclick="showAddSupervisorModal()">+ إضافة مشرف</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('المشرفون والصلاحيات','') +
      `<div class="card">${errorHtml(e.message,'renderSupervisors')}</div>`;
  }
}

function buildPermsGrid(containerId, currentPerms=[]) {
  return `<div class="perms-grid" id="${containerId}">
    ${ALL_PERMS.map(p=>`
      <label class="perm-checkbox${currentPerms.includes(p)?' checked':''}" onclick="togglePerm(this)">
        <input type="checkbox" name="perm" value="${p}" ${currentPerms.includes(p)?'checked':''}>
        <div class="perm-check-icon">✓</div>
        <span class="perm-label">${PERM_LABELS[p]}</span>
      </label>`).join('')}
  </div>`;
}

function showAddSupervisorModal() {
  openModal('إضافة مشرف جديد', `
    <div class="form-group"><label>الاسم الكامل</label><input type="text" id="sup-name" placeholder="اسم المشرف"></div>
    <div class="form-group"><label>رقم الهاتف</label><input type="tel" id="sup-phone" placeholder="967xxxxxxxxx أو 05xxxxxxxx"></div>
    <div class="form-group"><label>كلمة المرور (للدخول بالـ OTP لا تحتاجها)</label><input type="password" id="sup-pass" placeholder="اختياري — 6 أحرف على الأقل"></div>
    <div class="form-group"><label>الصلاحيات (اختر الصلاحيات المطلوبة)</label>
      ${buildPermsGrid('perms-grid')}
    </div>`,
    async () => {
      const name  = document.getElementById('sup-name').value.trim();
      const phone = document.getElementById('sup-phone').value.trim();
      const pass  = document.getElementById('sup-pass').value.trim();
      const perms = [...document.querySelectorAll('#perms-grid input:checked')].map(i=>i.value);
      if (!name||!phone) { toast('أدخل الاسم ورقم الهاتف على الأقل','error'); return; }
      if (pass && pass.length < 6) { toast('كلمة المرور يجب أن تكون 6 أحرف على الأقل','error'); return; }
      try {
        await POST('/admin/supervisors', { name, phone, ...(pass?{password:pass}:{}), permissions:perms });
        toast('تم إضافة المشرف ✅','success');
        closeModal(); renderSupervisors();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}

function togglePerm(label) {
  label.classList.toggle('checked');
  const cb = label.querySelector('input');
  cb.checked = label.classList.contains('checked');
}

function editSupervisor(id, name, phone, currentPerms) {
  openModal(`تعديل صلاحيات: ${name}`, `
    <p style="color:#555;margin-bottom:12px">الهاتف: <strong>${phone}</strong></p>
    <div class="form-group"><label>الصلاحيات</label>
      ${buildPermsGrid('perms-grid-edit', currentPerms)}
    </div>`,
    async () => {
      const perms = [...document.querySelectorAll('#perms-grid-edit input:checked')].map(i=>i.value);
      try {
        await PUT(`/admin/supervisors/${id}/permissions`, { permissions:perms });
        toast('تم تحديث الصلاحيات ✅','success');
        closeModal(); renderSupervisors();
      } catch(e) {
        try {
          await PATCH(`/admin/supervisors/${id}`, { permissions:perms });
          toast('تم تحديث الصلاحيات ✅','success');
          closeModal(); renderSupervisors();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
}

async function deleteSupervisor(id) {
  if (!confirm('هل تريد حذف هذا المشرف؟')) return;
  try {
    await DEL(`/admin/supervisors/${id}`);
    toast('تم حذف المشرف','success');
    renderSupervisors();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: PACKAGES — FIXED with endpoint fallbacks + CRUD
══════════════════════════════════════════════════════ */
async function renderPackages() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback([
      '/admin/packages',
      '/packages',
      '/admin/subscription-packages',
      '/subscription-plans',
    ]);
    const list = data.packages || data.plans || data.data || data || [];
    const rows = Array.isArray(list) ? list.map(p => `<tr>
      <td data-label="#"><strong>${p.id||'-'}</strong></td>
      <td data-label="الباقة"><strong>${p.name||p.name_ar||p.title||'-'}</strong><br><small style="color:#888">${p.name_en||p.description||''}</small></td>
      <td data-label="السعر"><strong style="color:var(--gold)">${p.price||p.amount||'-'}</strong> ${p.currency||'USD'}</td>
      <td data-label="المدة">${p.duration_days?p.duration_days+' يوم':p.duration?p.duration+' يوم':'-'}</td>
      <td data-label="حد العقارات">${p.max_properties||p.properties_limit||p.max_listings||'—'}</td>
      <td data-label="حد الموظفين">${p.max_employees||p.employees_limit||p.max_team||'—'}</td>
      <td data-label="الحالة"><span class="badge ${p.is_active||p.active||p.status==='active'?'badge-green':'badge-red'}">${p.is_active||p.active||p.status==='active'?'نشط':'معطّل'}</span></td>
      <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
        <button class="btn-action btn-view btn-sm" onclick="editPackage(${p.id},'${(p.name||'').replace(/'/g,'')}',${p.price||0},${p.duration_days||p.duration||30},${p.max_properties||0},${p.max_employees||0})">تعديل</button>
        <button class="btn-action btn-delete btn-sm" onclick="deletePackage(${p.id})">حذف</button>
      </div></td>
    </tr>`).join('') : '';
    main.innerHTML = pageHeader('الباقات','إدارة باقات الاشتراك المتاحة في التطبيق.',
      `<button class="btn-white" onclick="showAddPackageModal()">+ إضافة باقة</button>`) +
      `<div class="card">
        ${rows ? `<div class="table-container"><table>
          <thead><tr><th>#</th><th>الباقة</th><th>السعر</th><th>المدة</th><th>حد العقارات</th><th>حد الموظفين</th><th>الحالة</th><th>إجراءات</th></tr></thead>
          <tbody>${rows}</tbody></table></div>` : emptyHtml('📦','لا توجد باقات مُعرَّفة','أضف باقة جديدة لعرضها هنا')}
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الباقات','') + `<div class="card">${errorHtml(e.message,'renderPackages')}</div>`;
  }
}

function showAddPackageModal() {
  openModal('إضافة باقة جديدة', `
    <div class="form-group"><label>اسم الباقة (عربي)</label><input type="text" id="pkg-name" placeholder="مثال: باقة الذهب"></div>
    <div class="form-group"><label>اسم الباقة (إنجليزي)</label><input type="text" id="pkg-name-en" placeholder="Gold Package"></div>
    <div class="form-group"><label>السعر</label><input type="number" id="pkg-price" placeholder="0.00" min="0" step="0.01"></div>
    <div class="form-group"><label>العملة</label>
      <select id="pkg-currency"><option value="USD">USD</option><option value="YER">YER</option><option value="SAR">SAR</option></select>
    </div>
    <div class="form-group"><label>المدة (بالأيام)</label><input type="number" id="pkg-days" placeholder="30" min="1"></div>
    <div class="form-group"><label>الحد الأقصى للعقارات</label><input type="number" id="pkg-props" placeholder="10" min="0"></div>
    <div class="form-group"><label>الحد الأقصى للموظفين</label><input type="number" id="pkg-emp" placeholder="5" min="0"></div>`,
    async () => {
      const name = document.getElementById('pkg-name').value.trim();
      const name_en = document.getElementById('pkg-name-en').value.trim();
      const price = parseFloat(document.getElementById('pkg-price').value) || 0;
      const currency = document.getElementById('pkg-currency').value;
      const duration_days = parseInt(document.getElementById('pkg-days').value) || 30;
      const max_properties = parseInt(document.getElementById('pkg-props').value) || 0;
      const max_employees = parseInt(document.getElementById('pkg-emp').value) || 0;
      if (!name) { toast('أدخل اسم الباقة','error'); return; }
      try {
        await POST('/admin/packages', { name, name_en, price, currency, duration_days, max_properties, max_employees });
        toast('تمت إضافة الباقة ✅','success');
        closeModal(); renderPackages();
      } catch(e) {
        try {
          await POST('/packages', { name, name_en, price, currency, duration_days, max_properties, max_employees });
          toast('تمت إضافة الباقة ✅','success');
          closeModal(); renderPackages();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
}

function editPackage(id, name, price, days, maxProps, maxEmp) {
  openModal(`تعديل الباقة: ${name}`, `
    <div class="form-group"><label>اسم الباقة</label><input type="text" id="epkg-name" value="${name}"></div>
    <div class="form-group"><label>السعر</label><input type="number" id="epkg-price" value="${price}" min="0" step="0.01"></div>
    <div class="form-group"><label>المدة (بالأيام)</label><input type="number" id="epkg-days" value="${days}" min="1"></div>
    <div class="form-group"><label>الحد الأقصى للعقارات</label><input type="number" id="epkg-props" value="${maxProps}" min="0"></div>
    <div class="form-group"><label>الحد الأقصى للموظفين</label><input type="number" id="epkg-emp" value="${maxEmp}" min="0"></div>`,
    async () => {
      const body = {
        name: document.getElementById('epkg-name').value.trim(),
        price: parseFloat(document.getElementById('epkg-price').value) || 0,
        duration_days: parseInt(document.getElementById('epkg-days').value) || 30,
        max_properties: parseInt(document.getElementById('epkg-props').value) || 0,
        max_employees: parseInt(document.getElementById('epkg-emp').value) || 0,
      };
      try {
        await PUT(`/admin/packages/${id}`, body);
        toast('تم تحديث الباقة ✅','success');
        closeModal(); renderPackages();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}

async function deletePackage(id) {
  if (!confirm('حذف هذه الباقة نهائياً؟')) return;
  try {
    await DEL(`/admin/packages/${id}`);
    toast('تم حذف الباقة','success'); renderPackages();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: SUBSCRIPTIONS — FIXED with approve/reject/activate/cancel
══════════════════════════════════════════════════════ */
async function renderSubscriptions() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/subscriptions');
    const rows = data.subscriptions||data.requests||data.data||[];
    const thead = `<tr>
      <th>رقم الطلب</th><th>المستخدم</th><th>الهاتف</th><th>نوع الحساب</th>
      <th>الباقة</th><th>تاريخ الطلب</th><th>الحالة</th><th>انتهاء</th><th>إجراءات</th>
    </tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td data-label="رقم الطلب"><strong>#${r.id}</strong></td>
          <td data-label="المستخدم">${r.user_name||r.office_name||r.user_id||'—'}</td>
          <td data-label="الهاتف">${r.user_phone||r.phone||'—'}</td>
          <td data-label="نوع الحساب"><span class="badge badge-gold">${r.user_role||r.account_type||'—'}</span></td>
          <td data-label="الباقة">${r.package_name||r.plan_type||r.packageType||'—'}</td>
          <td data-label="تاريخ الطلب">${fmtDate(r.created_at||r.requested_at)}</td>
          <td data-label="الحالة">${badgeForStatus(r.status||'pending')}</td>
          <td data-label="انتهاء">${fmtDate(r.expiry_date||r.expires_at)}</td>
          <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
            ${r.status==='pending'||r.status==='pending_review'?`
              <button class="btn-action btn-approve btn-sm" onclick="approveSubscription(${r.id})">قبول</button>
              <button class="btn-action btn-reject btn-sm" onclick="rejectSubscription(${r.id})">رفض</button>
            `:''}
            ${r.status==='approved'||r.status==='active'?`
              <button class="btn-action btn-delete btn-sm" onclick="cancelSubscription(${r.id})">إلغاء</button>
            `:''}
            ${r.status==='approved'&&r.status!=='active'?`
              <button class="btn-action btn-gold btn-sm" onclick="activateSubscription(${r.id})">تفعيل</button>
            `:''}
          </div></td>
        </tr>`).join('')
      : `<tr><td colspan="9" class="empty-cell">${emptyHtml('⭐','لا توجد اشتراكات')}</td></tr>`;
    main.innerHTML = pageHeader('الباقات والاشتراكات','إدارة اشتراكات المكاتب — النظام يدوي بدون دفع إلكتروني.',
      `<button class="btn-white" onclick="showManualSubModal()">+ اشتراك يدوي</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الباقات والاشتراكات','') +
      `<div class="card">${errorHtml(e.message,'renderSubscriptions')}</div>`;
  }
}
async function approveSubscription(id) {
  if (!confirm('قبول هذا الاشتراك؟')) return;
  try {
    await PATCH(`/admin/subscriptions/${id}/status`, { status:'approved' });
    toast('تم قبول الاشتراك ✅','success'); renderSubscriptions();
  } catch(e) {
    try {
      await POST(`/admin/subscriptions/${id}/approve`, {});
      toast('تم قبول الاشتراك ✅','success'); renderSubscriptions();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function rejectSubscription(id) {
  const reason = prompt('سبب الرفض:');
  if (reason === null) return;
  try {
    await PATCH(`/admin/subscriptions/${id}/status`, { status:'rejected', reason });
    toast('تم رفض الاشتراك','success'); renderSubscriptions();
  } catch(e) {
    try {
      await POST(`/admin/subscriptions/${id}/reject`, { reason });
      toast('تم رفض الاشتراك','success'); renderSubscriptions();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function activateSubscription(id) {
  if (!confirm('تفعيل هذا الاشتراك؟')) return;
  try {
    await PATCH(`/admin/subscriptions/${id}/status`, { status:'active' });
    toast('تم تفعيل الاشتراك ✅','success'); renderSubscriptions();
  } catch(e) { toast(e.message,'error'); }
}
async function cancelSubscription(id) {
  if (!confirm('إلغاء هذا الاشتراك؟')) return;
  try {
    await PATCH(`/admin/subscriptions/${id}/status`, { status:'cancelled' });
    toast('تم إلغاء الاشتراك','success'); renderSubscriptions();
  } catch(e) {
    try {
      await POST(`/admin/subscriptions/${id}/cancel`, {});
      toast('تم إلغاء الاشتراك','success'); renderSubscriptions();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
function showManualSubModal() {
  openModal('إنشاء اشتراك يدوي', `
    <div class="form-group"><label>معرف المستخدم (userId)</label><input type="number" id="sub-userid"></div>
    <div class="form-group"><label>نوع الباقة (packageType)</label>
      <select id="sub-type">
        <option value="gold">Gold</option>
        <option value="silver">Silver</option>
        <option value="employee_slots">Slots موظف</option>
      </select>
    </div>
    <div class="form-group"><label>عدد الأيام</label><input type="number" id="sub-days" value="30"></div>`,
    async () => {
      const userId = document.getElementById('sub-userid').value;
      const packageType = document.getElementById('sub-type').value;
      const durationInDays = document.getElementById('sub-days').value;
      if (!userId) { toast('أدخل معرف المستخدم','error'); return; }
      try {
        await POST('/admin/subscriptions/manual', { userId:+userId, packageType, durationInDays:+durationInDays });
        toast('تم إنشاء الاشتراك ✅','success');
        closeModal(); renderSubscriptions();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}

/* ══════════════════════════════════════════════════════
   PAGE: PAYMENT REVIEWS
══════════════════════════════════════════════════════ */
async function renderPaymentReviews() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/payment-reviews');
    const rows = data.reviews||data.data||[];
    const thead = `<tr><th>المستخدم</th><th>رقم الحوالة</th><th>الباقة</th><th>المبلغ</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td data-label="المستخدم">${r.user_name||r.user_id||'—'}<br><small style="color:var(--text-light)">${r.user_phone||''}</small></td>
          <td data-label="رقم الحوالة"><code style="font-size:12px;word-break:break-all">${r.transaction_ref||'—'}</code></td>
          <td data-label="الباقة">${r.package_name||r.package_id||r.payment_type||'—'}</td>
          <td data-label="المبلغ">${r.amount?fmtNum(r.amount)+' '+(r.currency||'USD'):'—'}</td>
          <td data-label="الحالة">${badgeForStatus(r.status)}</td>
          <td data-label="التاريخ">${fmtDate(r.created_at)}</td>
          <td data-label="إجراءات" class="actions-cell"><div class="action-btns">${r.status==='pending'?`
            <button class="btn-action btn-approve btn-sm" onclick="approvePayment(${r.id})">موافقة</button>
            <button class="btn-action btn-reject btn-sm" onclick="rejectPayment(${r.id})">رفض</button>`:'—'}
          </div></td>
        </tr>`).join('')
      : `<tr><td colspan="7" class="empty-cell">${emptyHtml('💳','لا توجد مدفوعات معلقة')}</td></tr>`;
    main.innerHTML = pageHeader('مراجعة المدفوعات','مراجعة الحوالات وإثباتات الدفع.',
      `<button class="btn-white" onclick="renderPaymentReviews()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('مراجعة المدفوعات','') +
      `<div class="card">${errorHtml(e.message,'renderPaymentReviews')}</div>`;
  }
}
async function approvePayment(id) {
  const note = prompt('ملاحظة للموافقة (اختياري):') ?? '';
  try {
    await POST(`/admin/payment-reviews/${id}/approve`, { admin_note:note });
    toast('تمت الموافقة على الدفع ✅','success');
    renderPaymentReviews();
  } catch(e) { toast(e.message,'error'); }
}
async function rejectPayment(id) {
  const note = prompt('سبب الرفض:');
  if (note === null) return;
  try {
    await POST(`/admin/payment-reviews/${id}/reject`, { admin_note:note });
    toast('تم رفض الدفع','success');
    renderPaymentReviews();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: VERIFICATIONS — FIXED with image display + re-upload action
══════════════════════════════════════════════════════ */
async function renderVerifications() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback(['/admin/verification','/admin/verifications','/admin/kyc']);
    const rows = data.verifications||data.requests||data.data||[];
    const thead = `<tr><th>المستخدم</th><th>الدور</th><th>نوع الوثيقة</th><th>الحالة</th><th>تاريخ الإرسال</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>{
          const imgs = [r.front_image||r.id_front||r.doc_front||r.image, r.back_image||r.id_back||r.doc_back].filter(Boolean);
          const imgBtn = imgs.length
            ? `<button class="btn-action btn-view btn-sm" onclick="openImageModal(${JSON.stringify(imgs).replace(/"/g,"'")})">📷 الصور</button>`
            : '';
          return `<tr>
            <td data-label="المستخدم">${r.user_name||r.name||r.user_id||'—'}<br><small style="color:#888">${r.user_phone||r.phone||''}</small></td>
            <td data-label="الدور"><span class="badge badge-gold">${r.user_role||r.role||'—'}</span></td>
            <td data-label="نوع الوثيقة">${r.doc_type||r.document_type||'هوية وطنية'}</td>
            <td data-label="الحالة">${badgeForStatus(r.status)}</td>
            <td data-label="تاريخ الإرسال">${fmtDate(r.submitted_at||r.created_at)}</td>
            <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
              ${imgBtn}
              ${r.status==='pending'||r.status==='pending_review'?`
                <button class="btn-action btn-approve btn-sm" onclick="approveVerif(${r.id})">قبول</button>
                <button class="btn-action btn-reject btn-sm" onclick="rejectVerif(${r.id})">رفض</button>
                <button class="btn-action btn-warn btn-sm" onclick="requestReupload(${r.id})">إعادة رفع</button>
              `:''}
              ${r.status==='approved'||r.status==='rejected'?`
                <button class="btn-action btn-warn btn-sm" onclick="requestReupload(${r.id})">إعادة رفع</button>
              `:''}
            </div></td>
          </tr>`;
        }).join('')
      : `<tr><td colspan="6" class="empty-cell">${emptyHtml('✅','لا توجد طلبات توثيق معلقة')}</td></tr>`;
    main.innerHTML = pageHeader('طلبات التوثيق','مراجعة طلبات التوثيق الرسمي.',
      `<button class="btn-white" onclick="renderVerifications()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('طلبات التوثيق','') +
      `<div class="card">${errorHtml(e.message,'renderVerifications')}</div>`;
  }
}
async function approveVerif(id) {
  const note = prompt('ملاحظة الموافقة (اختياري):') ?? '';
  try {
    await PATCH(`/admin/verification/${id}`, { status:'approved', admin_note:note });
    toast('تمت الموافقة على التوثيق ✅','success');
    renderVerifications();
  } catch(e) {
    try {
      await PUT(`/admin/verification/${id}`, { status:'approved', admin_note:note });
      toast('تمت الموافقة على التوثيق ✅','success');
      renderVerifications();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function rejectVerif(id) {
  const note = prompt('سبب الرفض:');
  if (note === null) return;
  try {
    await PATCH(`/admin/verification/${id}`, { status:'rejected', admin_note:note });
    toast('تم رفض طلب التوثيق','success');
    renderVerifications();
  } catch(e) {
    try {
      await PUT(`/admin/verification/${id}`, { status:'rejected', admin_note:note });
      toast('تم رفض طلب التوثيق','success');
      renderVerifications();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function requestReupload(id) {
  const note = prompt('رسالة للمستخدم (سبب طلب إعادة الرفع):');
  if (note === null) return;
  try {
    await PATCH(`/admin/verification/${id}`, { status:'reupload_required', admin_note:note });
    toast('تم طلب إعادة رفع المستندات','success');
    renderVerifications();
  } catch(e) {
    try {
      await POST(`/admin/verification/${id}/request-reupload`, { message:note });
      toast('تم طلب إعادة رفع المستندات','success');
      renderVerifications();
    } catch(e2) { toast(e2.message,'error'); }
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: ALL EMPLOYEES — FIXED with photo, office info, notifications
══════════════════════════════════════════════════════ */
async function renderAllEmployees() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/all-employees');
    const rows = data.employees||data.data||[];
    const thead = `<tr><th>الصورة</th><th>الاسم</th><th>الهاتف</th><th>الحالة</th><th>المكتب</th><th>رقم المكتب</th><th>تاريخ الإضافة</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>{
          const photo = r.profile_photo || r.avatar || r.photo || '';
          const thumb = photo
            ? `<img src="${photo}" class="user-thumb" onclick="openImageModal(['${photo}'])" style="cursor:pointer">`
            : `<div class="user-thumb-empty">👔</div>`;
          return `<tr>
            <td data-label="الصورة">${thumb}</td>
            <td data-label="الاسم"><strong>${r.name||'—'}</strong></td>
            <td data-label="الهاتف">${r.phone||'—'}</td>
            <td data-label="الحالة">${badgeForStatus(r.status||'active')}</td>
            <td data-label="المكتب">${r.office_name||r.office?.name||'—'}</td>
            <td data-label="رقم المكتب">${r.office_phone||r.office?.phone||'—'}</td>
            <td data-label="تاريخ الإضافة">${fmtDate(r.created_at)}</td>
            <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
              <button class="btn-action btn-view btn-sm" onclick="toggleEmployee(${r.id},'${r.status||'active'}')">${r.status==='active'?'تعطيل':'تفعيل'}</button>
              <button class="btn-action btn-delete btn-sm" onclick="deleteEmployee(${r.id})">حذف</button>
            </div></td>
          </tr>`;
        }).join('')
      : `<tr><td colspan="8" class="empty-cell">${emptyHtml('👔','لا يوجد موظفون')}</td></tr>`;
    main.innerHTML = pageHeader('إدارة الموظفين','جميع موظفي المكاتب المسجلين.',
      `<button class="btn-white" onclick="renderAllEmployees()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('إدارة الموظفين','') +
      `<div class="card">${errorHtml(e.message,'renderAllEmployees')}</div>`;
  }
}
async function toggleEmployee(id, currentStatus) {
  const newStatus = currentStatus === 'active' ? 'inactive' : 'active';
  try {
    await PATCH(`/admin/all-employees/${id}/toggle`, { status: newStatus });
    toast('تم تحديث حالة الموظف ✅','success');
    renderAllEmployees();
  } catch(e) {
    try {
      await PATCH(`/admin/all-employees/${id}/status`, { status: newStatus });
      toast('تم تحديث حالة الموظف ✅','success');
      renderAllEmployees();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function deleteEmployee(id) {
  if (!confirm('حذف هذا الموظف؟')) return;
  try {
    await DEL(`/admin/all-employees/${id}`);
    toast('تم حذف الموظف','success');
    renderAllEmployees();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: NOTIFICATIONS
══════════════════════════════════════════════════════ */
async function renderNotifications() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/notifications');
    const rows = data.notifications||data.data||[];
    const thead = `<tr><th>العنوان</th><th>الرسالة</th><th>الفئة المستهدفة</th><th>تاريخ الإرسال</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td data-label="العنوان"><strong>${r.title||'—'}</strong></td>
          <td data-label="الرسالة">${r.message||'—'}</td>
          <td data-label="الفئة المستهدفة"><span class="badge badge-gold">${r.target_role||'الكل'}</span></td>
          <td data-label="تاريخ الإرسال">${fmtDate(r.created_at)}</td>
        </tr>`).join('')
      : `<tr><td colspan="4" class="empty-cell">${emptyHtml('🔔','لا توجد إشعارات')}</td></tr>`;
    main.innerHTML = pageHeader('الإشعارات','إرسال وإدارة إشعارات التطبيق.',
      `<button class="btn-white" onclick="showNotifModal()">+ إشعار جديد</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الإشعارات','') +
      `<div class="card">${errorHtml(e.message,'renderNotifications')}</div>`;
  }
}
function showNotifModal() {
  openModal('إرسال إشعار جديد', `
    <div class="form-group"><label>العنوان</label><input type="text" id="notif-title" placeholder="عنوان الإشعار"></div>
    <div class="form-group"><label>الرسالة</label><textarea id="notif-msg" placeholder="نص الإشعار"></textarea></div>
    <div class="form-group"><label>الفئة المستهدفة</label>
      <select id="notif-role">
        <option value="all">الكل</option>
        <option value="seeker">الباحثون</option>
        <option value="owner">الملاك</option>
        <option value="office">المكاتب</option>
      </select>
    </div>`,
    async () => {
      const title  = document.getElementById('notif-title').value.trim();
      const message= document.getElementById('notif-msg').value.trim();
      const targetRole = document.getElementById('notif-role').value;
      if (!title||!message) { toast('أكمل العنوان والرسالة','error'); return; }
      try {
        await POST('/admin/notifications', { title, message, targetRole });
        toast('تم إرسال الإشعار ✅','success');
        closeModal(); renderNotifications();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}

/* ══════════════════════════════════════════════════════
   PAGE: CHATS — FIXED with image/attachment support
══════════════════════════════════════════════════════ */
async function renderChats() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/chats');
    const rows = data.rooms||data.chats||data.data||data||[];
    const thead = `<tr><th>رقم الغرفة</th><th>المشاركون</th><th>آخر رسالة</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>{
          const hasMedia = r.has_images || r.images_count > 0 || r.has_attachments;
          return `<tr>
            <td data-label="رقم الغرفة"><strong>#${r.id}</strong></td>
            <td data-label="المشاركون">${r.participant_a_name||r.participant_a||'—'} ↔ ${r.participant_b_name||r.participant_b||'—'}</td>
            <td data-label="آخر رسالة">
              ${r.last_message||'لا توجد رسائل'}
              ${hasMedia ? '<span class="badge badge-gold" style="margin-right:4px">📎 مرفقات</span>' : ''}
            </td>
            <td data-label="الحالة">${badgeForStatus(r.status||'open')}</td>
            <td data-label="التاريخ">${fmtDate(r.created_at)}</td>
            <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
              <button class="btn-action btn-view btn-sm" onclick="viewChatMessages(${r.id})">عرض</button>
              <button class="btn-action btn-delete btn-sm" onclick="deleteChat(${r.id})">حذف</button>
            </div></td>
          </tr>`;
        }).join('')
      : `<tr><td colspan="6" class="empty-cell">${emptyHtml('💬','لا توجد محادثات')}</td></tr>`;
    main.innerHTML = pageHeader('إدارة المحادثات','مراقبة محادثات المستخدمين.',
      `<button class="btn-white" onclick="renderChats()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('إدارة المحادثات','') +
      `<div class="card">${errorHtml(e.message,'renderChats')}</div>`;
  }
}
async function viewChatMessages(roomId) {
  try {
    const data = await GET(`/admin/chats/${roomId}/messages`);
    const msgs = data.messages || data.data || [];
    const msgsHtml = msgs.length
      ? `<div class="chat-messages-list">
          ${msgs.map(m => {
            const isImg = m.type === 'image' || m.message_type === 'image' || (m.image_url || m.attachment_url);
            const imgHtml = isImg && (m.image_url || m.attachment_url || m.media_url)
              ? `<div style="margin-top:6px"><img src="${m.image_url||m.attachment_url||m.media_url}" style="max-width:200px;border-radius:8px;cursor:pointer" onclick="openImageModal(['${m.image_url||m.attachment_url||m.media_url}'])"></div>`
              : '';
            return `<div class="chat-msg-item">
              <strong>${m.sender_name||m.user_name||m.from||'مجهول'}</strong>
              <span style="color:#888;font-size:12px;margin-right:8px">${fmtDate(m.created_at||m.sent_at)}</span>
              <div>${m.content||m.message||m.text||''}</div>
              ${imgHtml}
            </div>`;
          }).join('')}
        </div>`
      : '<p style="text-align:center;color:#888;padding:20px">لا توجد رسائل</p>';
    openModal(`محادثة #${roomId}`, msgsHtml, null);
  } catch(e) {
    toast('تعذر تحميل الرسائل: ' + e.message,'error');
  }
}
async function deleteChat(id) {
  if (!confirm('حذف هذه المحادثة؟')) return;
  try {
    await DEL(`/admin/chats/${id}`);
    toast('تم حذف المحادثة','success');
    renderChats();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: REPORTS / STATISTICS
══════════════════════════════════════════════════════ */
async function renderReports() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/stats');
    const s = data;
    const roleRows = Object.entries(s.users_by_role||{}).map(([k,v]) =>
      `<div class="insight-row"><span class="insight-label">${k}</span><span class="insight-value">${fmtNum(v)}</span></div>`
    ).join('');
    main.innerHTML = pageHeader('التقارير والإحصائيات','بيانات مباشرة من قاعدة البيانات.',
      `<button class="btn-white" onclick="renderReports()">🔄 تحديث</button>`) +
      `<div class="insights-grid">
        <div class="card">
          <h3 style="font-size:16px;font-weight:800;color:#102A43;margin-bottom:16px">📊 إحصائيات العقارات</h3>
          <div class="insight-row"><span class="insight-label">إجمالي العقارات</span><span class="insight-value">${fmtNum(s.totalProperties||s.total_properties)}</span></div>
          <div class="insight-row"><span class="insight-label">نشطة</span><span class="insight-value">${fmtNum(s.activeProperties||s.active_properties)}</span></div>
          <div class="insight-row"><span class="insight-label">قيد المراجعة</span><span class="insight-value">${fmtNum(s.pendingProperties||s.pending_properties)}</span></div>
          <div class="insight-row"><span class="insight-label">مميزة</span><span class="insight-value">${fmtNum(s.featuredProperties||s.featured_properties)}</span></div>
          <div class="insight-row"><span class="insight-label">مُباعة</span><span class="insight-value">${fmtNum(s.soldProperties||s.sold_properties)}</span></div>
          <div class="insight-row"><span class="insight-label">مؤجرة</span><span class="insight-value">${fmtNum(s.rentedProperties||s.rented_properties)}</span></div>
        </div>
        <div class="card">
          <h3 style="font-size:16px;font-weight:800;color:#102A43;margin-bottom:16px">👥 إحصائيات المستخدمين</h3>
          ${roleRows||'<p style="color:#6B7280">لا توجد بيانات</p>'}
        </div>
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader('التقارير والإحصائيات','') +
      `<div class="card">${errorHtml(e.message,'renderReports')}</div>`;
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: ACTIVITY LOG
══════════════════════════════════════════════════════ */
async function renderActivityLogs() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/activity-log');
    const rows = data.logs||data.data||[];
    const thead = `<tr><th>الحدث</th><th>المستخدم</th><th>التفاصيل</th><th>التاريخ</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td data-label="الحدث"><span class="badge badge-gold">${r.action||r.event||'—'}</span></td>
          <td data-label="المستخدم">${r.user_name||r.admin_name||r.user_id||'—'}</td>
          <td data-label="التفاصيل">${r.details||r.description||JSON.stringify(r.data||{}).slice(0,80)}</td>
          <td data-label="التاريخ">${fmtDate(r.created_at)}</td>
        </tr>`).join('')
      : `<tr><td colspan="4" class="empty-cell">${emptyHtml('📜','لا توجد سجلات')}</td></tr>`;
    main.innerHTML = pageHeader('سجل الأنشطة','جميع أنشطة الإدارة المسجلة.',
      `<button class="btn-white" onclick="renderActivityLogs()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('سجل الأنشطة','') +
      `<div class="card">${errorHtml(e.message,'renderActivityLogs')}</div>`;
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: SETTINGS — FIXED with edit functionality
══════════════════════════════════════════════════════ */
async function renderSettings() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/settings');
    const settings = data.settings||data||{};
    const rows = Object.entries(settings).map(([k,v])=>
      `<div class="insight-row">
        <span class="insight-label">${k}</span>
        <div style="display:flex;align-items:center;gap:8px">
          <span class="insight-value">${typeof v==='object'?JSON.stringify(v).slice(0,60):String(v)}</span>
          <button class="btn-action btn-view btn-sm" onclick="editSetting('${k}','${String(v).replace(/'/g,'')}')">تعديل</button>
        </div>
      </div>`
    ).join('');
    main.innerHTML = pageHeader('الإعدادات','إعدادات التطبيق العامة.',
      `<button class="btn-white" onclick="renderSettings()">🔄 تحديث</button>`) +
      `<div class="card"><h3 style="font-size:16px;font-weight:800;margin-bottom:16px">⚙️ الإعدادات الحالية</h3>${rows||'<p style="color:#6B7280">لا توجد إعدادات</p>'}</div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الإعدادات','') +
      `<div class="card">${errorHtml(e.message,'renderSettings')}</div>`;
  }
}
function editSetting(key, currentValue) {
  openModal(`تعديل الإعداد: ${key}`, `
    <div class="form-group"><label>${key}</label><input type="text" id="setting-value" value="${currentValue}"></div>`,
    async () => {
      const value = document.getElementById('setting-value').value.trim();
      try {
        await PUT('/admin/settings', { [key]: value });
        toast('تم حفظ الإعداد ✅','success');
        closeModal(); renderSettings();
      } catch(e) {
        try {
          await PATCH('/admin/settings', { [key]: value });
          toast('تم حفظ الإعداد ✅','success');
          closeModal(); renderSettings();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
}

/* ══════════════════════════════════════════════════════
   PAGE: LOCATIONS — FIXED with proper display
══════════════════════════════════════════════════════ */
async function renderLocations() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback([
      '/admin/locations/cities',
      '/admin/cities',
      '/locations/cities',
      '/cities',
    ]);
    const rows = data.cities||data.data||data||[];
    const arrRows = Array.isArray(rows) ? rows : [];
    const thead = `<tr><th>#</th><th>اسم المدينة</th><th>المحافظة / المنطقة</th><th>الإجراءات</th></tr>`;
    const tbody = arrRows.length
      ? arrRows.map(r=>`<tr>
          <td data-label="#">${r.id||'—'}</td>
          <td data-label="اسم المدينة"><strong>${r.name||r.city_name||r.name_ar||'—'}</strong></td>
          <td data-label="المحافظة">${r.governorate||r.governorate_name||r.region||'—'}</td>
          <td data-label="الإجراءات" class="actions-cell"><div class="action-btns">
            <button class="btn-action btn-view btn-sm" onclick="editCity(${r.id},'${(r.name||'').replace(/'/g,'')}','${(r.governorate||'').replace(/'/g,'')}')">تعديل</button>
            <button class="btn-action btn-delete btn-sm" onclick="deleteCity(${r.id})">حذف</button>
          </div></td>
        </tr>`).join('')
      : `<tr><td colspan="4" class="empty-cell">${emptyHtml('📍','لا توجد مدن')}</td></tr>`;
    main.innerHTML = pageHeader('المواقع الجغرافية','إدارة المدن والمناطق.',
      `<button class="btn-white" onclick="showAddCityModal()">+ إضافة مدينة</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div>
      <p style="padding:12px 16px 0;color:#6B7280;font-size:13px">إجمالي: ${arrRows.length} مدينة</p>
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader('المواقع الجغرافية','') +
      `<div class="card">${errorHtml(e.message,'renderLocations')}</div>`;
  }
}
function showAddCityModal() {
  openModal('إضافة مدينة', `
    <div class="form-group"><label>اسم المدينة</label><input type="text" id="city-name" placeholder="مثال: صنعاء"></div>
    <div class="form-group"><label>المحافظة / المنطقة</label><input type="text" id="city-gov" placeholder="مثال: أمانة العاصمة"></div>`,
    async () => {
      const name = document.getElementById('city-name').value.trim();
      const governorate = document.getElementById('city-gov').value.trim();
      if (!name) { toast('أدخل اسم المدينة','error'); return; }
      try {
        await POST('/admin/locations/cities', { name, governorate });
        toast('تمت إضافة المدينة ✅','success');
        closeModal(); renderLocations();
      } catch(e) {
        try {
          await POST('/admin/cities', { name, governorate });
          toast('تمت إضافة المدينة ✅','success');
          closeModal(); renderLocations();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
}
function editCity(id, name, governorate) {
  openModal('تعديل المدينة', `
    <div class="form-group"><label>اسم المدينة</label><input type="text" id="city-name-edit" value="${name}"></div>
    <div class="form-group"><label>المحافظة</label><input type="text" id="city-gov-edit" value="${governorate}"></div>`,
    async () => {
      const newName = document.getElementById('city-name-edit').value.trim();
      const newGov = document.getElementById('city-gov-edit').value.trim();
      if (!newName) { toast('أدخل اسم المدينة','error'); return; }
      try {
        await PUT(`/admin/locations/cities/${id}`, { name:newName, governorate:newGov });
        toast('تم تحديث المدينة ✅','success');
        closeModal(); renderLocations();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}
async function deleteCity(id) {
  if (!confirm('حذف هذه المدينة؟')) return;
  try {
    await DEL(`/admin/locations/cities/${id}`);
    toast('تم حذف المدينة','success');
    renderLocations();
  } catch(e) {
    try {
      await DEL(`/admin/cities/${id}`);
      toast('تم حذف المدينة','success');
      renderLocations();
    } catch(e2) { toast(e2.message,'error'); }
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: PROPERTY TYPES — FIXED with proper display
══════════════════════════════════════════════════════ */
async function renderPropertyTypes() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback([
      '/admin/property-types',
      '/property-types',
      '/admin/property_types',
    ]);
    const rows = data.types||data.property_types||data.data||data||[];
    const arrRows = Array.isArray(rows) ? rows : [];
    const thead = `<tr><th>#</th><th>النوع</th><th>الوصف</th><th>إجراءات</th></tr>`;
    const tbody = arrRows.length
      ? arrRows.map(r=>`<tr>
          <td data-label="#">${r.id||'—'}</td>
          <td data-label="النوع"><strong>${r.name||r.name_ar||r.type_name||'—'}</strong></td>
          <td data-label="الوصف">${r.description||r.description_ar||'—'}</td>
          <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
            <button class="btn-action btn-delete btn-sm" onclick="deletePropertyType(${r.id})">حذف</button>
          </div></td>
        </tr>`).join('')
      : `<tr><td colspan="4" class="empty-cell">${emptyHtml('🏗️','لا توجد أنواع عقارات')}</td></tr>`;
    main.innerHTML = pageHeader('أنواع العقارات','إدارة أنواع العقارات المتاحة.',
      `<button class="btn-white" onclick="showAddPropertyTypeModal()">+ إضافة نوع</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('أنواع العقارات','') +
      `<div class="card">${errorHtml(e.message,'renderPropertyTypes')}</div>`;
  }
}
function showAddPropertyTypeModal() {
  openModal('إضافة نوع عقار', `
    <div class="form-group"><label>الاسم (عربي)</label><input type="text" id="ptype-name" placeholder="مثال: شقة سكنية"></div>
    <div class="form-group"><label>الوصف (اختياري)</label><textarea id="ptype-desc" placeholder="وصف مختصر"></textarea></div>`,
    async () => {
      const name = document.getElementById('ptype-name').value.trim();
      const description = document.getElementById('ptype-desc').value.trim();
      if (!name) { toast('أدخل اسم النوع','error'); return; }
      try {
        await POST('/admin/property-types', { name, description });
        toast('تمت الإضافة ✅','success');
        closeModal(); renderPropertyTypes();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}
async function deletePropertyType(id) {
  if (!confirm('حذف هذا النوع؟')) return;
  try {
    await DEL(`/admin/property-types/${id}`);
    toast('تم الحذف','success');
    renderPropertyTypes();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: MONITORING
══════════════════════════════════════════════════════ */
async function renderMonitoring() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/monitoring/health');
    const render = (obj, depth=0) => {
      if (typeof obj !== 'object' || !obj) return `<span>${obj}</span>`;
      return Object.entries(obj).map(([k,v])=>`
        <div class="insight-row" style="padding-right:${depth*12}px">
          <span class="insight-label">${k}</span>
          <span class="insight-value">${typeof v==='object'?'':v}</span>
        </div>
        ${typeof v==='object'?render(v,depth+1):''}`).join('');
    };
    main.innerHTML = pageHeader('مراقبة النظام','حالة الخادم وقاعدة البيانات.',
      `<button class="btn-white" onclick="renderMonitoring()">🔄 تحديث</button>`) +
      `<div class="card"><h3 style="font-size:16px;font-weight:800;margin-bottom:16px">⚡ حالة النظام</h3>${render(data)}</div>`;
  } catch(e) {
    main.innerHTML = pageHeader('مراقبة النظام','') +
      `<div class="card">${errorHtml(e.message,'renderMonitoring')}</div>`;
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: ADS — FIXED with add/edit/activate/deactivate
══════════════════════════════════════════════════════ */
async function renderAds() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback(['/admin/ads','/ads']);
    const rows = data.ads||data.data||[];
    const arrRows = Array.isArray(rows) ? rows : [];
    const thead = `<tr><th>الصورة</th><th>العنوان</th><th>الرابط</th><th>الحالة</th><th>تاريخ الانتهاء</th><th>إجراءات</th></tr>`;
    const tbody = arrRows.length
      ? arrRows.map(r=>{
          const img = r.image || r.image_url || r.banner || '';
          const thumb = img
            ? `<img src="${img}" class="prop-thumb" onclick="openImageModal(['${img}'])" style="cursor:pointer">`
            : `<div class="prop-thumb-empty">📣</div>`;
          const isActive = r.is_active || r.active || r.status === 'active';
          return `<tr>
            <td data-label="الصورة">${thumb}</td>
            <td data-label="العنوان"><strong>${r.title||'—'}</strong></td>
            <td data-label="الرابط"><a href="${r.url||r.link||'#'}" target="_blank" style="color:var(--gold)">${(r.url||r.link||'—').substring(0,35)}</a></td>
            <td data-label="الحالة">${badgeForStatus(isActive?'active':'inactive')}</td>
            <td data-label="تاريخ الانتهاء">${fmtDate(r.expires_at||r.end_date)}</td>
            <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
              <button class="btn-action btn-view btn-sm" onclick="editAd(${r.id},'${(r.title||'').replace(/'/g,'')}','${(r.url||r.link||'').replace(/'/g,'')}')">تعديل</button>
              <button class="btn-action ${isActive?'btn-warn':'btn-approve'} btn-sm" onclick="toggleAd(${r.id},${isActive})">${isActive?'إلغاء تفعيل':'تفعيل'}</button>
              <button class="btn-action btn-delete btn-sm" onclick="deleteAd(${r.id})">حذف</button>
            </div></td>
          </tr>`;
        }).join('')
      : `<tr><td colspan="6" class="empty-cell">${emptyHtml('📣','لا توجد إعلانات')}</td></tr>`;
    main.innerHTML = pageHeader('الإعلانات','إدارة الإعلانات في التطبيق.',
      `<button class="btn-white" onclick="showAddAdModal()">+ إضافة إعلان</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الإعلانات','') +
      `<div class="card">${errorHtml(e.message,'renderAds')}</div>`;
  }
}
function showAddAdModal() {
  openModal('إضافة إعلان جديد', `
    <div class="form-group"><label>العنوان</label><input type="text" id="ad-title" placeholder="عنوان الإعلان"></div>
    <div class="form-group"><label>رابط الصورة (URL)</label><input type="url" id="ad-image" placeholder="https://..."></div>
    <div class="form-group"><label>رابط الوجهة</label><input type="url" id="ad-url" placeholder="https://..."></div>
    <div class="form-group"><label>تاريخ الانتهاء</label><input type="date" id="ad-expires"></div>`,
    async () => {
      const title = document.getElementById('ad-title').value.trim();
      const image = document.getElementById('ad-image').value.trim();
      const url = document.getElementById('ad-url').value.trim();
      const expires_at = document.getElementById('ad-expires').value;
      if (!title) { toast('أدخل عنوان الإعلان','error'); return; }
      try {
        await POST('/admin/ads', { title, image, url, expires_at, is_active:true });
        toast('تمت إضافة الإعلان ✅','success');
        closeModal(); renderAds();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}
function editAd(id, title, url) {
  openModal('تعديل الإعلان', `
    <div class="form-group"><label>العنوان</label><input type="text" id="ead-title" value="${title}"></div>
    <div class="form-group"><label>رابط الصورة</label><input type="url" id="ead-image" placeholder="https://..."></div>
    <div class="form-group"><label>رابط الوجهة</label><input type="url" id="ead-url" value="${url}"></div>`,
    async () => {
      const body = {
        title: document.getElementById('ead-title').value.trim(),
        url: document.getElementById('ead-url').value.trim(),
      };
      const img = document.getElementById('ead-image').value.trim();
      if (img) body.image = img;
      try {
        await PUT(`/admin/ads/${id}`, body);
        toast('تم تحديث الإعلان ✅','success');
        closeModal(); renderAds();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}
async function toggleAd(id, currentActive) {
  try {
    await PATCH(`/admin/ads/${id}`, { is_active: !currentActive });
    toast(currentActive ? 'تم إلغاء تفعيل الإعلان' : 'تم تفعيل الإعلان ✅','success');
    renderAds();
  } catch(e) { toast(e.message,'error'); }
}
async function deleteAd(id) {
  if (!confirm('حذف هذا الإعلان؟')) return;
  try { await DEL(`/admin/ads/${id}`); toast('تم الحذف','success'); renderAds(); }
  catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: BACKUP — FIXED with download/restore
══════════════════════════════════════════════════════ */
async function renderBackup() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/backup');
    const list = data.backups || data.data || data || [];
    const rows = Array.isArray(list) ? list.map(b => `<tr>
      <td data-label="#"><strong>${b.id||'-'}</strong></td>
      <td data-label="اسم الملف"><code style="font-size:12px">${b.filename||b.name||'-'}</code></td>
      <td data-label="الحجم">${b.size_mb?b.size_mb+' MB':b.size?b.size:'—'}</td>
      <td data-label="الحالة"><span class="badge badge-green">${b.status||'مكتمل'}</span></td>
      <td data-label="التاريخ">${fmtDate(b.created_at)}</td>
      <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
        <button class="btn-action btn-approve btn-sm" onclick="downloadBackup(${b.id},'${b.filename||b.name||b.id}')">⬇ تنزيل</button>
        <button class="btn-action btn-warn btn-sm" onclick="restoreBackup(${b.id},'${b.filename||b.name||''}')">🔄 استعادة</button>
      </div></td>
    </tr>`).join('') : '';
    main.innerHTML = pageHeader('النسخ الاحتياطي','إدارة النسخ الاحتياطية لقاعدة البيانات.',
      `<button class="btn-primary" onclick="createBackup()">📦 إنشاء نسخة احتياطية</button>`) +
      `<div class="card">
        ${rows ? `<div class="table-container"><table>
          <thead><tr><th>#</th><th>اسم الملف</th><th>الحجم</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr></thead>
          <tbody>${rows}</tbody></table></div>` : emptyHtml('💾','لا توجد نسخ احتياطية بعد','اضغط على الزر أعلاه لإنشاء نسخة احتياطية')}
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader('النسخ الاحتياطي','') + `<div class="card">${errorHtml(e.message,'renderBackup')}</div>`;
  }
}
async function createBackup() {
  try {
    toast('جاري إنشاء النسخة الاحتياطية...','');
    await POST('/admin/backup/create', {});
    toast('تم إنشاء النسخة الاحتياطية ✅','success');
    setTimeout(renderBackup, 2000);
  } catch(e) { toast(e.message,'error'); }
}
async function downloadBackup(id, filename) {
  try {
    toast('جاري تحضير التنزيل...','');
    // Try to get a signed download URL
    const data = await GET(`/admin/backup/${id}/download`);
    const url = data.url || data.download_url || data.signed_url;
    if (url) {
      const a = document.createElement('a');
      a.href = url;
      a.download = filename || `backup_${id}.sql`;
      a.click();
    } else {
      toast('لا يوجد رابط تنزيل لهذه النسخة','error');
    }
  } catch(e) { toast('تعذر تنزيل النسخة: ' + e.message,'error'); }
}
async function restoreBackup(id, filename) {
  if (!confirm(`⚠️ تحذير: سيتم استعادة النسخة الاحتياطية "${filename}" وستُستبدل البيانات الحالية. هل أنت متأكد؟`)) return;
  try {
    toast('جاري استعادة النسخة الاحتياطية...','');
    await POST(`/admin/backup/${id}/restore`, {});
    toast('تمت استعادة النسخة الاحتياطية ✅','success');
    renderBackup();
  } catch(e) { toast('تعذر الاستعادة: ' + e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: SECURITY — FIXED with audit log
══════════════════════════════════════════════════════ */
async function renderSecurity() {
  const main = document.getElementById('main-content');
  try {
    const [bannedData, auditData] = await Promise.allSettled([
      GET('/admin/security/banned-users'),
      GET('/admin/security/audit-log'),
    ]);
    const banned = bannedData.status === 'fulfilled'
      ? (bannedData.value.users||bannedData.value.banned_users||bannedData.value.data||[])
      : [];
    const auditLogs = auditData.status === 'fulfilled'
      ? (auditData.value.logs||auditData.value.data||[])
      : [];

    const bannedRows = banned.length
      ? banned.map(r=>`<tr>
          <td data-label="المستخدم">${r.name||r.user_id||'—'}</td>
          <td data-label="الهاتف">${r.phone||'—'}</td>
          <td data-label="السبب">${r.reason||'—'}</td>
          <td data-label="تاريخ الحظر">${fmtDate(r.banned_at||r.created_at)}</td>
          <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
            <button class="btn-action btn-approve btn-sm" onclick="unbanUser(${r.id||r.user_id})">إلغاء الحظر</button>
          </div></td>
        </tr>`).join('')
      : `<tr><td colspan="5" class="empty-cell">${emptyHtml('🔒','لا يوجد مستخدمون محظورون')}</td></tr>`;

    const auditHtml = auditLogs.length
      ? `<div class="table-container"><table>
          <thead><tr><th>الحدث</th><th>المستخدم</th><th>التفاصيل</th><th>IP</th><th>التاريخ</th></tr></thead>
          <tbody>${auditLogs.map(l=>`<tr>
            <td data-label="الحدث"><span class="badge badge-gold">${l.action||l.event||'—'}</span></td>
            <td data-label="المستخدم">${l.user_name||l.admin_name||l.user_id||'—'}</td>
            <td data-label="التفاصيل">${l.details||l.description||'—'}</td>
            <td data-label="IP"><code style="font-size:11px">${l.ip_address||l.ip||'—'}</code></td>
            <td data-label="التاريخ">${fmtDate(l.created_at)}</td>
          </tr>`).join('')}</tbody>
        </table></div>`
      : '<p style="color:#6B7280;padding:16px">لا توجد سجلات أمنية</p>';

    main.innerHTML = pageHeader('إدارة الأمان','إدارة المستخدمين المحظورين وسجل العمليات الأمنية.',
      `<button class="btn-white" onclick="showBanModal()">+ حظر مستخدم</button>`) +
      `<div class="card">
        <h3 style="font-size:16px;font-weight:800;margin-bottom:16px">🚫 المستخدمون المحظورون</h3>
        <div class="table-container">
          <table><thead><tr><th>المستخدم</th><th>الهاتف</th><th>السبب</th><th>تاريخ الحظر</th><th>إجراءات</th></tr></thead>
          <tbody>${bannedRows}</tbody></table>
        </div>
      </div>
      <div class="card" style="margin-top:20px">
        <h3 style="font-size:16px;font-weight:800;margin-bottom:16px">🔐 سجل العمليات الأمنية</h3>
        ${auditHtml}
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader('إدارة الأمان','') +
      `<div class="card">${errorHtml(e.message,'renderSecurity')}</div>`;
  }
}
function showBanModal() {
  openModal('حظر مستخدم', `
    <div class="form-group"><label>رقم الهاتف</label><input type="tel" id="ban-phone" placeholder="967xxxxxxxxx"></div>
    <div class="form-group"><label>السبب</label><input type="text" id="ban-reason" placeholder="سبب الحظر"></div>`,
    async () => {
      const phone = document.getElementById('ban-phone').value.trim();
      const reason = document.getElementById('ban-reason').value.trim();
      if (!phone) { toast('أدخل رقم الهاتف','error'); return; }
      try {
        await POST('/admin/security/ban-user', { phone, reason });
        toast('تم حظر المستخدم','success');
        closeModal(); renderSecurity();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}
async function unbanUser(id) {
  if (!confirm('إلغاء حظر هذا المستخدم؟')) return;
  try {
    await DEL(`/admin/security/ban-user/${id}`);
    toast('تم إلغاء الحظر','success');
    renderSecurity();
  } catch(e) {
    try {
      await POST(`/admin/security/unban-user`, { userId: id });
      toast('تم إلغاء الحظر','success');
      renderSecurity();
    } catch(e2) { toast(e2.message,'error'); }
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: EMERGENCY — FIXED
══════════════════════════════════════════════════════ */
async function renderEmergency() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback(['/admin/emergency/flags','/admin/emergency','/admin/system/flags']);
    const flags = data.flags||data.data||data||{};
    const rows = typeof flags === 'object' && !Array.isArray(flags)
      ? Object.entries(flags).map(([k,v])=>`
          <div class="insight-row">
            <span class="insight-label">${k}</span>
            <div style="display:flex;align-items:center;gap:8px">
              <span class="insight-value">${typeof v==='boolean'?`<span class="badge ${v?'badge-red':'badge-green'}">${v?'مفعّل':'معطّل'}</span>`:v}</span>
              ${typeof v === 'boolean'
                ? `<button class="btn-action btn-warn btn-sm" onclick="toggleEmergencyFlag('${k}',${v})">${v?'إيقاف':'تفعيل'}</button>`
                : ''}
            </div>
          </div>`).join('')
      : '<p style="color:#6B7280">لا توجد بيانات</p>';
    main.innerHTML = pageHeader('مركز الطوارئ','حالات الطوارئ وأعلام النظام.',
      `<button class="btn-white" onclick="renderEmergency()">🔄 تحديث</button>`) +
      `<div class="card"><h3 style="font-size:16px;font-weight:800;margin-bottom:16px">🚨 أعلام النظام</h3>${rows}</div>`;
  } catch(e) {
    main.innerHTML = pageHeader('مركز الطوارئ','') +
      `<div class="card">${errorHtml(e.message,'renderEmergency')}</div>`;
  }
}
async function toggleEmergencyFlag(key, currentValue) {
  try {
    await PATCH('/admin/emergency/flags', { [key]: !currentValue });
    toast('تم تحديث العَلَم','success');
    renderEmergency();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: PAYMENTS
══════════════════════════════════════════════════════ */
async function renderPayments() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/payments');
    const list = data.payments || data.data || data || [];
    const rows = Array.isArray(list) ? list.map(p => `<tr>
      <td data-label="#">${p.id||'-'}</td>
      <td data-label="المستخدم">${p.user_name||p.phone||'-'}</td>
      <td data-label="الباقة">${p.package_name||p.type||'-'}</td>
      <td data-label="المبلغ">${p.amount||'-'} ${p.currency||'USD'}</td>
      <td data-label="الحالة"><span class="badge ${p.status==='completed'?'badge-green':p.status==='pending'?'badge-yellow':'badge-red'}">${p.status||'-'}</span></td>
      <td data-label="التاريخ">${p.created_at?new Date(p.created_at).toLocaleDateString('ar'):'–'}</td>
    </tr>`).join('') : '';
    main.innerHTML = pageHeader('المدفوعات','سجل جميع المدفوعات في النظام.',
      `<button class="btn-white" onclick="renderPayments()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container"><table>
        <thead><tr><th>#</th><th>المستخدم</th><th>الباقة</th><th>المبلغ</th><th>الحالة</th><th>التاريخ</th></tr></thead>
        <tbody>${rows||`<tr><td colspan="6" class="empty-cell">${emptyHtml('💰','لا توجد مدفوعات')}</td></tr>`}</tbody>
      </table></div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('المدفوعات','') + `<div class="card">${errorHtml(e.message,'renderPayments')}</div>`;
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: COMPLAINTS
══════════════════════════════════════════════════════ */
async function renderComplaints() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/complaints');
    const list = data.complaints || data.data || data || [];
    const rows = Array.isArray(list) ? list.map(c => `<tr>
      <td data-label="#">${c.id||'-'}</td>
      <td data-label="المُبلِّغ">${c.reporter_name||c.user_name||'-'}</td>
      <td data-label="الموضوع">${c.subject||c.type||'-'}</td>
      <td data-label="الوصف">${(c.description||c.message||'').substring(0,60)}${(c.description||'').length>60?'...':''}</td>
      <td data-label="الحالة"><span class="badge ${c.status==='resolved'?'badge-green':c.status==='pending'?'badge-yellow':'badge-red'}">${c.status||'pending'}</span></td>
      <td data-label="التاريخ">${c.created_at?new Date(c.created_at).toLocaleDateString('ar'):'–'}</td>
      <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
        ${c.status!=='resolved'?`<button class="btn-action btn-approve btn-sm" onclick="resolveComplaint(${c.id})">حل</button>`:''}
      </div></td>
    </tr>`).join('') : '';
    main.innerHTML = pageHeader('البلاغات والشكاوى','إدارة البلاغات والشكاوى المُقدّمة من المستخدمين.',
      `<button class="btn-white" onclick="renderComplaints()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container"><table>
        <thead><tr><th>#</th><th>المُبلِّغ</th><th>الموضوع</th><th>الوصف</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr></thead>
        <tbody>${rows||`<tr><td colspan="7" class="empty-cell">${emptyHtml('🚩','لا توجد شكاوى')}</td></tr>`}</tbody>
      </table></div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('البلاغات والشكاوى','') + `<div class="card">${errorHtml(e.message,'renderComplaints')}</div>`;
  }
}
async function resolveComplaint(id) {
  const note = prompt('ملاحظة الحل (اختياري):') ?? '';
  try {
    await PATCH(`/admin/complaints/${id}`, { status:'resolved', admin_note:note });
    toast('تم حل الشكوى ✅','success'); renderComplaints();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: MESSAGES SUPPORT
══════════════════════════════════════════════════════ */
async function renderMessagesSupport() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/messages');
    const list = data.messages || data.data || data || [];
    const rows = Array.isArray(list) ? list.map(m => `<tr>
      <td data-label="#">${m.id||'-'}</td>
      <td data-label="المُرسِل">${m.sender_name||m.from||'-'}<br><small style="color:#888">${m.phone||m.email||''}</small></td>
      <td data-label="الرسالة">${(m.subject||m.message||'').substring(0,60)}${(m.subject||m.message||'').length>60?'...':''}</td>
      <td data-label="الحالة"><span class="badge ${m.status==='read'?'badge-green':'badge-yellow'}">${m.status==='read'?'مقروء':'غير مقروء'}</span></td>
      <td data-label="التاريخ">${m.created_at?new Date(m.created_at).toLocaleDateString('ar'):'–'}</td>
      <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
        ${m.status!=='read'?`<button class="btn-action btn-approve btn-sm" onclick="markMessageRead(${m.id})">تحديد كمقروء</button>`:''}
      </div></td>
    </tr>`).join('') : '';
    main.innerHTML = pageHeader('الرسائل والدعم','رسائل الدعم الفني الواردة من المستخدمين.',
      `<button class="btn-white" onclick="renderMessagesSupport()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container"><table>
        <thead><tr><th>#</th><th>المُرسِل</th><th>الرسالة</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr></thead>
        <tbody>${rows||`<tr><td colspan="6" class="empty-cell">${emptyHtml('📩','لا توجد رسائل')}</td></tr>`}</tbody>
      </table></div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الرسائل والدعم','') + `<div class="card">${errorHtml(e.message,'renderMessagesSupport')}</div>`;
  }
}
async function markMessageRead(id) {
  try {
    await PATCH(`/admin/messages/${id}`, { status:'read' });
    toast('تم التحديد كمقروء','success'); renderMessagesSupport();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: RATINGS
══════════════════════════════════════════════════════ */
async function renderRatings() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/ratings');
    const list = data.ratings || data.data || data || [];
    const stars = n => '★'.repeat(Math.round(n||0)) + '☆'.repeat(5-Math.round(n||0));
    const rows = Array.isArray(list) ? list.map(r => `<tr>
      <td data-label="#">${r.id||'-'}</td>
      <td data-label="المُقيِّم">${r.reviewer_name||r.from_user||'-'}</td>
      <td data-label="المُقيَّم">${r.target_name||r.to_user||'-'}</td>
      <td data-label="التقييم" style="color:#F59E0B">${stars(r.rating||r.score||0)} (${r.rating||r.score||0})</td>
      <td data-label="التعليق">${(r.comment||r.review||'').substring(0,60)}</td>
      <td data-label="التاريخ">${r.created_at?new Date(r.created_at).toLocaleDateString('ar'):'–'}</td>
    </tr>`).join('') : '';
    main.innerHTML = pageHeader('التقييمات','تقييمات المستخدمين والمكاتب العقارية.',
      `<button class="btn-white" onclick="renderRatings()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container"><table>
        <thead><tr><th>#</th><th>المُقيِّم</th><th>المُقيَّم</th><th>التقييم</th><th>التعليق</th><th>التاريخ</th></tr></thead>
        <tbody>${rows||`<tr><td colspan="6" class="empty-cell">${emptyHtml('⭐','لا توجد تقييمات')}</td></tr>`}</tbody>
      </table></div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('التقييمات','') + `<div class="card">${errorHtml(e.message,'renderRatings')}</div>`;
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: CONTENT PAGES — FIXED endpoint + edit
══════════════════════════════════════════════════════ */
async function renderContentPages() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback([
      '/admin/content-pages',
      '/admin/pages',
      '/admin/static-pages',
      '/content-pages',
    ]);
    const list = data.pages || data.content_pages || data.data || data || [];
    const arrList = Array.isArray(list) ? list : [];
    const rows = arrList.map(p => `<tr>
      <td data-label="#">${p.id||'-'}</td>
      <td data-label="العنوان"><strong>${p.title||p.title_ar||p.name||'-'}</strong></td>
      <td data-label="النوع"><code>${p.type||p.slug||p.key||'-'}</code></td>
      <td data-label="الحالة"><span class="badge ${p.is_active||p.active||p.status==='active'?'badge-green':'badge-red'}">${p.is_active||p.active||p.status==='active'?'منشور':'مخفي'}</span></td>
      <td data-label="آخر تعديل">${p.updated_at?new Date(p.updated_at).toLocaleDateString('ar'):'–'}</td>
      <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
        <button class="btn-action btn-view btn-sm" onclick="editContentPage(${p.id},'${(p.title||p.name||'').replace(/'/g,'')}')">تعديل</button>
      </div></td>
    </tr>`).join('');
    main.innerHTML = pageHeader('إدارة المحتوى','صفحات المحتوى الثابتة (سياسة الخصوصية، الشروط، إلخ).',
      `<button class="btn-white" onclick="renderContentPages()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container"><table>
        <thead><tr><th>#</th><th>العنوان</th><th>النوع</th><th>الحالة</th><th>آخر تعديل</th><th>إجراءات</th></tr></thead>
        <tbody>${rows||`<tr><td colspan="6" class="empty-cell">${emptyHtml('📄','لا توجد صفحات محتوى')}</td></tr>`}</tbody>
      </table></div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('إدارة المحتوى','') + `<div class="card">${errorHtml(e.message,'renderContentPages')}</div>`;
  }
}
async function editContentPage(id, title) {
  try {
    const data = await GET(`/admin/content-pages/${id}`);
    const page = data.page || data.data || data;
    openModal(`تعديل: ${title}`, `
      <div class="form-group"><label>العنوان</label><input type="text" id="cp-title" value="${page.title||page.title_ar||title}"></div>
      <div class="form-group"><label>المحتوى</label><textarea id="cp-content" rows="8" style="font-size:13px;direction:rtl">${page.content||page.body||''}</textarea></div>
      <div class="form-group"><label>الحالة</label>
        <select id="cp-status">
          <option value="1" ${page.is_active||page.active?'selected':''}>منشور</option>
          <option value="0" ${!(page.is_active||page.active)?'selected':''}>مخفي</option>
        </select>
      </div>`,
      async () => {
        const body = {
          title: document.getElementById('cp-title').value.trim(),
          content: document.getElementById('cp-content').value.trim(),
          is_active: document.getElementById('cp-status').value === '1',
        };
        try {
          await PUT(`/admin/content-pages/${id}`, body);
          toast('تم حفظ الصفحة ✅','success');
          closeModal(); renderContentPages();
        } catch(e) {
          try {
            await PATCH(`/admin/content-pages/${id}`, body);
            toast('تم حفظ الصفحة ✅','success');
            closeModal(); renderContentPages();
          } catch(e2) { toast(e2.message,'error'); }
        }
      }
    );
  } catch(e) {
    toast('تعذر تحميل الصفحة: ' + e.message,'error');
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: APP CONFIG — FIXED with edit/save
══════════════════════════════════════════════════════ */
async function renderAppConfig() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback(['/admin/app-config','/admin/app-settings','/admin/config']);
    const cfg = data.config || data.settings || data || {};
    const rows = Object.entries(cfg).map(([k,v]) => `
      <div class="insight-row">
        <span class="insight-label">${k}</span>
        <div style="display:flex;align-items:center;gap:8px">
          <span class="insight-value">${typeof v === 'boolean'
            ? `<span class="badge ${v?'badge-green':'badge-red'}">${v?'مفعّل':'معطّل'}</span>`
            : String(v).substring(0,60)}</span>
          <button class="btn-action btn-view btn-sm" onclick="editAppConfigKey('${k}','${String(v).replace(/'/g,'')}',${typeof v === 'boolean'})">تعديل</button>
        </div>
      </div>`).join('');
    main.innerHTML = pageHeader('إعدادات التطبيق','إعدادات وتكوين التطبيق العامة.',
      `<button class="btn-white" onclick="renderAppConfig()">🔄 تحديث</button>`) +
      `<div class="card"><h3 style="font-size:16px;font-weight:800;margin-bottom:16px">⚙️ إعدادات النظام</h3>
        ${rows || '<p style="color:#6B7280;text-align:center;padding:20px">لا توجد إعدادات</p>'}
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader('إعدادات التطبيق','') + `<div class="card">${errorHtml(e.message,'renderAppConfig')}</div>`;
  }
}
function editAppConfigKey(key, currentValue, isBool) {
  const inputHtml = isBool
    ? `<select id="cfg-val">
        <option value="true" ${currentValue==='true'?'selected':''}>مفعّل</option>
        <option value="false" ${currentValue!=='true'?'selected':''}>معطّل</option>
      </select>`
    : `<input type="text" id="cfg-val" value="${currentValue}">`;
  openModal(`تعديل: ${key}`, `
    <div class="form-group"><label>${key}</label>${inputHtml}</div>`,
    async () => {
      let val = document.getElementById('cfg-val').value;
      if (isBool) val = val === 'true';
      try {
        await PATCH('/admin/app-config', { [key]: val });
        toast('تم حفظ الإعداد ✅','success');
        closeModal(); renderAppConfig();
      } catch(e) {
        try {
          await PUT('/admin/app-config', { [key]: val });
          toast('تم حفظ الإعداد ✅','success');
          closeModal(); renderAppConfig();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
}

/* ══════════════════════════════════════════════════════
   PAGE: APP UPDATES — FIXED with create button
══════════════════════════════════════════════════════ */
async function renderAppUpdates() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback(['/admin/app-updates','/admin/updates','/app-updates']);
    const list = data.updates || data.data || data || [];
    const rows = Array.isArray(list) ? list.map(u => `<tr>
      <td data-label="#">${u.id||'-'}</td>
      <td data-label="الإصدار"><strong>${u.version||'-'}</strong></td>
      <td data-label="المنصة"><span class="badge badge-gold">${u.platform||'-'}</span></td>
      <td data-label="الملاحظات">${(u.notes||u.description||u.release_notes||'').substring(0,60)}</td>
      <td data-label="النوع"><span class="badge ${u.is_forced||u.force_update?'badge-red':'badge-green'}">${u.is_forced||u.force_update?'إجباري':'اختياري'}</span></td>
      <td data-label="التاريخ">${u.created_at?new Date(u.created_at).toLocaleDateString('ar'):'–'}</td>
    </tr>`).join('') : '';
    main.innerHTML = pageHeader('إدارة التحديثات','تحديثات التطبيق للأندرويد والـ iOS.',
      `<button class="btn-white" onclick="showAddUpdateModal()">+ إضافة تحديث</button>`) +
      `<div class="card">
        ${rows ? `<div class="table-container"><table>
          <thead><tr><th>#</th><th>الإصدار</th><th>المنصة</th><th>الملاحظات</th><th>النوع</th><th>التاريخ</th></tr></thead>
          <tbody>${rows}</tbody></table></div>` : emptyHtml('📱','لا توجد تحديثات مسجّلة','أضف أول تحديث للتطبيق')}
      </div>`;
  } catch(e) {
    main.innerHTML = pageHeader('إدارة التحديثات','') + `<div class="card">${errorHtml(e.message,'renderAppUpdates')}</div>`;
  }
}
function showAddUpdateModal() {
  openModal('إضافة تحديث جديد', `
    <div class="form-group"><label>رقم الإصدار</label><input type="text" id="upd-version" placeholder="1.0.0"></div>
    <div class="form-group"><label>المنصة</label>
      <select id="upd-platform">
        <option value="android">Android</option>
        <option value="ios">iOS</option>
        <option value="both">كلاهما</option>
      </select>
    </div>
    <div class="form-group"><label>الملاحظات / ما الجديد</label><textarea id="upd-notes" placeholder="ملاحظات الإصدار..."></textarea></div>
    <div class="form-group"><label>رابط التحديث (URL)</label><input type="url" id="upd-url" placeholder="https://play.google.com/..."></div>
    <div class="form-group">
      <label class="perm-checkbox" onclick="togglePerm(this)" id="upd-forced-label">
        <input type="checkbox" id="upd-forced">
        <div class="perm-check-icon">✓</div>
        <span class="perm-label">تحديث إجباري</span>
      </label>
    </div>`,
    async () => {
      const version = document.getElementById('upd-version').value.trim();
      const platform = document.getElementById('upd-platform').value;
      const notes = document.getElementById('upd-notes').value.trim();
      const url = document.getElementById('upd-url').value.trim();
      const is_forced = document.getElementById('upd-forced').checked;
      if (!version) { toast('أدخل رقم الإصدار','error'); return; }
      try {
        await POST('/admin/app-updates', { version, platform, notes, url, is_forced });
        toast('تمت إضافة التحديث ✅','success');
        closeModal(); renderAppUpdates();
      } catch(e) {
        try {
          await POST('/admin/updates', { version, platform, notes, url, is_forced });
          toast('تمت إضافة التحديث ✅','success');
          closeModal(); renderAppUpdates();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
}

/* ══════════════════════════════════════════════════════
   MODAL SYSTEM
══════════════════════════════════════════════════════ */
let _modalConfirm = null;
function openModal(title, bodyHtml, onConfirm) {
  _modalConfirm = onConfirm;
  const existing = document.getElementById('modal-overlay');
  if (existing) existing.remove();
  const el = document.createElement('div');
  el.id = 'modal-overlay';
  el.className = 'modal-overlay';
  const hasConfirm = typeof onConfirm === 'function';
  el.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <span class="modal-title">${title}</span>
        <button class="modal-close" onclick="closeModal()">✕</button>
      </div>
      <div class="modal-body">${bodyHtml}</div>
      <div class="modal-footer">
        ${hasConfirm
          ? `<button class="btn-action btn-delete" onclick="closeModal()">إلغاء</button>
             <button class="btn-action btn-approve" onclick="confirmModal()" style="padding:10px 20px">تأكيد</button>`
          : `<button class="btn-action btn-approve" onclick="closeModal()" style="padding:10px 20px">إغلاق</button>`}
      </div>
    </div>`;
  document.body.appendChild(el);
  // Close on overlay click
  el.addEventListener('click', e => {
    if (e.target === el) closeModal();
  });
}
function closeModal() {
  const el = document.getElementById('modal-overlay');
  if (el) el.remove();
  _modalConfirm = null;
}
async function confirmModal() {
  if (_modalConfirm) await _modalConfirm();
}

/* ── Mobile Sidebar ────────────────────────────────── */
function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebar-overlay');
  const btn = document.getElementById('hamburger-btn');
  const isOpen = sidebar.classList.contains('open');
  if (isOpen) {
    sidebar.classList.remove('open');
    overlay.classList.add('hidden');
    btn?.setAttribute('aria-expanded', 'false');
  } else {
    sidebar.classList.add('open');
    overlay.classList.remove('hidden');
    btn?.setAttribute('aria-expanded', 'true');
  }
}
function closeSidebar() {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebar-overlay').classList.add('hidden');
  document.getElementById('hamburger-btn')?.setAttribute('aria-expanded', 'false');
}

/* ══════════════════════════════════════════════════════
   PAGE: USER GUIDE
══════════════════════════════════════════════════════ */
function renderUserGuide() {
  const main = document.getElementById('main-content');

  const sections = [
    {
      icon: '📊',
      title: 'لوحة التحكم الرئيسية',
      desc: 'نظرة شاملة على جميع مؤشرات الأداء',
      content: `
        <p class="guide-content">تعرض لوحة التحكم الرئيسية أهم إحصائيات المنصة في الوقت الفعلي:</p>
        <ul class="guide-content">
          <li><strong>إجمالي العقارات</strong> — العدد الكلي للعقارات المسجلة</li>
          <li><strong>العقارات النشطة</strong> — العقارات المعروضة حالياً</li>
          <li><strong>بانتظار المراجعة</strong> — عقارات تحتاج موافقة</li>
          <li><strong>المستخدمون</strong> — الملاك، المكاتب، الباحثون</li>
          <li><strong>المشرفون</strong> — أعضاء الفريق الإداري</li>
        </ul>
      `
    },
    {
      icon: '🏠',
      title: 'إدارة العقارات',
      desc: 'مراجعة وإدارة جميع العقارات المسجلة',
      content: `
        <p class="guide-content">من قسم <strong>العقارات</strong> يمكنك:</p>
        <ol class="guide-steps">
          <li>عرض صورة مصغرة لكل عقار — اضغطها لعرض الصور الكاملة</li>
          <li>الموافقة على العقارات الجديدة أو رفضها</li>
          <li>تمييز عقارات بالضغط على زر "تمييز ⭐"</li>
          <li>إلغاء التمييز أو حذف العقارات المخالفة</li>
          <li>عرض تفاصيل العقار الكاملة مع صوره</li>
        </ol>
      `
    },
    {
      icon: '👤',
      title: 'إدارة المستخدمين',
      desc: 'الملاك، المكاتب العقارية، والباحثون',
      content: `
        <p class="guide-content">يشمل قسم المستخدمين ثلاثة أنواع:</p>
        <ul class="guide-content">
          <li><strong>الملاك 👤</strong> — اضغط "الملف الشخصي" لعرض صور الهوية وبيانات الحساب</li>
          <li><strong>المكاتب العقارية 🏢</strong> — عرض صور الهوية، السجل التجاري، توثيق/إلغاء توثيق المكتب</li>
          <li><strong>الباحثون 🔍</strong> — قبول/رفض/إيقاف/حذف الحسابات</li>
        </ul>
        <p class="guide-content">اضغط زر "⋮ المزيد" لرؤية خيارات إضافية لكل مستخدم.</p>
      `
    },
    {
      icon: '👮',
      title: 'المشرفون والصلاحيات',
      desc: 'إدارة المشرفين وتعيين 11 نوع من الصلاحيات',
      content: `
        <p class="guide-content">يمكنك تعيين أي مجموعة من الصلاحيات الـ 11 لكل مشرف:</p>
        <ul class="guide-content" style="display:grid;grid-template-columns:1fr 1fr;gap:4px">
          <li>إدارة العقارات</li><li>إدارة المستخدمين</li>
          <li>إدارة الاشتراكات</li><li>إدارة الطلبات</li>
          <li>إدارة الإعدادات</li><li>إدارة الموظفين</li>
          <li>إدارة المدن</li><li>إدارة الإعلانات</li>
          <li>إدارة التقارير</li><li>إدارة المحتوى</li>
          <li>إدارة الأمان</li>
        </ul>
        <p class="guide-content" style="margin-top:8px">المشرفون يدخلون عبر OTP مثل الأدمن.</p>
      `
    },
    {
      icon: '📦',
      title: 'الباقات والاشتراكات',
      desc: 'إدارة باقات الاشتراك والاشتراكات اليدوية',
      content: `
        <p class="guide-content">نظام اشتراك <strong>يدوي بالكامل بدون دفع إلكتروني</strong>:</p>
        <ol class="guide-steps">
          <li>من <strong>الباقات 📦</strong>: أضف/عدّل/احذف الباقات مع تحديد السعر والمدة وحدود العقارات والموظفين</li>
          <li>من <strong>الاشتراكات 🌟</strong>: استقبل طلبات الاشتراك وقبّلها أو ارفضها أو فعّلها أو ألغِها</li>
        </ol>
      `
    },
    {
      icon: '✅',
      title: 'إدارة التوثيق',
      desc: 'طلبات توثيق الهوية مع عرض الصور',
      content: `
        <p class="guide-content">من <strong>طلبات التوثيق ✅</strong>:</p>
        <ol class="guide-steps">
          <li>اضغط "📷 الصور" لعرض وثائق الهوية المرفوعة</li>
          <li>قبول الطلب (يصبح الحساب "موثقاً")</li>
          <li>رفض الطلب مع ذكر السبب</li>
          <li>طلب إعادة رفع المستندات إذا كانت غير واضحة</li>
        </ol>
      `
    },
    {
      icon: '🔒',
      title: 'إدارة الأمان',
      desc: 'حظر المستخدمين وسجل العمليات الأمنية',
      content: `
        <p class="guide-content">تتضمن صفحة الأمان قسمين:</p>
        <ul class="guide-content">
          <li><strong>المستخدمون المحظورون</strong> — عرض وإدارة حظر/إلغاء حظر المستخدمين</li>
          <li><strong>سجل العمليات الأمنية</strong> — تتبع جميع الإجراءات الأمنية مع IP والتاريخ</li>
        </ul>
      `
    },
    {
      icon: '❓',
      title: 'الأسئلة الشائعة',
      desc: 'أجوبة على أكثر الأسئلة تكراراً',
      content: null,
      faq: [
        { q: 'كيف أقبل عقاراً جديداً؟', a: 'اذهب إلى قسم العقارات → اضغط زر "قبول" بجانب العقار المطلوب.' },
        { q: 'كيف أمنح مشرفاً صلاحيات متعددة؟', a: 'اذهب إلى المشرفون والصلاحيات → اضغط "تعديل الصلاحيات" → ضع علامة على الصلاحيات المطلوبة من قائمة الـ 11 صلاحية → اضغط تأكيد.' },
        { q: 'كيف أعرض صور هوية المستخدم؟', a: 'اذهب إلى قسم الملاك أو المكاتب → اضغط "الملف الشخصي" → ستجد صور الهوية في أسفل النافذة.' },
        { q: 'كيف أوثق مكتباً عقارياً؟', a: 'اذهب إلى المكاتب العقارية → اضغط "⋮ المزيد" بجانب المكتب → اختر "توثيق المكتب".' },
        { q: 'كيف أطلب إعادة رفع وثائق توثيق؟', a: 'اذهب إلى طلبات التوثيق → اضغط "إعادة رفع" → أدخل رسالة للمستخدم.' },
        { q: 'كيف أضيف إعلاناً جديداً؟', a: 'اذهب إلى الإعلانات → اضغط "+ إضافة إعلان" → أدخل العنوان ورابط الصورة والرابط الوجهة.' },
        { q: 'كيف أعمل نسخة احتياطية؟', a: 'اذهب إلى النسخ الاحتياطي → اضغط "إنشاء نسخة احتياطية". بعد الإنشاء يمكنك تنزيلها أو استعادتها.' },
        { q: 'هل يعمل التطبيق بدون إنترنت؟', a: 'لوحة الإدارة تعمل offline جزئياً — يمكن عرض الصفحات المحملة مسبقاً، لكن البيانات الحية تتطلب اتصالاً.' },
      ]
    },
  ];

  const renderSection = (s, i) => {
    const contentHtml = s.content ? `<div class="guide-content">${s.content}</div>` : '';
    const faqHtml = s.faq ? s.faq.map((f,j) => `
      <div class="guide-faq-item">
        <div class="guide-faq-q" onclick="toggleFaq(this)" role="button" tabindex="0">
          <span>${f.q}</span>
          <span class="faq-arrow">▼</span>
        </div>
        <div class="guide-faq-a">${f.a}</div>
      </div>`).join('') : '';
    return `
      <div class="guide-section" id="guide-${i}">
        <div class="guide-section-header">
          <div class="guide-icon">${s.icon}</div>
          <div>
            <div class="guide-section-title">${s.title}</div>
            <div class="guide-section-desc">${s.desc}</div>
          </div>
        </div>
        ${contentHtml}
        ${faqHtml}
      </div>`;
  };

  main.innerHTML = pageHeader('دليل الاستخدام','الشرح الكامل لجميع أقسام لوحة الإدارة.') +
    `<div class="card" style="margin-bottom:20px;padding:20px 22px">
      <p style="font-size:14px;color:#52606D;line-height:1.7">
        📖 هذا الدليل يشرح كيفية استخدام جميع أقسام <strong>Aqari Plus Admin</strong> — لوحة إدارة منصة عقاري بلس.
        اضغط على أي قسم لعرض التفاصيل.
      </p>
    </div>` +
    sections.map((s, i) => renderSection(s, i)).join('');
}

function toggleFaq(el) {
  const answer = el.nextElementSibling;
  const isOpen = answer.classList.contains('open');
  document.querySelectorAll('.guide-faq-a.open').forEach(a => {
    a.classList.remove('open');
    a.previousElementSibling.classList.remove('open');
  });
  if (!isOpen) {
    answer.classList.add('open');
    el.classList.add('open');
  }
}

/* ── Welcome Screen (First-Run) ───────────────────────── */
function showWelcomeIfFirstRun() {
  const seen = localStorage.getItem('aqari_admin_welcome_seen');
  if (!seen) {
    const modal = document.getElementById('welcome-modal');
    if (modal) modal.classList.remove('hidden');
    if (/iphone|ipad|ipod/i.test(navigator.userAgent)) {
      const hint = document.getElementById('ios-install-hint');
      if (hint) hint.style.display = 'block';
    }
    localStorage.setItem('aqari_admin_welcome_seen', '1');
  }
}

function closeWelcome() {
  const modal = document.getElementById('welcome-modal');
  if (modal) {
    modal.style.opacity = '0';
    modal.style.transition = 'opacity .3s';
    setTimeout(() => {
      modal.classList.add('hidden');
      modal.style.opacity = '';
      modal.style.transition = '';
    }, 300);
  }
}

/* ── Boot ────────────────────────────────────────────── */
window.addEventListener('DOMContentLoaded', () => {
  showWelcomeIfFirstRun();

  if (Session.token && Session.role &&
      ['admin','super_admin','supervisor'].includes(Session.role)) {
    initAdminPanel();
  }

  const hash = window.location.hash.replace('#','');
  if (hash && Session.token && ['admin','super_admin','supervisor'].includes(Session.role||'')) {
    setTimeout(() => navigateTo(hash), 150);
  }

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
      closeModal();
      closeSidebar();
    }
  });

  let touchStartX = 0;
  document.addEventListener('touchstart', e => {
    touchStartX = e.changedTouches[0].screenX;
  }, { passive: true });
  document.addEventListener('touchend', e => {
    const dx = e.changedTouches[0].screenX - touchStartX;
    const sidebar = document.getElementById('sidebar');
    if (!sidebar) return;
    if (dx > 60 && sidebar.classList.contains('open')) {
      closeSidebar();
    } else if (dx < -60 && !sidebar.classList.contains('open')) {
      toggleSidebar();
    }
  }, { passive: true });
});
