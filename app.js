/* ═══════════════════════════════════════════════════════
   Aqari Plus Admin Panel — Production SPA
   Backend: https://aqari-backend.onrender.com/api
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
  { label:'لوحة التحكم',         route:'dashboard',        perm: null,                   icon:'📊' },
  { label:'العقارات',             route:'properties',       perm:'manage_properties',     icon:'🏠' },
  { label:'الملاك',               route:'owners',           perm:'manage_users',          icon:'👤' },
  { label:'المكاتب العقارية',     route:'offices',          perm:'manage_users',          icon:'🏢' },
  { label:'الباحثون',             route:'seekers',          perm:'manage_users',          icon:'🔍' },
  { label:'طلبات الباحثين',       route:'seeker-requests',  perm:'manage_requests',       icon:'📋' },
  { label:'المشرفون والصلاحيات', route:'supervisors',      perm:'manage_users',          icon:'👮' },
  { label:'الباقات والاشتراكات',  route:'subscriptions',    perm:'manage_subscriptions',  icon:'⭐' },
  { label:'مراجعة المدفوعات',     route:'payment-reviews',  perm:'manage_subscriptions',  icon:'💳' },
  { label:'طلبات التوثيق',        route:'verifications',    perm:'manage_users',          icon:'✅' },
  { label:'إدارة الموظفين',       route:'all-employees',    perm:'manage_employees',      icon:'👔' },
  { label:'الإشعارات',            route:'notifications',    perm:'manage_settings',       icon:'🔔' },
  { label:'إدارة المحادثات',      route:'chats-management', perm:'manage_requests',       icon:'💬' },
  { label:'التقارير والإحصائيات', route:'reports',          perm:'manage_settings',       icon:'📈' },
  { label:'سجل الأنشطة',          route:'activity-logs',    perm:'manage_settings',       icon:'📜' },
  { label:'الإعدادات',            route:'settings',         perm:'manage_settings',       icon:'⚙️' },
  { label:'المواقع الجغرافية',    route:'locations',        perm:'manage_cities',         icon:'📍' },
  { label:'أنواع العقارات',       route:'property-types',   perm:'manage_settings',       icon:'🏗️' },
  { label:'مراقبة النظام',        route:'monitoring',       perm:'manage_settings',       icon:'🖥️' },
  { label:'الإعلانات',            route:'ads',              perm:'manage_settings',       icon:'📣' },
  { label:'إدارة الأمان',         route:'security',         perm:'manage_settings',       icon:'🔒' },
  { label:'مركز الطوارئ',         route:'emergency',        perm:'manage_settings',       icon:'🚨' },
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
  // Update active nav item
  document.querySelectorAll('.nav-item').forEach(el => {
    const isActive = el.dataset.route === route;
    el.classList.toggle('active', isActive);
    el.querySelector('.nav-dot')?.classList.toggle('hidden', !isActive);
  });
  // Render page
  const main = document.getElementById('main-content');
  const pages = {
    'dashboard':       renderDashboard,
    'properties':      () => renderUsersTable('properties'),
    'owners':          () => renderUsersTable('owners'),
    'offices':         () => renderUsersTable('offices'),
    'seekers':         () => renderUsersTable('seekers'),
    'seeker-requests': renderSeekerRequests,
    'supervisors':     renderSupervisors,
    'subscriptions':   renderSubscriptions,
    'payment-reviews': renderPaymentReviews,
    'verifications':   renderVerifications,
    'all-employees':   renderAllEmployees,
    'notifications':   renderNotifications,
    'chats-management':renderChats,
    'reports':         renderReports,
    'activity-logs':   renderActivityLogs,
    'settings':        renderSettings,
    'locations':       renderLocations,
    'property-types':  renderPropertyTypes,
    'monitoring':      renderMonitoring,
    'ads':             renderAds,
    'security':        renderSecurity,
    'emergency':       renderEmergency,
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
  return `<div class="empty-state"><div class="empty-icon">⚠️</div><h3>خطأ</h3><p>${msg}</p>${retry?`<br><button class="btn-action btn-view" onclick="${retry}()">إعادة المحاولة</button>`:''}</div>`;
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

/* ══════════════════════════════════════════════════════
   PAGE: DASHBOARD
══════════════════════════════════════════════════════ */
async function renderDashboard() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/stats');
    const s = data;
    const cards = [
      { icon:'🏠', label:'إجمالي العقارات',    value: fmtNum(s.totalProperties||s.total_properties),    color:'#1D7CF2' },
      { icon:'✅', label:'العقارات النشطة',    value: fmtNum(s.activeProperties||s.active_properties),  color:'#17B26A' },
      { icon:'⏳', label:'بانتظار المراجعة',   value: fmtNum(s.pendingProperties||s.pending_properties),color:'#F39C12' },
      { icon:'⭐', label:'العقارات المميزة',    value: fmtNum(s.featuredProperties||s.featured_properties),color:'#9A6B00' },
      { icon:'🔑', label:'المؤجرة',            value: fmtNum(s.rentedProperties||s.rented_properties),  color:'#7B61FF' },
      { icon:'💰', label:'المُباعة',           value: fmtNum(s.soldProperties||s.sold_properties),      color:'#DE6C3D' },
      { icon:'👤', label:'الملاك',             value: fmtNum((s.users_by_role||{}).owner||s.ownersCount||s.owners_count||0), color:'#0F9D90' },
      { icon:'🏢', label:'المكاتب',            value: fmtNum((s.users_by_role||{}).office||s.officesCount||s.offices_count||0), color:'#7B61FF' },
      { icon:'🔍', label:'الباحثون',           value: fmtNum((s.users_by_role||{}).seeker||s.seekersCount||s.seekers_count||0), color:'#1D7CF2' },
      { icon:'👮', label:'المشرفون',           value: fmtNum(s.supervisorsCount||s.supervisors_count||0), color:'#0B3A66' },
    ];
    const grid = cards.map(c => `
      <div class="stat-card">
        <div class="stat-icon" style="background:${c.color}20">${c.icon}</div>
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
   PAGE: PROPERTIES / USERS (generic table)
══════════════════════════════════════════════════════ */
const PAGE_CFG = {
  properties: {
    title:'العقارات', subtitle:'إدارة ومراجعة جميع العقارات.', endpoint:'/admin/properties',
    cols: ['العنوان','النوع','العملية','المدينة','السعر','الحالة','التاريخ','الإجراءات'],
    row: (p, perm) => [
      p.title||p.property_type||'عقار',
      p.property_type||'—', p.operation_type||p.offer_type||'—',
      p.city||'—',
      fmtNum(p.price)+(p.currency?' '+p.currency:''),
      badgeForStatus(p.status),
      fmtDate(p.created_at),
      perm?`<button class="btn-action btn-approve btn-sm" onclick="approveProperty(${p.id})">موافقة</button>
            <button class="btn-action btn-reject btn-sm" onclick="rejectProperty(${p.id})">رفض</button>
            <button class="btn-action btn-delete btn-sm" onclick="deleteProperty(${p.id})">حذف</button>`:'—'
    ]
  },
  owners: {
    title:'الملاك', subtitle:'إدارة حسابات الملاك.', endpoint:'/admin/users?role=owner',
    cols: ['الاسم','الهاتف','الحالة','العقارات','تاريخ التسجيل'],
    row: p => [p.name||p.full_name||'—', p.phone||'—', badgeForStatus(p.status||'active'), fmtNum(p.properties_count||0), fmtDate(p.created_at)]
  },
  offices: {
    title:'المكاتب العقارية', subtitle:'إدارة حسابات المكاتب.', endpoint:'/admin/users?role=office',
    cols: ['الاسم','الهاتف','الحالة','الموظفون','تاريخ التسجيل'],
    row: p => [p.name||p.full_name||'—', p.phone||'—', badgeForStatus(p.status||'active'), fmtNum(p.employees_count||0), fmtDate(p.created_at)]
  },
  seekers: {
    title:'الباحثون', subtitle:'إدارة حسابات الباحثين.', endpoint:'/admin/users?role=seeker',
    cols: ['الاسم','الهاتف','الحالة','تاريخ التسجيل'],
    row: p => [p.name||p.full_name||'—', p.phone||'—', badgeForStatus(p.status||'active'), fmtDate(p.created_at)]
  },
};

async function renderUsersTable(type) {
  const main = document.getElementById('main-content');
  const cfg  = PAGE_CFG[type];
  const perm = Session.hasPerm(cfg.endpoint.includes('admin/properties')?'manage_properties':'manage_users');
  try {
    let data = await GET(cfg.endpoint);
    let rows = data[type]||data.properties||data.users||data.data||data||[];
    if (!Array.isArray(rows)) rows = [];

    const thead = `<tr>${cfg.cols.map(c=>`<th>${c}</th>`).join('')}</tr>`;
    const tbody = rows.length
      ? rows.map(r => `<tr>${cfg.row(r,perm).map(c=>`<td>${c}</td>`).join('')}</tr>`).join('')
      : `<tr><td colspan="${cfg.cols.length}">${emptyHtml('📂','لا توجد بيانات')}</td></tr>`;

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

/* ── Property Actions ─────────────────────────────────── */
async function approveProperty(id) {
  if (!confirm('هل تريد الموافقة على هذا العقار؟')) return;
  try {
    await PATCH(`/admin/properties/${id}/status`, { status:'approved' });
    toast('تمت الموافقة على العقار ✅','success');
    renderUsersTable('properties');
  } catch(e) { toast(e.message,'error'); }
}
async function rejectProperty(id) {
  const reason = prompt('سبب الرفض (اختياري):');
  if (reason === null) return;
  try {
    await PATCH(`/admin/properties/${id}/status`, { status:'rejected', rejection_reason:reason });
    toast('تم رفض العقار','success');
    renderUsersTable('properties');
  } catch(e) { toast(e.message,'error'); }
}
async function deleteProperty(id) {
  if (!confirm('هل تريد حذف هذا العقار نهائياً؟')) return;
  try {
    await DEL(`/admin/properties/${id}`);
    toast('تم حذف العقار','success');
    renderUsersTable('properties');
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
          <td>${r.id}</td>
          <td>${r.user_name||r.seeker_name||r.phone||'—'}</td>
          <td>${r.city||'—'}</td>
          <td>${r.property_type||'—'}</td>
          <td>${fmtNum(r.budget)||fmtNum(r.max_price)||'—'}</td>
          <td>${badgeForStatus(r.status||'active')}</td>
          <td>${fmtDate(r.created_at)}</td>
          <td><button class="btn-action btn-delete btn-sm" onclick="deleteRequest(${r.id})">حذف</button></td>
        </tr>`).join('')
      : `<tr><td colspan="8">${emptyHtml('📋','لا توجد طلبات')}</td></tr>`;
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
   PAGE: SUPERVISORS
══════════════════════════════════════════════════════ */
const PERM_LABELS = {
  manage_properties:   'إدارة العقارات',
  manage_users:        'إدارة المستخدمين',
  manage_subscriptions:'إدارة الاشتراكات',
  manage_requests:     'إدارة الطلبات',
  manage_settings:     'إدارة الإعدادات',
  manage_employees:    'إدارة الموظفين',
  manage_cities:       'إدارة المدن',
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
            <td><strong>${r.name||'—'}</strong></td>
            <td>${r.phone||'—'}</td>
            <td style="max-width:260px">${perms.map(p=>`<span class="badge badge-blue" style="margin:2px">${PERM_LABELS[p]||p}</span>`).join(' ')||'لا توجد صلاحيات'}</td>
            <td>${fmtDate(r.created_at)}</td>
            <td>
              <button class="btn-action btn-view btn-sm" onclick="editSupervisor(${r.id},'${r.name}','${r.phone}',${JSON.stringify(perms)})">تعديل</button>
              <button class="btn-action btn-delete btn-sm" onclick="deleteSupervisor(${r.id})">حذف</button>
            </td>
          </tr>`;
        }).join('')
      : `<tr><td colspan="5">${emptyHtml('👮','لا يوجد مشرفون','أضف مشرفاً أولاً')}</td></tr>`;
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

function showAddSupervisorModal() {
  openModal('إضافة مشرف جديد', `
    <div class="form-group"><label>الاسم</label><input type="text" id="sup-name" placeholder="اسم المشرف"></div>
    <div class="form-group"><label>رقم الهاتف</label><input type="tel" id="sup-phone" placeholder="967xxxxxxxxx"></div>
    <div class="form-group"><label>كلمة المرور</label><input type="password" id="sup-pass" placeholder="6 أحرف على الأقل"></div>
    <div class="form-group"><label>الصلاحيات</label>
      <div class="perms-grid" id="perms-grid">
        ${ALL_PERMS.map(p=>`
          <label class="perm-checkbox" onclick="togglePerm(this)">
            <input type="checkbox" name="perm" value="${p}">
            <div class="perm-check-icon">✓</div>
            <span class="perm-label">${PERM_LABELS[p]}</span>
          </label>`).join('')}
      </div>
    </div>`,
    async () => {
      const name  = document.getElementById('sup-name').value.trim();
      const phone = document.getElementById('sup-phone').value.trim();
      const pass  = document.getElementById('sup-pass').value.trim();
      const perms = [...document.querySelectorAll('#perms-grid input:checked')].map(i=>i.value);
      if (!name||!phone||!pass) { toast('أكمل جميع الحقول','error'); return; }
      if (pass.length < 6) { toast('كلمة المرور 6 أحرف على الأقل','error'); return; }
      try {
        await POST('/admin/supervisors', { name, phone, password:pass, permissions:perms });
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
  openModal('تعديل صلاحيات المشرف', `
    <div class="form-group"><label>الصلاحيات</label>
      <div class="perms-grid" id="perms-grid-edit">
        ${ALL_PERMS.map(p=>`
          <label class="perm-checkbox${currentPerms.includes(p)?' checked':''}" onclick="togglePerm(this)">
            <input type="checkbox" name="perm" value="${p}" ${currentPerms.includes(p)?'checked':''}>
            <div class="perm-check-icon">✓</div>
            <span class="perm-label">${PERM_LABELS[p]}</span>
          </label>`).join('')}
      </div>
    </div>`,
    async () => {
      const perms = [...document.querySelectorAll('#perms-grid-edit input:checked')].map(i=>i.value);
      try {
        await PUT(`/admin/supervisors/${id}/permissions`, { permissions:perms });
        toast('تم تحديث الصلاحيات ✅','success');
        closeModal(); renderSupervisors();
      } catch(e) { toast(e.message,'error'); }
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
   PAGE: SUBSCRIPTIONS
══════════════════════════════════════════════════════ */
async function renderSubscriptions() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/subscriptions');
    const rows = data.subscriptions||data.data||[];
    const thead = `<tr><th>المكتب/المستخدم</th><th>الباقة</th><th>الحالة</th><th>تاريخ الانتهاء</th><th>تاريخ الإنشاء</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td>${r.user_name||r.office_name||r.user_id||'—'}</td>
          <td>${r.package_name||r.plan_type||r.packageType||'—'}</td>
          <td>${badgeForStatus(r.status||'active')}</td>
          <td>${fmtDate(r.expiry_date||r.expires_at)}</td>
          <td>${fmtDate(r.created_at)}</td>
        </tr>`).join('')
      : `<tr><td colspan="5">${emptyHtml('⭐','لا توجد اشتراكات')}</td></tr>`;
    main.innerHTML = pageHeader('الباقات والاشتراكات','إدارة اشتراكات المكاتب.',
      `<button class="btn-white" onclick="showManualSubModal()">+ اشتراك يدوي</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الباقات والاشتراكات','') +
      `<div class="card">${errorHtml(e.message,'renderSubscriptions')}</div>`;
  }
}
function showManualSubModal() {
  openModal('إنشاء اشتراك يدوي', `
    <div class="form-group"><label>معرف المستخدم (userId)</label><input type="number" id="sub-userid"></div>
    <div class="form-group"><label>نوع الباقة (packageType)</label>
      <select id="sub-type"><option value="gold">Gold</option><option value="silver">Silver</option><option value="employee_slots">Slots موظف</option></select>
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
          <td>${r.user_name||r.user_id||'—'} <br><small style="color:#6B7280">${r.user_phone||''}</small></td>
          <td><code>${r.transaction_ref||'—'}</code></td>
          <td>${r.package_name||r.package_id||r.payment_type||'—'}</td>
          <td>${r.amount?fmtNum(r.amount)+' '+(r.currency||'USD'):'—'}</td>
          <td>${badgeForStatus(r.status)}</td>
          <td>${fmtDate(r.created_at)}</td>
          <td>${r.status==='pending'?`
            <button class="btn-action btn-approve btn-sm" onclick="approvePayment(${r.id})">موافقة</button>
            <button class="btn-action btn-reject btn-sm" onclick="rejectPayment(${r.id})">رفض</button>`:'—'}
          </td>
        </tr>`).join('')
      : `<tr><td colspan="7">${emptyHtml('💳','لا توجد مدفوعات معلقة')}</td></tr>`;
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
   PAGE: VERIFICATIONS
══════════════════════════════════════════════════════ */
async function renderVerifications() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/verification');
    const rows = data.verifications||data.data||[];
    const thead = `<tr><th>المستخدم</th><th>الدور</th><th>نوع الوثيقة</th><th>الحالة</th><th>تاريخ الإرسال</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td>${r.user_name||r.user_id||'—'}</td>
          <td>${r.user_role||'—'}</td>
          <td>${r.doc_type||'—'}</td>
          <td>${badgeForStatus(r.status)}</td>
          <td>${fmtDate(r.submitted_at)}</td>
          <td>${r.status==='pending'?`
            <button class="btn-action btn-approve btn-sm" onclick="approveVerif(${r.id})">موافقة</button>
            <button class="btn-action btn-reject btn-sm" onclick="rejectVerif(${r.id})">رفض</button>`:'—'}
          </td>
        </tr>`).join('')
      : `<tr><td colspan="6">${emptyHtml('✅','لا توجد طلبات توثيق معلقة')}</td></tr>`;
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
    await PUT(`/admin/verification/${id}`, { status:'approved', admin_note:note });
    toast('تمت الموافقة على التوثيق ✅','success');
    renderVerifications();
  } catch(e) { toast(e.message,'error'); }
}
async function rejectVerif(id) {
  const note = prompt('سبب الرفض:');
  if (note === null) return;
  try {
    await PUT(`/admin/verification/${id}`, { status:'rejected', admin_note:note });
    toast('تم رفض طلب التوثيق','success');
    renderVerifications();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: ALL EMPLOYEES
══════════════════════════════════════════════════════ */
async function renderAllEmployees() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/all-employees');
    const rows = data.employees||data.data||[];
    const thead = `<tr><th>الاسم</th><th>الهاتف</th><th>الحالة</th><th>المكتب</th><th>تاريخ الإضافة</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td>${r.name||'—'}</td>
          <td>${r.phone||'—'}</td>
          <td>${badgeForStatus(r.status||'active')}</td>
          <td>${r.office_name||r.office_id||'—'}</td>
          <td>${fmtDate(r.created_at)}</td>
          <td>
            <button class="btn-action btn-view btn-sm" onclick="toggleEmployee(${r.id})">${r.status==='active'?'تعطيل':'تفعيل'}</button>
            <button class="btn-action btn-delete btn-sm" onclick="deleteEmployee(${r.id})">حذف</button>
          </td>
        </tr>`).join('')
      : `<tr><td colspan="6">${emptyHtml('👔','لا يوجد موظفون')}</td></tr>`;
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
async function toggleEmployee(id) {
  try {
    await PATCH(`/admin/all-employees/${id}/toggle`, {});
    toast('تم تحديث حالة الموظف ✅','success');
    renderAllEmployees();
  } catch(e) { toast(e.message,'error'); }
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
          <td><strong>${r.title||'—'}</strong></td>
          <td>${r.message||'—'}</td>
          <td><span class="badge badge-blue">${r.target_role||'الكل'}</span></td>
          <td>${fmtDate(r.created_at)}</td>
        </tr>`).join('')
      : `<tr><td colspan="4">${emptyHtml('🔔','لا توجد إشعارات')}</td></tr>`;
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
   PAGE: CHATS
══════════════════════════════════════════════════════ */
async function renderChats() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/chats');
    const rows = data.rooms||data.data||data||[];
    const thead = `<tr><th>رقم الغرفة</th><th>المشاركون</th><th>آخر رسالة</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td>#${r.id}</td>
          <td>${r.participant_a_name||r.participant_a||'—'} ↔ ${r.participant_b_name||r.participant_b||'—'}</td>
          <td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${r.last_message||'لا توجد رسائل'}</td>
          <td>${badgeForStatus(r.status||'open')}</td>
          <td>${fmtDate(r.created_at)}</td>
          <td>
            <button class="btn-action btn-delete btn-sm" onclick="deleteChat(${r.id})">حذف</button>
          </td>
        </tr>`).join('')
      : `<tr><td colspan="6">${emptyHtml('💬','لا توجد محادثات')}</td></tr>`;
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
          <td><span class="badge badge-blue">${r.action||r.event||'—'}</span></td>
          <td>${r.user_name||r.admin_name||r.user_id||'—'}</td>
          <td style="max-width:300px;overflow:hidden;text-overflow:ellipsis">${r.details||r.description||JSON.stringify(r.data||{}).slice(0,80)}</td>
          <td>${fmtDate(r.created_at)}</td>
        </tr>`).join('')
      : `<tr><td colspan="4">${emptyHtml('📜','لا توجد سجلات')}</td></tr>`;
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
   PAGE: SETTINGS
══════════════════════════════════════════════════════ */
async function renderSettings() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/settings');
    const settings = data.settings||data||{};
    const rows = Object.entries(settings).map(([k,v])=>
      `<div class="insight-row">
        <span class="insight-label">${k}</span>
        <span class="insight-value">${typeof v==='object'?JSON.stringify(v).slice(0,60):String(v)}</span>
      </div>`
    ).join('');
    main.innerHTML = pageHeader('الإعدادات','إعدادات التطبيق العامة.',
      `<button class="btn-white" onclick="renderSettings()">🔄 تحديث</button>`) +
      `<div class="card"><h3 style="font-size:16px;font-weight:800;margin-bottom:16px">الإعدادات الحالية</h3>${rows||'<p style="color:#6B7280">لا توجد إعدادات</p>'}</div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الإعدادات','') +
      `<div class="card">${errorHtml(e.message,'renderSettings')}</div>`;
  }
}

/* ══════════════════════════════════════════════════════
   PAGE: LOCATIONS
══════════════════════════════════════════════════════ */
async function renderLocations() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/locations/cities');
    const rows = data.cities||data.data||data||[];
    const thead = `<tr><th>المدينة</th><th>المحافظة</th><th>الإجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td>${r.name||r.city_name||'—'}</td>
          <td>${r.governorate||r.governorate_name||'—'}</td>
          <td><button class="btn-action btn-delete btn-sm" onclick="deleteCity(${r.id})">حذف</button></td>
        </tr>`).join('')
      : `<tr><td colspan="3">${emptyHtml('📍','لا توجد مدن')}</td></tr>`;
    main.innerHTML = pageHeader('المواقع الجغرافية','إدارة المدن والمناطق.',
      `<button class="btn-white" onclick="showAddCityModal()">+ إضافة مدينة</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('المواقع الجغرافية','') +
      `<div class="card">${errorHtml(e.message,'renderLocations')}</div>`;
  }
}
function showAddCityModal() {
  openModal('إضافة مدينة', `
    <div class="form-group"><label>اسم المدينة</label><input type="text" id="city-name" placeholder="مثال: صنعاء"></div>
    <div class="form-group"><label>المحافظة</label><input type="text" id="city-gov" placeholder="مثال: أمانة العاصمة"></div>`,
    async () => {
      const name = document.getElementById('city-name').value.trim();
      const governorate = document.getElementById('city-gov').value.trim();
      if (!name) { toast('أدخل اسم المدينة','error'); return; }
      try {
        await POST('/admin/locations/cities', { name, governorate });
        toast('تمت إضافة المدينة ✅','success');
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
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: PROPERTY TYPES
══════════════════════════════════════════════════════ */
async function renderPropertyTypes() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/property-types');
    const rows = data.types||data.property_types||data.data||data||[];
    const thead = `<tr><th>النوع</th><th>الوصف</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td>${r.name||r.type_name||'—'}</td>
          <td>${r.description||'—'}</td>
          <td><button class="btn-action btn-delete btn-sm" onclick="deletePropertyType(${r.id})">حذف</button></td>
        </tr>`).join('')
      : `<tr><td colspan="3">${emptyHtml('🏗️','لا توجد أنواع عقارات')}</td></tr>`;
    main.innerHTML = pageHeader('أنواع العقارات','إدارة أنواع العقارات المتاحة.',
      `<button class="btn-white" onclick="renderPropertyTypes()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('أنواع العقارات','') +
      `<div class="card">${errorHtml(e.message,'renderPropertyTypes')}</div>`;
  }
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
   PAGE: ADS
══════════════════════════════════════════════════════ */
async function renderAds() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/ads');
    const rows = data.ads||data.data||[];
    const thead = `<tr><th>العنوان</th><th>الرابط</th><th>الحالة</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td>${r.title||'—'}</td>
          <td><a href="${r.url||'#'}" target="_blank" style="color:#1D7CF2">${r.url||'—'}</a></td>
          <td>${badgeForStatus(r.status||'active')}</td>
          <td><button class="btn-action btn-delete btn-sm" onclick="deleteAd(${r.id})">حذف</button></td>
        </tr>`).join('')
      : `<tr><td colspan="4">${emptyHtml('📣','لا توجد إعلانات')}</td></tr>`;
    main.innerHTML = pageHeader('الإعلانات','إدارة الإعلانات في التطبيق.',
      `<button class="btn-white" onclick="renderAds()">🔄 تحديث</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('الإعلانات','') +
      `<div class="card">${errorHtml(e.message,'renderAds')}</div>`;
  }
}
async function deleteAd(id) {
  if (!confirm('حذف هذا الإعلان؟')) return;
  try { await DEL(`/admin/ads/${id}`); toast('تم الحذف','success'); renderAds(); }
  catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: SECURITY
══════════════════════════════════════════════════════ */
async function renderSecurity() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/security/banned-users');
    const rows = data.users||data.banned_users||data.data||[];
    const thead = `<tr><th>المستخدم</th><th>الهاتف</th><th>السبب</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>`<tr>
          <td>${r.name||r.user_id||'—'}</td>
          <td>${r.phone||'—'}</td>
          <td>${r.reason||'—'}</td>
          <td><button class="btn-action btn-approve btn-sm" onclick="unbanUser(${r.id||r.user_id})">إلغاء الحظر</button></td>
        </tr>`).join('')
      : `<tr><td colspan="4">${emptyHtml('🔒','لا يوجد مستخدمون محظورون')}</td></tr>`;
    main.innerHTML = pageHeader('إدارة الأمان','إدارة المستخدمين المحظورين.',
      `<button class="btn-white" onclick="showBanModal()">+ حظر مستخدم</button>`) +
      `<div class="card"><div class="table-container">
        <table><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
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
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: EMERGENCY
══════════════════════════════════════════════════════ */
async function renderEmergency() {
  const main = document.getElementById('main-content');
  try {
    const data = await GET('/admin/emergency/flags');
    const flags = data.flags||data||{};
    const rows = Object.entries(flags).map(([k,v])=>`
      <div class="insight-row">
        <span class="insight-label">${k}</span>
        <span class="insight-value">${typeof v==='boolean'?`<span class="badge ${v?'badge-red':'badge-green'}">${v?'مفعّل':'معطّل'}</span>`:v}</span>
      </div>`).join('');
    main.innerHTML = pageHeader('مركز الطوارئ','حالات الطوارئ وأعلام النظام.',
      `<button class="btn-white" onclick="renderEmergency()">🔄 تحديث</button>`) +
      `<div class="card"><h3 style="font-size:16px;font-weight:800;margin-bottom:16px">🚨 أعلام النظام</h3>${rows||'<p style="color:#6B7280">لا توجد بيانات</p>'}</div>`;
  } catch(e) {
    main.innerHTML = pageHeader('مركز الطوارئ','') +
      `<div class="card">${errorHtml(e.message,'renderEmergency')}</div>`;
  }
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
  el.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <span class="modal-title">${title}</span>
        <button class="modal-close" onclick="closeModal()">✕</button>
      </div>
      <div class="modal-body">${bodyHtml}</div>
      <div class="modal-footer">
        <button class="btn-action btn-delete" onclick="closeModal()">إلغاء</button>
        <button class="btn-action btn-approve" onclick="confirmModal()" style="padding:10px 20px">تأكيد</button>
      </div>
    </div>`;
  document.body.appendChild(el);
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
  document.getElementById('sidebar').classList.toggle('open');
  document.getElementById('sidebar-overlay').classList.toggle('hidden');
}
function closeSidebar() {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebar-overlay').classList.add('hidden');
}

/* ── Boot ────────────────────────────────────────────── */
window.addEventListener('DOMContentLoaded', () => {
  if (Session.token && Session.role &&
      ['admin','super_admin','supervisor'].includes(Session.role)) {
    initAdminPanel();
  }
});
