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
  let lastStatus = 0;
  let lastMsg = '';
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
      lastStatus = res.status;
      const errData = await res.json().catch(() => ({}));
      lastMsg = errData.message || errData.error || `HTTP ${res.status}`;
      /* 401/403 — endpoint EXISTS but token issue; stop trying further endpoints */
      if (res.status === 401 || res.status === 403) {
        throw new Error(`401: ${lastMsg}`);
      }
      /* 404 — endpoint doesn't exist; try next */
      /* other errors — try next */
    } catch (e) {
      if (e.message && (e.message.startsWith('401:') || e.message.startsWith('403:'))) {
        throw new Error(e.message);
      }
      /* network error or 404 — try next */
    }
  }
  throw new Error(lastMsg || 'تعذر الوصول إلى البيانات. تحقق من الاتصال بالشبكة.');
}

/* ── In-memory cache to prevent duplicate API calls ──── */
const _cache = new Map();
const _cacheTime = new Map();
const CACHE_TTL = 30000; // 30 ثانية

async function cachedApi(key, fetchFn) {
  const now = Date.now();
  if (_cache.has(key) && (now - (_cacheTime.get(key) || 0)) < CACHE_TTL) {
    return _cache.get(key);
  }
  const data = await fetchFn();
  _cache.set(key, data);
  _cacheTime.set(key, now);
  return data;
}

function clearCache(prefix) {
  if (prefix) {
    for (const k of _cache.keys()) {
      if (k.startsWith(prefix)) { _cache.delete(k); _cacheTime.delete(k); }
    }
  } else {
    _cache.clear(); _cacheTime.clear();
  }
}

/* ── Media URL resolver (matches Flutter _resolveUrl) ───
   Backend stores images as relative paths: /uploads/img.jpg
   OR as stringified JSON: '[{"url":"/uploads/img.jpg","isMain":true}]'
   This function normalises them to full URLs.
   ─────────────────────────────────────────────────────── */
const BACKEND_BASE = 'https://aqari-backend.onrender.com';

function resolveMediaUrl(raw) {
  if (!raw) return '';
  let v = String(raw).trim();
  if (!v || v === 'null' || v === 'undefined') return '';
  /* Stringified JSON: '[{"url":"/uploads/...",...}]' or '["url"]' */
  if (v.startsWith('[') || v.startsWith('{')) {
    try {
      const parsed = JSON.parse(v);
      if (Array.isArray(parsed) && parsed.length > 0) {
        const first = parsed[0];
        v = (typeof first === 'string')
          ? first
          : (first?.url || first?.path || first?.uri || '');
      } else if (parsed && typeof parsed === 'object') {
        v = parsed.url || parsed.path || parsed.uri || '';
      }
    } catch (_) { /* not valid JSON, use as-is */ }
  }
  v = v.trim();
  if (!v) return '';
  /* Already absolute */
  if (/^https?:\/\//i.test(v)) return v;
  if (v.startsWith('//')) return 'https:' + v;
  /* Relative path → prepend backend base */
  return BACKEND_BASE + (v.startsWith('/') ? v : '/' + v);
}

/* Extract all image URLs from a property object —
   handles arrays, stringified JSON, multiple field names */
function extractPropImages(p) {
  const listKeys = ['images', 'image_urls', 'photos', 'media', 'gallery'];
  for (const key of listKeys) {
    const raw = p[key];
    if (Array.isArray(raw) && raw.length > 0) {
      const urls = raw.map(i => {
        if (typeof i === 'string') return resolveMediaUrl(i);
        if (i && typeof i === 'object') return resolveMediaUrl(i.url || i.path || i.uri || '');
        return '';
      }).filter(Boolean);
      if (urls.length) return urls;
    }
    /* Stringified JSON array */
    if (typeof raw === 'string' && raw.trim()) {
      try {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed) && parsed.length > 0) {
          const urls = parsed.map(i => {
            if (typeof i === 'string') return resolveMediaUrl(i);
            if (i && typeof i === 'object') return resolveMediaUrl(i.url || i.path || i.uri || '');
            return '';
          }).filter(Boolean);
          if (urls.length) return urls;
        }
      } catch (_) {}
      /* Plain string path */
      const resolved = resolveMediaUrl(raw);
      if (resolved) return [resolved];
    }
  }
  /* Single-image fallback fields */
  const singleKeys = ['thumbnail', 'image', 'imageUrl', 'image_url', 'cover_image', 'main_image', 'photo', 'cover'];
  for (const key of singleKeys) {
    const v = p[key];
    if (v && typeof v === 'string') {
      const resolved = resolveMediaUrl(v);
      if (resolved) return [resolved];
    }
  }
  return [];
}

/* ── Lazy Image loading helper ───────────────────────── */
function lazyImg(src, cls = '', style = '', fallback = '') {
  const ph = fallback || '🏠';
  if (!src) return `<div class="img-placeholder">${ph}</div>`;
  return `<img 
    data-src="${src}" 
    src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='80' height='60'%3E%3C/svg%3E"
    class="lazy-img ${cls}" 
    style="${style}"
    onerror="this.onerror=null;this.src='';this.outerHTML='<div class=\'img-placeholder\'>${ph}</div>'"
    alt="">`;
}

/* Initialize Intersection Observer for lazy loading */
function initLazyLoad() {
  if (window._lazyObserver) return;
  window._lazyObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const img = entry.target;
        const src = img.dataset.src;
        if (src) {
          img.src = src;
          img.removeAttribute('data-src');
          img.classList.remove('lazy-img');
          window._lazyObserver.unobserve(img);
        }
      }
    });
  }, { rootMargin: '100px' });
}

function observeLazyImages() {
  initLazyLoad();
  document.querySelectorAll('img[data-src]').forEach(img => {
    window._lazyObserver.observe(img);
  });
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

    /* ── extract role from all known response shapes ── */
    const userData = res.user || res.userData || res.data || {};
    /* Check all possible field names backend might use for the role.
       Flutter admin_session_controller checks: ['role', 'userRole', 'type']
       Backend may also use: user_type, account_type, user_role */
    const rawRole = (
      userData.role ||
      userData.userRole ||
      userData.user_role ||
      userData.type ||
      userData.user_type ||
      userData.account_type ||
      res.role ||
      res.userRole ||
      ''
    );
    const role = String(rawRole).toLowerCase().trim();

    /* Map variant spellings → canonical role */
    const ROLE_MAP = {
      'supervisor': 'supervisor',
      'admin':      'admin',
      'super_admin':'super_admin',
      'superadmin': 'super_admin',
      'super-admin':'super_admin',
    };
    const canonicalRole = ROLE_MAP[role] || role;

    if (!['admin','super_admin','supervisor'].includes(canonicalRole)) {
      /* Debug: log full response so we can diagnose what the backend actually returns */
      console.warn('[login] role check failed. rawRole:', rawRole,
        '| userData keys:', Object.keys(userData),
        '| res keys:', Object.keys(res));
      throw new Error('هذا الحساب لا يمتلك صلاحية الدخول كمدير. تأكد من أن رقم الهاتف صحيح وأن الحساب مشرف أو مدير.');
    }
    /* Use canonical role for the session */
    const role_ = canonicalRole;

    const token = res.token || res.access_token || res.accessToken || userData.token || '';
    if (!token) throw new Error('لم يصل رمز الجلسة من الخادم. حاول مرة أخرى.');

    /* ── extract permissions from all possible locations ── */
    const rawPerms = (
      userData.permissions ||
      userData.perms ||
      userData.rolePermissions ||
      res.permissions ||
      res.perms ||
      []
    );
    const perms = Array.isArray(rawPerms) ? rawPerms : [];

    Session.set(token, { ...userData, role: role_, permissions: perms });
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
/* NOTE: perm=null means visible to ALL roles (including supervisor)
   perm values must exactly match keys in PERM_LABELS             */
const ALL_NAV = [
  { label:'لوحة التحكم',          route:'dashboard',            perm: null,                   icon:'📊' },
  { label:'العقارات',              route:'properties',           perm:'manage_properties',     icon:'🏠' },
  { label:'العقارات المميزة',      route:'featured-properties',  perm:'manage_featured',       icon:'⭐' },
  { label:'الملاك',                route:'owners',               perm:'manage_owners',         icon:'👤' },
  { label:'المكاتب العقارية',      route:'offices',              perm:'manage_offices',        icon:'🏢' },
  { label:'الباحثون',              route:'seekers',              perm:'manage_seekers',        icon:'🔍' },
  { label:'طلبات الباحثين',        route:'seeker-requests',      perm:'manage_requests',       icon:'📋' },
  { label:'المشرفون والصلاحيات',   route:'supervisors',          perm:'manage_supervisors',    icon:'👮' },
  { label:'الباقات',               route:'packages',             perm:'manage_subscriptions',  icon:'📦' },
  { label:'الباقات والاشتراكات',   route:'subscriptions',        perm:'manage_subscriptions',  icon:'🌟' },
  { label:'المدفوعات',             route:'payments',             perm:'manage_payments',       icon:'💰' },
  { label:'مراجعة المدفوعات',      route:'payment-reviews',      perm:'manage_payments',       icon:'💳' },
  { label:'طلبات التوثيق',         route:'verifications',        perm:'manage_verifications',  icon:'✅' },
  { label:'إدارة الموظفين',        route:'all-employees',        perm:'manage_employees',      icon:'👔' },
  { label:'الإشعارات',             route:'notifications',        perm:'manage_settings',       icon:'🔔' },
  { label:'إدارة المحادثات',       route:'chats-management',     perm:'manage_chats',          icon:'💬' },
  { label:'البلاغات والشكاوى',     route:'complaints',           perm:'manage_requests',       icon:'🚩' },
  { label:'الرسائل والدعم',        route:'messages-support',     perm:'manage_requests',       icon:'📩' },
  { label:'التقييمات',             route:'ratings',              perm:'manage_settings',       icon:'⭐' },
  { label:'إدارة المحتوى',         route:'content-pages',        perm:'manage_content',        icon:'📄' },
  { label:'التقارير والإحصائيات',  route:'reports',              perm:'manage_reports',        icon:'📈' },
  { label:'سجل الأنشطة',           route:'activity-logs',        perm:'manage_settings',       icon:'📜' },
  { label:'الإعدادات',             route:'settings',             perm:'manage_settings',       icon:'⚙️' },
  { label:'المواقع الجغرافية',     route:'locations',            perm:'manage_cities',         icon:'📍' },
  { label:'أنواع العقارات',        route:'property-types',       perm:'manage_cities',         icon:'🏗️' },
  { label:'مراقبة النظام',         route:'monitoring',           perm:'manage_settings',       icon:'🖥️' },
  { label:'الإعلانات',             route:'ads',                  perm:'manage_ads',            icon:'📣' },
  { label:'النسخ الاحتياطي',       route:'backup',               perm:'manage_backup',         icon:'💾' },
  { label:'إدارة الأمان',          route:'security',             perm:'manage_security',       icon:'🔒' },
  { label:'مركز الطوارئ',          route:'emergency',            perm:'manage_settings',       icon:'🚨' },
  { label:'إعدادات التطبيق',       route:'app-config',           perm:'manage_settings',       icon:'🔧' },
  { label:'إدارة التحديثات',       route:'app-updates',          perm:'manage_updates',        icon:'📱' },
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
let _navDebounce = null;
function navigateTo(route) {
  /* debounce rapid clicks */
  if (_navDebounce) clearTimeout(_navDebounce);
  _navDebounce = setTimeout(() => _doNavigate(route), 50);
}
function _doNavigate(route) {
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
  /* Permission check: supervisors can only see pages in their nav */
  if (pages[route]) {
    /* Find the nav item for this route and check its perm */
    const navItem = ALL_NAV.find(n => n.route === route);
    if (navItem && navItem.perm && !Session.hasPerm(navItem.perm)) {
      main.innerHTML = pageHeader('غير مصرح', '') +
        `<div class="card"><div class="empty-state">
          <div class="empty-icon">🔐</div>
          <h3>ليس لديك صلاحية للوصول إلى هذه الصفحة</h3>
          <p style="color:#888">تواصل مع مدير النظام لطلب الصلاحية اللازمة.</p>
        </div></div>`;
      return;
    }
    main.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>جاري التحميل...</p></div>`;
    Promise.resolve(pages[route]()).then(() => observeLazyImages());
  } else {
    main.innerHTML = pageHeader('الصفحة غير موجودة', '') +
      `<div class="card"><p style="text-align:center;padding:40px;color:#6B7280">لم يتم العثور على الصفحة المطلوبة.</p></div>`;
  }
  /* Scroll to top on navigation */
  main.scrollTop = 0;
  window.scrollTo(0,0);
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
  /* تحديد نوع الخطأ لعرض رسالة مناسبة */
  let icon = '⚠️';
  let title = 'تعذّر تحميل البيانات';
  let hint = msg || 'حدث خطأ غير متوقع';

  if (/401|403|unauthorized|forbidden/i.test(msg)) {
    icon = '🔐';
    title = 'غير مصرح بالوصول';
    hint = 'يبدو أن الجلسة انتهت أو لا تملك صلاحية لهذه الصفحة. حاول تسجيل الدخول من جديد.';
  } else if (/404|not found/i.test(msg)) {
    icon = '🔍';
    title = 'البيانات غير متوفرة';
    hint = 'هذه الخدمة لم تُفعَّل على الخادم بعد أو لا تحتوي على بيانات.';
  } else if (/500|server/i.test(msg)) {
    icon = '🖥️';
    title = 'خطأ في الخادم';
    hint = 'حدث خطأ مؤقت في الخادم. يُرجى الانتظار قليلاً ثم المحاولة مجدداً.';
  } else if (/network|fetch|ECONNREFUSED|timeout/i.test(msg)) {
    icon = '📡';
    title = 'تعذّر الاتصال بالخادم';
    hint = 'تأكد من الاتصال بالإنترنت، أو أن الخادم قيد التشغيل.';
  } else if (/\u062a\u0639\u0630\u0631/.test(msg)) {
    /* رسالة عربية من apiWithFallback */
    icon = '📡';
    title = 'البيانات غير متاحة حالياً';
    hint = 'لم يتمكن النظام من جلب البيانات من الخادم. قد يكون الخادم في وضع الاستعداد — انتظر 30 ثانية ثم أعد المحاولة.';
  }

  return `<div class="empty-state" style="padding:40px 24px">
    <div class="empty-icon">${icon}</div>
    <h3 style="margin-bottom:8px">${title}</h3>
    <p style="color:#6B7280;max-width:420px;margin:0 auto ${retry?'20px':'0'}">${hint}</p>
    ${retry ? `<button class="btn-action btn-view" onclick="${retry}" style="margin-top:16px">🔄 إعادة المحاولة</button>` : ''}
  </div>`;
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
        onerror="this.onerror=null;this.style.display='none';this.insertAdjacentHTML('afterend','<div style=\'text-align:center;padding:40px;color:#888;font-size:48px\'>🏠</div>')">
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
        onerror="this.onerror=null;this.style.display='none';this.insertAdjacentHTML('afterend','<div style=\'text-align:center;padding:40px;color:#888;font-size:48px\'>🏠</div>')">
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
    const data = await cachedApi('dashboard', () => apiWithFallback([
      '/admin/stats',
      '/admin/statistics',
      '/admin/dashboard',
      '/admin/dashboard/stats',
      '/admin/overview',
    ]));
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
   PAGE: PROPERTIES — بطاقات على الهاتف + جدول على الكمبيوتر
══════════════════════════════════════════════════════ */
let _allProperties = []; // للبحث والفلاتر

async function renderProperties(filter = '') {
  const main = document.getElementById('main-content');
  const perm = Session.hasPerm('manage_properties');

  /* إذا كان هناك فلتر فقط، لا نعيد تحميل الـ API */
  if (!filter && _allProperties.length === 0) {
    main.innerHTML = pageHeader('العقارات','إدارة ومراجعة جميع العقارات.',
      _buildPropActions(perm)) +
      `<div class="card">${loadingHtml()}</div>`;
  }

  try {
    if (!filter || _allProperties.length === 0) {
      const data = await cachedApi('prop-list', () => apiWithFallback([
        '/admin/properties',
        '/admin/properties?status=all',
        '/admin/property/list',
      ]));
      _allProperties = data.properties || data.data || data || [];
      if (!Array.isArray(_allProperties)) _allProperties = [];
    }

    let rows = _allProperties;
    if (filter) {
      const q = filter.toLowerCase();
      rows = _allProperties.filter(p =>
        (p.title||'').toLowerCase().includes(q) ||
        (p.city||p.city_name||'').toLowerCase().includes(q) ||
        (p.owner_name||p.user_name||p.office_name||'').toLowerCase().includes(q) ||
        (p.property_type||'').toLowerCase().includes(q) ||
        (p.status||'').toLowerCase().includes(q)
      );
    }

    const cards = rows.map(p => _buildPropCard(p, perm)).join('');

    main.innerHTML = pageHeader('العقارات','إدارة ومراجعة جميع العقارات.', _buildPropActions(perm)) +
      `<div class="prop-search-bar">
        <input type="text" class="prop-search-input" placeholder="🔍 ابحث بالعنوان أو المدينة أو المالك..." 
          value="${filter}" 
          oninput="_propSearchDebounce(this.value)"
          style="width:100%;padding:12px 16px;border:1.5px solid var(--beige-mid);border-radius:12px;font-family:inherit;font-size:15px">
      </div>
      <div class="card" style="margin-top:0">
        ${rows.length
          ? `<div class="prop-cards-grid">${cards}</div>
             <p style="padding:12px 0 0;color:#6B7280;font-size:13px">
               ${filter ? `نتائج البحث: ${rows.length} من أصل ${_allProperties.length}` : `إجمالي: ${rows.length} عقار`}
             </p>`
          : emptyHtml('🏠', filter ? 'لا نتائج مطابقة للبحث' : 'لا توجد عقارات', '')}
      </div>`;

    observeLazyImages();
  } catch(e) {
    main.innerHTML = pageHeader('العقارات','') +
      `<div class="card">${errorHtml(e.message,'renderProperties()')}</div>`;
  }
}

let _propSearchTimer = null;
function _propSearchDebounce(val) {
  clearTimeout(_propSearchTimer);
  _propSearchTimer = setTimeout(() => renderProperties(val), 300);
}

function _buildPropActions(perm) {
  return `<button class="btn-white" onclick="clearCache('prop');_allProperties=[];renderProperties()">🔄 تحديث</button>
    <select onchange="_filterPropsByStatus(this.value)" id="prop-status-filter" style="padding:8px 12px;border:1.5px solid var(--beige-mid);border-radius:10px;font-family:inherit;font-size:13px">
      <option value="">كل الحالات</option>
      <option value="pending">معلق</option>
      <option value="approved">مقبول</option>
      <option value="rejected">مرفوض</option>
      <option value="featured">مميز</option>
    </select>`;
}
function _filterPropsByStatus(statusVal) {
  const main = document.getElementById('main-content');
  const perm = Session.hasPerm('manage_properties');
  if (!_allProperties.length) { renderProperties(); return; }
  const rows = statusVal
    ? _allProperties.filter(p => (p.status||'') === statusVal || (statusVal==='featured'&&(p.is_featured||p.featured)))
    : _allProperties;
  const cards = rows.map(p => _buildPropCard(p, perm)).join('');
  const gridEl = document.querySelector('.prop-cards-grid');
  if (gridEl) {
    gridEl.innerHTML = cards;
    observeLazyImages();
  } else {
    renderProperties(statusVal);
  }
}

function _buildPropCard(p, perm) {
  /* Use extractPropImages which handles relative URLs, stringified JSON, all field names */
  const imgArr = extractPropImages(p);
  const firstImg = imgArr[0] || '';
  const isFeatured = p.is_featured || p.featured || p.status === 'featured';
  const ownerName = p.owner_name || p.user_name || p.office_name ||
    (p.owner ? (p.owner.name || p.owner.full_name || '') : '') ||
    (p.user  ? (p.user.name  || p.user.full_name  || '') : '') || '—';

  const imgHtml = firstImg
    ? `<div class="prop-card-img-wrap" onclick="openImageModal(${JSON.stringify(imgArr.length?imgArr:[firstImg]).replace(/"/g,"'")})">
         <img data-src="${firstImg}" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'/%3E"
           class="lazy-img prop-card-img"
           onerror="this.onerror=null;this.style.display='none';this.parentElement.querySelector('.prop-no-img').style.display='flex'">
         <div class="prop-no-img" style="display:none">🏠</div>
         ${imgArr.length>1?`<span class="prop-img-count">📷 ${imgArr.length} صور</span>`:''}
         ${isFeatured?`<span class="prop-featured-badge">⭐ مميز</span>`:''}
       </div>`
    : `<div class="prop-card-img-wrap"><div class="prop-no-img">🏠</div>${isFeatured?'<span class="prop-featured-badge">⭐ مميز</span>':''}</div>`;

  const actionBtns = perm ? `
    <div class="prop-card-actions">
      <button class="btn-action btn-view btn-sm" onclick="viewPropertyDetail(${p.id})">📋 تفاصيل</button>
      <button class="btn-action btn-approve btn-sm" onclick="approveProperty(${p.id})">✅ قبول</button>
      <button class="btn-action btn-reject btn-sm" onclick="rejectProperty(${p.id})">❌ رفض</button>
      ${isFeatured
        ? `<button class="btn-action btn-warn btn-sm" onclick="unfeatureProperty(${p.id})">إلغاء التمييز</button>`
        : `<button class="btn-action btn-gold btn-sm" onclick="featureProperty(${p.id})">⭐ تمييز</button>`}
      <button class="btn-action btn-delete btn-sm" onclick="deleteProperty(${p.id})">🗑️ حذف</button>
    </div>` : '';

  return `<div class="prop-card">
    ${imgHtml}
    <div class="prop-card-body">
      <div class="prop-card-title">${p.title||p.property_type||'عقار غير معنون'}</div>
      <div class="prop-card-meta">
        <span class="prop-meta-item">🏗️ ${p.property_type||'—'}</span>
        <span class="prop-meta-item">📍 ${p.city||p.city_name||'—'}</span>
        <span class="prop-meta-item">💰 ${fmtNum(p.price)}${p.currency?' '+p.currency:''}</span>
        <span class="prop-meta-item">👤 ${ownerName}</span>
      </div>
      <div class="prop-card-footer">
        ${badgeForStatus(p.status)}
        <span style="color:#888;font-size:12px">${fmtDate(p.created_at)}</span>
      </div>
      ${actionBtns}
    </div>
  </div>`;
}

async function viewPropertyDetail(id) {
  try {
    const data = await GET(`/admin/properties/${id}`);
    const p = data.property || data.data || data;
    /* Use extractPropImages to handle relative URLs + stringified JSON from backend */
    const imgList = extractPropImages(p);

    /* معرض الصور مع تنقل سابق/تالي بارز */
    const galleryHtml = imgList.length
      ? `<div class="prop-detail-gallery">
          <div class="prop-gallery-main" id="pgm">
            <img src="${imgList[0]}" id="pgm-img" class="prop-gallery-main-img"
              onclick="openImageModal(${JSON.stringify(imgList).replace(/"/g,"'")})"
              onerror="this.onerror=null;this.src='';this.parentElement.innerHTML='<div style=\'padding:40px;text-align:center;color:#888\'>🏠 لا توجد صورة</div>'"
              style="cursor:zoom-in">
            <div class="prop-gallery-nav">
              <button class="btn-action btn-view btn-sm" id="pgm-prev" onclick="propGalleryNav(-1)" disabled>❮</button>
              <span id="pgm-count">1 / ${imgList.length}</span>
              <button class="btn-action btn-approve btn-sm" id="pgm-next" onclick="propGalleryNav(1)" ${imgList.length<=1?'disabled':''}>❯</button>
            </div>
          </div>
          ${imgList.length>1?`<div class="prop-gallery-thumbs">
            ${imgList.map((u,i)=>`<img src="${u}" class="prop-gallery-thumb ${i===0?'active':''}" 
              onclick="propGallerySet(${i})"
              onerror="this.style.display='none'">`).join('')}
          </div>`:''}
        </div>`
      : '<div style="text-align:center;padding:24px;color:#888;background:#F9F5F0;border-radius:12px;margin-bottom:16px">🏠 لا توجد صور لهذا العقار</div>';

    const ownerName = p.owner_name||p.user_name||p.office_name||
      (p.owner?(p.owner.name||p.owner.full_name||''):'') ||
      (p.user?(p.user.name||p.user.full_name||''):'') || '—';

    openWideModal(`تفاصيل العقار #${id}`, `
      ${galleryHtml}
      <div class="detail-grid" style="margin-top:16px">
        <div class="detail-item"><span class="detail-label">📝 العنوان</span><span class="detail-val"><strong>${p.title||'—'}</strong></span></div>
        <div class="detail-item"><span class="detail-label">🏗️ النوع</span><span class="detail-val">${p.property_type||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">🔄 العملية</span><span class="detail-val">${p.operation_type||p.offer_type||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">📍 المدينة</span><span class="detail-val">${p.city||p.city_name||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">💰 السعر</span><span class="detail-val" style="color:var(--gold);font-weight:800">${fmtNum(p.price)} ${p.currency||'ر.ي'}</span></div>
        <div class="detail-item"><span class="detail-label">📐 المساحة</span><span class="detail-val">${p.area||p.size||'—'} ${p.area_unit||'م²'}</span></div>
        <div class="detail-item"><span class="detail-label">🛏️ الغرف</span><span class="detail-val">${p.rooms||p.bedrooms||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">🚿 الحمامات</span><span class="detail-val">${p.bathrooms||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">🔆 الحالة</span><span class="detail-val">${badgeForStatus(p.status)}</span></div>
        <div class="detail-item"><span class="detail-label">👤 المالك/المكتب</span><span class="detail-val">${ownerName}</span></div>
        <div class="detail-item"><span class="detail-label">📞 الهاتف</span><span class="detail-val">${p.phone||p.owner_phone||p.user_phone||'—'}</span></div>
        <div class="detail-item"><span class="detail-label">📅 تاريخ الإضافة</span><span class="detail-val">${fmtDate(p.created_at)}</span></div>
      </div>
      ${p.description?`<div class="detail-desc"><strong>📄 الوصف:</strong><p>${p.description}</p></div>`:''}
      ${p.address||p.location?`<div class="detail-desc"><strong>📍 العنوان التفصيلي:</strong><p>${p.address||p.location}</p></div>`:''}
    `, null);
    /* تخزين الصور للتنقل */
    window._pgImages = imgList;
    window._pgIdx = 0;
  } catch(e) {
    toast('تعذر تحميل تفاصيل العقار: ' + e.message, 'error');
  }
}

/* تنقل معرض صور تفاصيل العقار */
function propGalleryNav(dir) {
  const imgs = window._pgImages || [];
  if (!imgs.length) return;
  window._pgIdx = Math.max(0, Math.min(imgs.length-1, window._pgIdx + dir));
  propGallerySet(window._pgIdx);
}
function propGallerySet(idx) {
  const imgs = window._pgImages || [];
  window._pgIdx = idx;
  const mainImg = document.getElementById('pgm-img');
  const count = document.getElementById('pgm-count');
  const prev = document.getElementById('pgm-prev');
  const next = document.getElementById('pgm-next');
  if (mainImg) {
    mainImg.src = imgs[idx] || '';
    mainImg.onerror = () => { mainImg.style.display='none'; };
  }
  if (count) count.textContent = `${idx+1} / ${imgs.length}`;
  if (prev) prev.disabled = idx === 0;
  if (next) next.disabled = idx === imgs.length-1;
  /* تحديث الـ thumbnails */
  document.querySelectorAll('.prop-gallery-thumb').forEach((t,i)=>{
    t.classList.toggle('active', i===idx);
  });
}

/* ── Property Actions ─────────────────────────────────── */
async function approveProperty(id) {
  if (!confirm('هل تريد الموافقة على هذا العقار؟')) return;
  try {
    /* جرب PATCH أولاً ثم POST */
    try { await PATCH(`/admin/properties/${id}/status`, { status:'approved' }); }
    catch { await POST(`/admin/properties/${id}/approve`, {}); }
    toast('تمت الموافقة على العقار ✅','success');
    clearCache('prop'); closeModal(); renderProperties();
  } catch(e) { toast(e.message,'error'); }
}
async function rejectProperty(id) {
  openModal('رفض العقار', `
    <div class="form-group"><label>سبب الرفض</label>
    <textarea id="rej-reason" rows="3" placeholder="اكتب سبب الرفض (اختياري)" style="width:100%;padding:10px;border:1px solid #E5D5B8;border-radius:8px;font-family:inherit"></textarea>
    </div>`,
    async () => {
      const reason = document.getElementById('rej-reason').value.trim();
      try {
        await PATCH(`/admin/properties/${id}/status`, { status:'rejected', rejection_reason:reason });
        toast('تم رفض العقار','success');
        clearCache('prop'); closeModal(); renderProperties();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}
async function deleteProperty(id) {
  if (!confirm('هل تريد حذف هذا العقار نهائياً؟ لا يمكن التراجع!')) return;
  try {
    await DEL(`/admin/properties/${id}`);
    toast('تم حذف العقار','success');
    clearCache('prop'); closeModal(); renderProperties();
  } catch(e) { toast(e.message,'error'); }
}
async function featureProperty(id) {
  if (!confirm('تمييز هذا العقار كعقار مميز؟')) return;
  try {
    await PATCH(`/admin/properties/${id}/featured`, { featured: true });
    toast('تم تمييز العقار ⭐','success');
    clearCache('prop'); renderProperties();
  } catch(e) {
    try {
      await POST(`/admin/properties/${id}/feature`, {});
      toast('تم تمييز العقار ⭐','success');
      clearCache('prop'); renderProperties();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function unfeatureProperty(id) {
  if (!confirm('إلغاء تمييز هذا العقار؟')) return;
  try {
    await PATCH(`/admin/properties/${id}/featured`, { featured: false });
    toast('تم إلغاء التمييز','success');
    clearCache('prop'); clearCache('feat'); renderProperties();
  } catch(e) { toast(e.message,'error'); }
}

/* ══════════════════════════════════════════════════════
   PAGE: FEATURED PROPERTIES
══════════════════════════════════════════════════════ */
async function renderFeaturedProperties() {
  const main = document.getElementById('main-content');
  try {
    const data = await cachedApi('feat-props', () => apiWithFallback([
      '/admin/properties/featured',
      '/admin/featured-properties',
      '/admin/properties?featured=true',
    ]));
    const list = data.properties || data.data || data || [];
    const items = Array.isArray(list) ? list : [];

    const cards = items.map(p => {
      const imgs = p.images || p.photos || [];
      const imgArr = Array.isArray(imgs) ? imgs.map(i => typeof i==='string'?i:(i?.url||'')).filter(Boolean) : [];
      const firstImg = imgArr[0] || p.image || p.thumbnail || '';
      const imgHtml = firstImg
        ? `<div class="prop-card-img-wrap" onclick="openImageModal(${JSON.stringify(imgArr.length?imgArr:[firstImg]).replace(/"/g,"'")})">
             <img data-src="${firstImg}" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'/%3E" class="lazy-img prop-card-img"
               onerror="this.onerror=null;this.style.display='none';this.parentElement.querySelector('.prop-no-img').style.display='flex'">
             <div class="prop-no-img" style="display:none">🏠</div>
           </div>`
        : `<div class="prop-card-img-wrap"><div class="prop-no-img">🏠</div></div>`;
      return `<div class="prop-card">
        ${imgHtml}
        <div class="prop-card-body">
          <div class="prop-card-title">${p.title||p.name||'عقار مميز'}</div>
          <div class="prop-card-meta">
            <span class="prop-meta-item">👤 ${p.owner_name||p.user_name||'—'}</span>
            <span class="prop-meta-item">💰 ${p.price?fmtNum(p.price)+' '+(p.currency||''):'—'}</span>
          </div>
          <div class="prop-card-footer">
            <span class="badge badge-purple">مميّز ⭐</span>
          </div>
          <div class="prop-card-actions">
            <button class="btn-action btn-view btn-sm" onclick="viewPropertyDetail(${p.id})">📋 عرض التفاصيل</button>
            <button class="btn-action btn-delete btn-sm" onclick="removeFeatured(${p.id})">إلغاء التمييز</button>
          </div>
        </div>
      </div>`;
    }).join('');

    main.innerHTML = pageHeader('العقارات المميزة','العقارات المعروضة بشكل مميز في التطبيق.',
      `<button class="btn-white" onclick="clearCache('feat');renderFeaturedProperties()">🔄 تحديث</button>`) +
      `<div class="card">${items.length
        ? `<div class="prop-cards-grid">${cards}</div>`
        : emptyHtml('⭐','لا توجد عقارات مميزة','قم بتمييز عقار من صفحة العقارات')
      }</div>`;
    observeLazyImages();
  } catch(e) {
    main.innerHTML = pageHeader('العقارات المميزة','') + `<div class="card">${errorHtml(e.message,'renderFeaturedProperties()')}</div>`;
  }
}
async function removeFeatured(id) {
  if (!confirm('إلغاء تمييز هذا العقار؟')) return;
  try {
    await PATCH(`/admin/properties/${id}/featured`, { featured: false });
    toast('تم إلغاء التمييز','success');
    clearCache('feat'); clearCache('prop'); renderFeaturedProperties();
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
    const epMap = {
      owners:  ['/admin/users?role=owner',  '/admin/owners',  '/admin/users?type=owner'],
      offices: ['/admin/users?role=office', '/admin/offices', '/admin/users?type=office'],
      seekers: ['/admin/users?role=seeker', '/admin/seekers', '/admin/users?type=seeker'],
    };
    const data = await cachedApi(`users-${type}`, () => apiWithFallback(epMap[type] || [cfg.endpoint]));
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
      `<button class="btn-white" onclick="clearCache('users-${type}');renderUsersTable('${type}')">🔄 تحديث</button>`) +
      `<div class="card">
        <div class="table-container">
          <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
        </div>
        <p style="padding:12px 16px 0;color:#6B7280;font-size:13px">إجمالي: ${rows.length} سجل</p>
      </div>`;
    observeLazyImages();
  } catch(e) {
    main.innerHTML = pageHeader(cfg.title,'') +
      `<div class="card">${errorHtml(e.message,`renderUsersTable('${type}')`)}</div>`;
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
  openModal('رفض الحساب', `
    <div class="form-group"><label>سبب الرفض</label>
    <textarea id="rej-user-reason" rows="3" placeholder="اكتب سبب الرفض (اختياري)" style="width:100%;padding:10px;border:1px solid #E5D5B8;border-radius:8px;font-family:inherit"></textarea>
    </div>`,
    async () => {
      const reason = document.getElementById('rej-user-reason').value.trim();
      try {
        await PATCH(`/admin/users/${id}/status`, { status:'rejected', reason });
        toast('تم رفض الحساب','success');
        closeModal(); renderUsersTable(type);
      } catch(e) { toast(e.message,'error'); }
    }
  );
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
    const data = await apiWithFallback(['/admin/requests','/admin/seeker-requests','/admin/property-requests']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
/* ── 21 Granular Permissions — matches sidebar nav exactly ── */
const PERM_LABELS = {
  manage_properties:      'إدارة العقارات',
  manage_featured:        'إدارة العقارات المميزة',
  manage_owners:          'إدارة الملاك',
  manage_offices:         'إدارة المكاتب العقارية',
  manage_seekers:         'إدارة الباحثين',
  manage_supervisors:     'إدارة المشرفين',
  manage_subscriptions:   'إدارة الباقات والاشتراكات',
  manage_payments:        'إدارة المدفوعات',
  manage_verifications:   'إدارة طلبات التوثيق',
  manage_employees:       'إدارة الموظفين',
  manage_chats:           'إدارة المحادثات',
  manage_content:         'إدارة المحتوى',
  manage_ads:             'إدارة الإعلانات',
  manage_cities:          'إدارة المدن وأنواع العقارات',
  manage_reports:         'إدارة التقارير والإحصائيات',
  manage_backup:          'إدارة النسخ الاحتياطية',
  manage_security:        'إدارة الأمان',
  manage_settings:        'إعدادات التطبيق',
  manage_updates:         'إدارة التحديثات',
  manage_requests:        'إدارة الطلبات والبلاغات',
  manage_users:           'إدارة المستخدمين (عام)',
};
const ALL_PERMS = Object.keys(PERM_LABELS);

/* Global store for supervisor perms — avoids JSON-in-HTML-attribute quoting bugs */
const _supStore = {};

async function renderSupervisors() {
  const main = document.getElementById('main-content');
  try {
    const data = await cachedApi('supervisors', () => apiWithFallback(['/admin/supervisors','/admin/users?role=supervisor']));
    const rows = data.supervisors||data.users||data.data||[];
    const thead = `<tr><th>الاسم</th><th>الهاتف</th><th>عدد الصلاحيات</th><th>تاريخ الإنشاء</th><th>إجراءات</th></tr>`;
    const tbody = rows.length
      ? rows.map(r=>{
          const perms = Array.isArray(r.permissions)?r.permissions:[];
          /* Store perms by ID to avoid quoting issues in onclick attributes */
          _supStore[r.id] = {
            perms,
            name: r.name||r.full_name||'',
            phone: r.phone||''
          };
          return `<tr>
            <td data-label="الاسم"><strong>${r.name||r.full_name||'—'}</strong></td>
            <td data-label="الهاتف">${r.phone||'—'}</td>
            <td data-label="عدد الصلاحيات">
              <div style="display:flex;flex-wrap:wrap;gap:4px">
                ${perms.length
                  ? `<span class="badge badge-gold">${perms.length} / ${ALL_PERMS.length} صلاحية</span>
                     ${perms.slice(0,3).map(p=>`<span class="badge badge-gray" style="margin:2px;font-size:11px">${PERM_ICONS[p]||'🔹'} ${PERM_LABELS[p]||p}</span>`).join('')}
                     ${perms.length > 3 ? `<span class="badge badge-gray" style="font-size:11px">+${perms.length-3} أخرى</span>` : ''}`
                  : '<span style="color:#888;font-size:13px">لا توجد صلاحيات</span>'}
              </div>
            </td>
            <td data-label="تاريخ الإنشاء">${fmtDate(r.created_at)}</td>
            <td data-label="إجراءات" class="actions-cell"><div class="action-btns">
              <button class="btn-action btn-view btn-sm" onclick="editSupervisorById(${r.id})">تعديل الصلاحيات</button>
              <button class="btn-action btn-delete btn-sm" onclick="deleteSupervisor(${r.id})">حذف</button>
            </div></td>
          </tr>`;
        }).join('')
      : `<tr><td colspan="5" class="empty-cell">${emptyHtml('👮','لا يوجد مشرفون','أضف مشرفاً أولاً')}</td></tr>`;
    main.innerHTML = pageHeader('المشرفون والصلاحيات','إدارة حسابات المشرفين وصلاحياتهم.',
      `<button class="btn-white" onclick="showAddSupervisorModal()">+ إضافة مشرف</button>
       <button class="btn-white" onclick="clearCache('supervisors');renderSupervisors()" style="margin-right:8px">🔄</button>`) +
      `<div class="card"><div class="table-container">
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('المشرفون والصلاحيات','') +
      `<div class="card">${errorHtml(e.message,'renderSupervisors()')}</div>`;
  }
}

/* ══════════════════════════════════════════════════════
   PERMISSIONS ENGINE — Pure native checkboxes, multi-select
══════════════════════════════════════════════════════ */

/**
 * buildPermsPanel(containerId, currentPerms)
 * Returns HTML string for a full-featured permissions selector:
 * - Search field to filter permissions
 * - Select All / Clear All toolbar buttons
 * - Live checked counter badge
 * - 21 native checkbox rows (no JS toggle tricks)
 */
function buildPermsPanel(containerId, currentPerms) {
  const sel = Array.isArray(currentPerms) ? currentPerms : [];
  const rows = ALL_PERMS.map((p, i) => {
    const checked = sel.includes(p);
    const icon = PERM_ICONS[p] || '🔹';
    return `
    <label class="perm-row" id="prow-${containerId}-${i}">
      <input type="checkbox"
        class="perm-native-cb"
        data-grid="${containerId}"
        data-idx="${i}"
        name="perm"
        value="${p}"
        ${checked ? 'checked' : ''}
        onchange="onPermChange(this)">
      <span class="perm-row-icon">${icon}</span>
      <span class="perm-row-label">${PERM_LABELS[p]}</span>
      <span class="perm-row-tick">${checked ? '✓' : ''}</span>
    </label>`;
  }).join('');

  return `
  <div class="perms-panel" id="panel-${containerId}">
    <div class="perms-panel-toolbar">
      <div class="perms-search-wrap">
        <span class="perms-search-icon">🔍</span>
        <input type="text"
          class="perms-search-input"
          placeholder="ابحث في الصلاحيات..."
          oninput="filterPerms('${containerId}', this.value)">
      </div>
      <div class="perms-panel-actions">
        <button type="button" class="perm-btn-all" onclick="selectAllPerms('${containerId}')">تحديد الكل</button>
        <button type="button" class="perm-btn-none" onclick="clearAllPerms('${containerId}')">إلغاء الكل</button>
        <span class="perms-badge" id="badge-${containerId}">${sel.length} / ${ALL_PERMS.length}</span>
      </div>
    </div>
    <div class="perms-rows-container" id="${containerId}">${rows}</div>
  </div>`;
}

/* Icon map for each permission key */
const PERM_ICONS = {
  manage_properties:    '🏠',
  manage_featured:      '⭐',
  manage_owners:        '👤',
  manage_offices:       '🏢',
  manage_seekers:       '🔍',
  manage_supervisors:   '👮',
  manage_subscriptions: '🌟',
  manage_payments:      '💰',
  manage_verifications: '✅',
  manage_employees:     '👔',
  manage_chats:         '💬',
  manage_content:       '📄',
  manage_ads:           '📣',
  manage_cities:        '📍',
  manage_reports:       '📈',
  manage_backup:        '💾',
  manage_security:      '🔒',
  manage_settings:      '⚙️',
  manage_updates:       '📱',
  manage_requests:      '📋',
  manage_users:         '👥',
};

function onPermChange(cb) {
  /* Sync visual tick */
  const tick = cb.parentElement.querySelector('.perm-row-tick');
  if (tick) tick.textContent = cb.checked ? '✓' : '';
  /* Highlight row */
  cb.parentElement.classList.toggle('perm-row-checked', cb.checked);
  /* Update badge */
  const containerId = cb.dataset.grid;
  _updatePermBadge(containerId);
}

function _updatePermBadge(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;
  const total   = container.querySelectorAll('.perm-native-cb').length;
  const checked = container.querySelectorAll('.perm-native-cb:checked').length;
  const badge   = document.getElementById('badge-' + containerId);
  if (badge) badge.textContent = `${checked} / ${total}`;
  /* color feedback */
  if (badge) {
    badge.className = 'perms-badge' + (checked === total ? ' perms-badge-full' : checked > 0 ? ' perms-badge-partial' : '');
  }
}

function selectAllPerms(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;
  container.querySelectorAll('.perm-native-cb').forEach(cb => {
    cb.checked = true;
    const tick = cb.parentElement.querySelector('.perm-row-tick');
    if (tick) tick.textContent = '✓';
    cb.parentElement.classList.add('perm-row-checked');
  });
  _updatePermBadge(containerId);
}

function clearAllPerms(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;
  container.querySelectorAll('.perm-native-cb').forEach(cb => {
    cb.checked = false;
    const tick = cb.parentElement.querySelector('.perm-row-tick');
    if (tick) tick.textContent = '';
    cb.parentElement.classList.remove('perm-row-checked');
  });
  _updatePermBadge(containerId);
}

function filterPerms(containerId, query) {
  const container = document.getElementById(containerId);
  if (!container) return;
  const q = query.trim().toLowerCase();
  container.querySelectorAll('.perm-row').forEach(row => {
    const label = row.querySelector('.perm-row-label');
    const text  = label ? label.textContent.toLowerCase() : '';
    row.style.display = (!q || text.includes(q)) ? '' : 'none';
  });
}

function getCheckedPerms(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return [];
  return [...container.querySelectorAll('.perm-native-cb:checked')].map(cb => cb.value);
}

/* Legacy compat */
function syncPermLabel() {}
function togglePerm() {}
function buildPermsGrid(cid, perms) { return buildPermsPanel(cid, perms); }

/* ══════════════════════════════════════════════════════
   SUPERVISOR MODALS — wide split-layout design
══════════════════════════════════════════════════════ */
function showAddSupervisorModal() {
  openWideModal('إضافة مشرف جديد', `
    <div class="sup-modal-layout">
      <div class="sup-modal-left">
        <div class="sup-modal-section-title">📋 بيانات الحساب</div>
        <div class="form-group">
          <label>الاسم الكامل <span style="color:#9B2335">*</span></label>
          <input type="text" id="sup-name" placeholder="مثال: أحمد محمد علي" autocomplete="off">
        </div>
        <div class="form-group">
          <label>رقم الهاتف <span style="color:#9B2335">*</span></label>
          <input type="tel" id="sup-phone" placeholder="967xxxxxxxxx أو 05xxxxxxxx" dir="ltr">
        </div>
        <div class="form-group">
          <label>كلمة المرور <span class="form-label-hint">(اختياري — الدخول بالـ OTP)</span></label>
          <input type="password" id="sup-pass" placeholder="اتركه فارغاً إذا كان الدخول بـ OTP">
        </div>
        <div class="sup-modal-info-box">
          <span>💡</span>
          <div>
            <strong>ملاحظة:</strong> المشرف يدخل عبر OTP برقم هاتفه. كلمة المرور اختيارية فقط إذا كان النظام يدعمها.
          </div>
        </div>
      </div>
      <div class="sup-modal-right">
        <div class="sup-modal-section-title">🔐 الصلاحيات الممنوحة</div>
        ${buildPermsPanel('perms-add-grid', [])}
      </div>
    </div>`,
    async () => {
      const name  = document.getElementById('sup-name').value.trim();
      const phone = document.getElementById('sup-phone').value.trim();
      const pass  = document.getElementById('sup-pass').value.trim();
      const perms = getCheckedPerms('perms-add-grid');
      if (!name)  { toast('أدخل اسم المشرف','error'); return; }
      if (!phone) { toast('أدخل رقم هاتف المشرف','error'); return; }
      if (pass && pass.length < 6) { toast('كلمة المرور يجب أن تكون 6 أحرف على الأقل','error'); return; }
      if (perms.length === 0) {
        if (!confirm('لم تحدد أي صلاحيات. هل تريد المتابعة؟')) return;
      }
      try {
        await POST('/admin/supervisors', {
          name, phone,
          ...(pass ? { password: pass } : {}),
          permissions: perms,
          role: 'supervisor'
        });
        toast(`تم إضافة المشرف "${name}" بنجاح ✅`, 'success');
        clearCache('supervisors'); closeModal(); renderSupervisors();
      } catch(e) { toast(e.message || 'حدث خطأ أثناء الإضافة','error'); }
    }
  );
}

/* Wrapper that reads from _supStore — avoids JSON-in-HTML-attribute quoting bugs */
function editSupervisorById(id) {
  const s = _supStore[id] || { perms: [], name: '', phone: '' };
  editSupervisor(id, s.name, s.phone, s.perms);
}

function editSupervisor(id, name, phone, currentPerms) {
  const safePerms = Array.isArray(currentPerms) ? currentPerms : [];
  openWideModal(`تعديل المشرف: ${name}`, `
    <div class="sup-modal-layout">
      <div class="sup-modal-left">
        <div class="sup-modal-section-title">👤 معلومات المشرف</div>
        <div class="sup-info-card">
          <div class="sup-info-avatar">${(name||'م').charAt(0)}</div>
          <div class="sup-info-details">
            <strong>${name || '—'}</strong>
            <span>${phone || '—'}</span>
          </div>
        </div>
        <div class="sup-modal-info-box" style="margin-top:16px">
          <span>ℹ️</span>
          <div>حدد الصلاحيات التي تريد منحها أو سحبها من هذا المشرف. يمكنك تحديد أي عدد من الصلاحيات أو إزالتها جميعاً.</div>
        </div>
        <div class="sup-modal-section-title" style="margin-top:20px">📊 الصلاحيات الحالية</div>
        <div class="sup-current-perms">
          ${safePerms.length
            ? safePerms.map(p => `<span class="sup-perm-tag">${PERM_ICONS[p]||'🔹'} ${PERM_LABELS[p]||p}</span>`).join('')
            : '<span style="color:#888;font-size:13px">لا توجد صلاحيات محددة حالياً</span>'}
        </div>
      </div>
      <div class="sup-modal-right">
        <div class="sup-modal-section-title">🔐 تعديل الصلاحيات</div>
        ${buildPermsPanel('perms-edit-grid', safePerms)}
      </div>
    </div>`,
    async () => {
      const perms = getCheckedPerms('perms-edit-grid');
      const save  = async (fn) => {
        await fn();
        toast('تم تحديث الصلاحيات ✅','success');
        clearCache('supervisors'); closeModal(); renderSupervisors();
      };
      try {
        await save(() => PUT(`/admin/supervisors/${id}/permissions`, { permissions: perms }));
      } catch(e1) { try {
        await save(() => PATCH(`/admin/supervisors/${id}`, { permissions: perms }));
      } catch(e2) { try {
        await save(() => PUT(`/admin/supervisors/${id}`, { permissions: perms }));
      } catch(e3) { toast(e3.message || 'تعذر حفظ الصلاحيات — تحقق من الاتصال بالخادم','error'); } } }
    }
  );
}

async function deleteSupervisor(id) {
  if (!confirm('هل تريد حذف هذا المشرف؟')) return;
  try {
    await DEL(`/admin/supervisors/${id}`);
    toast('تم حذف المشرف','success');
    clearCache('supervisors'); renderSupervisors();
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
      '/admin/subscription-packages',
      '/admin/pricing',
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
        ${rows ? `<div class="table-container"><table class="data-table">
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
      } catch(e) { toast(e.message,'error'); }
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
    const data = await apiWithFallback(['/admin/subscriptions','/admin/subscription-requests','/admin/user-subscriptions']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
  openModal('رفض الاشتراك', `
    <div class="form-group"><label>سبب الرفض</label>
    <textarea id="rej-sub-reason" rows="3" placeholder="اكتب سبب الرفض" style="width:100%;padding:10px;border:1px solid #E5D5B8;border-radius:8px;font-family:inherit"></textarea>
    </div>`,
    async () => {
      const reason = document.getElementById('rej-sub-reason').value.trim();
      try {
        await PATCH(`/admin/subscriptions/${id}/status`, { status:'rejected', reason });
        toast('تم رفض الاشتراك','success'); closeModal(); renderSubscriptions();
      } catch(e) {
        try {
          await POST(`/admin/subscriptions/${id}/reject`, { reason });
          toast('تم رفض الاشتراك','success'); closeModal(); renderSubscriptions();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
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
    const data = await apiWithFallback(['/admin/payment-reviews','/admin/payments/reviews','/admin/payments/pending']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('مراجعة المدفوعات','') +
      `<div class="card">${errorHtml(e.message,'renderPaymentReviews')}</div>`;
  }
}
async function approvePayment(id) {
  if (!confirm('تأكيد الموافقة على هذه الدفعة؟')) return;
  try {
    await POST(`/admin/payment-reviews/${id}/approve`, {});
    toast('تمت الموافقة على الدفع ✅','success');
    renderPaymentReviews();
  } catch(e) { toast(e.message,'error'); }
}
async function rejectPayment(id) {
  openModal('رفض الدفعة', `
    <div class="form-group"><label>سبب الرفض</label>
    <textarea id="rej-pay-note" rows="3" placeholder="اكتب سبب الرفض" style="width:100%;padding:10px;border:1px solid #E5D5B8;border-radius:8px;font-family:inherit"></textarea>
    </div>`,
    async () => {
      const note = document.getElementById('rej-pay-note').value.trim();
      try {
        await POST(`/admin/payment-reviews/${id}/reject`, { admin_note:note });
        toast('تم رفض الدفع','success'); closeModal(); renderPaymentReviews();
      } catch(e) { toast(e.message,'error'); }
    }
  );
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
      </div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('طلبات التوثيق','') +
      `<div class="card">${errorHtml(e.message,'renderVerifications')}</div>`;
  }
}
async function approveVerif(id) {
  if (!confirm('تأكيد الموافقة على طلب التوثيق؟')) return;
  try {
    await PATCH(`/admin/verification/${id}`, { status:'approved' });
    toast('تمت الموافقة على التوثيق ✅','success');
    renderVerifications();
  } catch(e) {
    try {
      await PUT(`/admin/verification/${id}`, { status:'approved' });
      toast('تمت الموافقة على التوثيق ✅','success');
      renderVerifications();
    } catch(e2) { toast(e2.message,'error'); }
  }
}
async function rejectVerif(id) {
  openModal('رفض طلب التوثيق', `
    <div class="form-group"><label>سبب الرفض</label>
    <textarea id="rej-verif-note" rows="3" placeholder="اكتب سبب الرفض" style="width:100%;padding:10px;border:1px solid #E5D5B8;border-radius:8px;font-family:inherit"></textarea>
    </div>`,
    async () => {
      const note = document.getElementById('rej-verif-note').value.trim();
      try {
        await PATCH(`/admin/verification/${id}`, { status:'rejected', admin_note:note });
        toast('تم رفض طلب التوثيق','success'); closeModal(); renderVerifications();
      } catch(e) {
        try {
          await PUT(`/admin/verification/${id}`, { status:'rejected', admin_note:note });
          toast('تم رفض طلب التوثيق','success'); closeModal(); renderVerifications();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
}
async function requestReupload(id) {
  openModal('طلب إعادة رفع المستندات', `
    <div class="form-group"><label>رسالة للمستخدم</label>
    <textarea id="reup-note" rows="3" placeholder="اكتب سبب طلب إعادة الرفع" style="width:100%;padding:10px;border:1px solid #E5D5B8;border-radius:8px;font-family:inherit"></textarea>
    </div>`,
    async () => {
      const note = document.getElementById('reup-note').value.trim();
      try {
        await PATCH(`/admin/verification/${id}`, { status:'reupload_required', admin_note:note });
        toast('تم طلب إعادة رفع المستندات','success'); closeModal(); renderVerifications();
      } catch(e) {
        try {
          await POST(`/admin/verification/${id}/request-reupload`, { message:note });
          toast('تم طلب إعادة رفع المستندات','success'); closeModal(); renderVerifications();
        } catch(e2) { toast(e2.message,'error'); }
      }
    }
  );
}

/* ══════════════════════════════════════════════════════
   PAGE: ALL EMPLOYEES — FIXED with photo, office info, notifications
══════════════════════════════════════════════════════ */
async function renderAllEmployees() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback(['/admin/all-employees','/admin/employees','/admin/users?role=employee']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
    const data = await apiWithFallback(['/admin/notifications','/admin/push-notifications','/notifications']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
    const data = await apiWithFallback(['/admin/chats','/admin/chat-rooms','/admin/conversations']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
  main.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>جاري تحميل الإحصائيات...</p></div>`;
  if (!Session.token) {
    main.innerHTML = pageHeader('التقارير والإحصائيات','') +
      `<div class="card"><div class="empty-state" style="padding:48px 24px">
        <div class="empty-icon">📈</div>
        <h3>سجّل الدخول للاستعراض</h3>
        <p style="color:#6B7280">بيانات التقارير تتطلب تسجيل الدخول.</p>
      </div></div>`;
    return;
  }

  /* ── Try every possible stats endpoint — return first that succeeds ── */
  let s = null;
  const statEndpoints = [
    '/admin/stats',
    '/admin/statistics',
    '/admin/dashboard',
    '/admin/dashboard/stats',
    '/admin/overview',
    '/admin/reports',
    '/stats',
    '/dashboard/stats',
  ];
  for (const ep of statEndpoints) {
    try {
      const res = await fetch(API + ep, {
        headers: {
          'Content-Type': 'application/json',
          ...(Session.token ? { 'Authorization': 'Bearer ' + Session.token } : {})
        }
      });
      if (res.ok) {
        const json = await res.json().catch(() => ({}));
        /* unwrap common wrappers */
        s = json.stats || json.data || json.overview || json.dashboard || json;
        if (s && typeof s === 'object') break;
      }
    } catch(e) { /* try next */ }
  }

  /* ── If all endpoints failed, try parallel individual endpoints ── */
  if (!s) {
    const [propRes, userRes, subRes, verifRes, adsRes, empRes] = await Promise.allSettled([
      fetch(API + '/admin/properties?limit=1', { headers: { 'Authorization': 'Bearer ' + Session.token } }),
      fetch(API + '/admin/users?limit=1',      { headers: { 'Authorization': 'Bearer ' + Session.token } }),
      fetch(API + '/admin/subscriptions?limit=1',{ headers: { 'Authorization': 'Bearer ' + Session.token } }),
      fetch(API + '/admin/verification?limit=1', { headers: { 'Authorization': 'Bearer ' + Session.token } }),
      fetch(API + '/admin/ads?limit=1',          { headers: { 'Authorization': 'Bearer ' + Session.token } }),
      fetch(API + '/admin/employees?limit=1',    { headers: { 'Authorization': 'Bearer ' + Session.token } }),
    ]);
    const safeJson = async (r) => { try { return await r.value.json(); } catch(e) { return {}; } };
    const [pd,ud,sd,vd,ad,ed] = await Promise.all([
      propRes.status==='fulfilled' ? safeJson(propRes) : Promise.resolve({}),
      userRes.status==='fulfilled' ? safeJson(userRes) : Promise.resolve({}),
      subRes.status==='fulfilled'  ? safeJson(subRes)  : Promise.resolve({}),
      verifRes.status==='fulfilled'? safeJson(verifRes): Promise.resolve({}),
      adsRes.status==='fulfilled'  ? safeJson(adsRes)  : Promise.resolve({}),
      empRes.status==='fulfilled'  ? safeJson(empRes)  : Promise.resolve({}),
    ]);
    s = {
      total_properties: pd.total || pd.count || (pd.data||pd.properties||[]).length || null,
      total_users:      ud.total || ud.count || (ud.data||ud.users||[]).length || null,
      total_subscriptions: sd.total || sd.count || (sd.data||sd.subscriptions||[]).length || null,
      total_verifications: vd.total || vd.count || (vd.data||vd.verifications||[]).length || null,
      total_ads:        ad.total || ad.count || (ad.data||ad.ads||[]).length || null,
      total_employees:  ed.total || ed.count || (ed.data||ed.employees||[]).length || null,
      _partial: true,
    };
    /* إذا كل القيم null — Backend لا يُرجع بيانات */
    const allNull = Object.values(s).every(v => v === null || v === true);
    if (allNull) {
      main.innerHTML = pageHeader('التقارير والإحصائيات','') +
        `<div class="card"><div class="empty-state" style="padding:48px 24px">
          <div class="empty-icon">📊</div>
          <h3 style="margin-bottom:8px">بيانات الإحصائيات غير متوفرة حاليًا</h3>
          <p style="color:#6B7280;max-width:420px;margin:0 auto 20px">لم يتمكن النظام من جلب بيانات الإحصائيات من الخادم. قد يكون الخادم في وضع الاستعداد أو الـ Endpoints غير مفعّلة بعد.</p>
          <button class="btn-white" onclick="renderReports()">🔄 إعادة المحاولة</button>
        </div></div>`;
      return;
    }
  }

  /* ── Helper: pick first non-null value from multiple keys ── */
  const pick = (...keys) => { for (const k of keys) { const v = s[k]; if (v != null && v !== '') return v; } return null; };
  const n = (v) => v != null ? fmtNum(v) : '<span style="color:#bbb">—</span>';

  /* ── Build stat cards ── */
  const statCard = (icon, title, rows) => `
    <div class="card report-card">
      <h3 class="report-card-title">${icon} ${title}</h3>
      ${rows.map(([label,val,cls=''])=>`
        <div class="insight-row">
          <span class="insight-label">${label}</span>
          <span class="insight-value ${cls}">${n(val)}</span>
        </div>`).join('')}
    </div>`;

  /* users_by_role breakdown if available */
  const byRole = s.users_by_role || s.usersByRole || s.roles || {};
  const ownerCount    = pick('owners','total_owners','owners_count') ?? byRole.owner   ?? byRole.owners   ?? null;
  const officeCount   = pick('offices','total_offices','offices_count') ?? byRole.office ?? byRole.offices ?? null;
  const seekerCount   = pick('seekers','total_seekers','seekers_count') ?? byRole.seeker ?? byRole.seekers ?? null;
  const supervisorCnt = pick('supervisors','total_supervisors','supervisors_count') ?? byRole.supervisor ?? null;

  const html = `
    ${pageHeader('التقارير والإحصائيات',
      s._partial ? 'بيانات جزئية — بعض نقاط النهاية غير متاحة.' : 'بيانات مباشرة من قاعدة البيانات.',
      `<button class="btn-white" onclick="renderReports()">🔄 تحديث</button>`)}

    <div class="reports-grid">
      ${statCard('🏠','إحصائيات العقارات', [
        ['إجمالي العقارات',      pick('totalProperties','total_properties','properties_count','properties')],
        ['العقارات النشطة',      pick('activeProperties','active_properties','active_listings')],
        ['قيد المراجعة',         pick('pendingProperties','pending_properties','pending_listings')],
        ['العقارات المميزة',     pick('featuredProperties','featured_properties','featured_count')],
        ['مُباعة / مؤجرة',       pick('soldProperties','sold_properties','rented_properties','sold_rented')],
      ])}

      ${statCard('👥','إحصائيات المستخدمين', [
        ['إجمالي المستخدمين',  pick('totalUsers','total_users','users_count','users')],
        ['الملاك',               ownerCount],
        ['المكاتب العقارية',    officeCount],
        ['الباحثون',             seekerCount],
        ['المشرفون',             supervisorCnt ?? pick('supervisors_count','total_supervisors')],
      ])}

      ${statCard('📦','إحصائيات الاشتراكات', [
        ['إجمالي الاشتراكات',   pick('totalSubscriptions','total_subscriptions','subscriptions_count','subscriptions')],
        ['اشتراكات نشطة',       pick('activeSubscriptions','active_subscriptions','active_subs')],
        ['اشتراكات منتهية',     pick('expiredSubscriptions','expired_subscriptions','expired_subs')],
        ['إجمالي الإيرادات',    pick('totalRevenue','total_revenue','revenue','income')],
      ])}

      ${statCard('✅','إحصائيات التوثيق', [
        ['طلبات التوثيق',       pick('totalVerifications','total_verifications','verifications_count','verifications')],
        ['موثقة / مقبولة',      pick('approvedVerifications','approved_verifications','verified_count')],
        ['معلقة',                pick('pendingVerifications','pending_verifications')],
        ['مرفوضة',               pick('rejectedVerifications','rejected_verifications')],
      ])}

      ${statCard('📣','الإعلانات والمحتوى', [
        ['إجمالي الإعلانات',    pick('totalAds','total_ads','ads_count','ads')],
        ['إعلانات نشطة',        pick('activeAds','active_ads')],
        ['صفحات المحتوى',       pick('totalPages','total_pages','content_pages','pages_count')],
        ['طلبات الدعم',         pick('totalComplaints','total_complaints','complaints_count','support_requests')],
      ])}

      ${statCard('👔','الموظفون والنظام', [
        ['إجمالي الموظفين',     pick('totalEmployees','total_employees','employees_count','employees')],
        ['موظفون نشطون',        pick('activeEmployees','active_employees')],
        ['محادثات نشطة',        pick('activeChats','active_chats','total_chats','chats_count')],
        ['سجلات النشاط',        pick('activityLogs','activity_logs','logs_count')],
      ])}
    </div>

    ${Object.keys(byRole).length > 0 ? `
    <div class="card" style="margin-top:16px">
      <h3 class="report-card-title">📊 توزيع المستخدمين حسب الدور</h3>
      <div style="display:flex;flex-wrap:wrap;gap:12px;margin-top:12px">
        ${Object.entries(byRole).map(([k,v])=>`
          <div style="background:var(--beige);border-radius:var(--radius-md);padding:12px 20px;text-align:center;min-width:100px">
            <div style="font-size:22px;font-weight:800;color:var(--gold)">${fmtNum(v)}</div>
            <div style="font-size:12px;color:#6B7280;margin-top:4px">${k}</div>
          </div>`).join('')}
      </div>
    </div>` : ''}
  `;

  main.innerHTML = html;
}

/* ══════════════════════════════════════════════════════
   PAGE: ACTIVITY LOG
══════════════════════════════════════════════════════ */
async function renderActivityLogs() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback(['/admin/activity-log','/admin/activity-logs','/admin/logs','/admin/audit-log']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
    const data = await apiWithFallback(['/admin/settings','/admin/app-settings','/admin/config/settings']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
    const data = await apiWithFallback(['/admin/monitoring/health','/admin/health','/admin/system/health']);
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
    const data = await apiWithFallback(['/admin/ads']);
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
        <table class="data-table"><thead>${thead}</thead><tbody>${tbody}</tbody></table>
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
    const data = await apiWithFallback(['/admin/backup','/admin/backups','/admin/database/backups']);
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
        ${rows ? `<div class="table-container"><table class="data-table">
          <thead><tr><th>#</th><th>اسم الملف</th><th>الحجم</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr></thead>
          <tbody>${rows}</tbody></table></div>` : emptyHtml('💾','لا توجد نسخ احتياطية بعد','اضغط على الزر أعلاه لإنشاء نسخة احتياطية')}
      </div>`;
  } catch(e) {
    /* الـ Backend لا يدعم النسخ الاحتياطي حاليًا — عرض واجهة احترافية */
    main.innerHTML = pageHeader('النسخ الاحتياطي','') +
      `<div class="card">
        <div class="empty-state" style="padding:48px 24px">
          <div class="empty-icon">💾</div>
          <h3 style="margin-bottom:8px">خدمة النسخ الاحتياطي غير مفعّلة</h3>
          <p style="color:#6B7280;max-width:400px;margin:0 auto 20px">لم يتم تفعيل خدمة النسخ الاحتياطي التلقائية من الخادم بعد. يرجى التواصل مع مطور الـ Backend لتفعيل هذه الميزة.</p>
          <div style="display:flex;gap:12px;justify-content:center;flex-wrap:wrap">
            <button class="btn-white" onclick="renderBackup()">🔄 إعادة المحاولة</button>
            <button class="btn-primary" onclick="createBackup()">📦 محاولة إنشاء نسخة الآن</button>
          </div>
        </div>
      </div>`;
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
      ? `<div class="table-container"><table class="data-table">
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
          <table class="data-table"><thead><tr><th>المستخدم</th><th>الهاتف</th><th>السبب</th><th>تاريخ الحظر</th><th>إجراءات</th></tr></thead>
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
    const data = await apiWithFallback(['/admin/payments','/admin/payment-transactions','/admin/transactions']);
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
      `<div class="card"><div class="table-container"><table class="data-table">
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
    const data = await apiWithFallback(['/admin/complaints','/admin/reports/complaints','/admin/support/complaints']);
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
      `<div class="card"><div class="table-container"><table class="data-table">
        <thead><tr><th>#</th><th>المُبلِّغ</th><th>الموضوع</th><th>الوصف</th><th>الحالة</th><th>التاريخ</th><th>إجراءات</th></tr></thead>
        <tbody>${rows||`<tr><td colspan="7" class="empty-cell">${emptyHtml('🚩','لا توجد شكاوى')}</td></tr>`}</tbody>
      </table></div></div>`;
  } catch(e) {
    main.innerHTML = pageHeader('البلاغات والشكاوى','') + `<div class="card">${errorHtml(e.message,'renderComplaints')}</div>`;
  }
}
async function resolveComplaint(id) {
  openModal('حل الشكوى', `
    <div class="form-group"><label>ملاحظة الحل (اختياري)</label>
    <textarea id="resolve-note" rows="3" placeholder="اكتب ملاحظة الحل" style="width:100%;padding:10px;border:1px solid #E5D5B8;border-radius:8px;font-family:inherit"></textarea>
    </div>`,
    async () => {
      const note = document.getElementById('resolve-note').value.trim();
      try {
        await PATCH(`/admin/complaints/${id}`, { status:'resolved', admin_note:note });
        toast('تم حل الشكوى ✅','success'); closeModal(); renderComplaints();
      } catch(e) { toast(e.message,'error'); }
    }
  );
}

/* ══════════════════════════════════════════════════════
   PAGE: MESSAGES SUPPORT
══════════════════════════════════════════════════════ */
async function renderMessagesSupport() {
  const main = document.getElementById('main-content');
  try {
    const data = await apiWithFallback(['/admin/messages','/admin/support-messages','/admin/contact-messages','/admin/support']);
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
      `<div class="card"><div class="table-container"><table class="data-table">
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
    const data = await apiWithFallback(['/admin/ratings','/admin/reviews','/admin/user-ratings']);
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
      `<div class="card"><div class="table-container"><table class="data-table">
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
      `<div class="card"><div class="table-container"><table class="data-table">
        <thead><tr><th>#</th><th>العنوان</th><th>النوع</th><th>الحالة</th><th>آخر تعديل</th><th>إجراءات</th></tr></thead>
        <tbody>${rows||`<tr><td colspan="6" class="empty-cell">${emptyHtml('📄','لا توجد صفحات محتوى')}</td></tr>`}</tbody>
      </table></div></div>`;
  } catch(e) {
    /* إذا لم توجد بيانات — عرض واجهة فارغة احترافية */
    main.innerHTML = pageHeader('إدارة المحتوى','صفحات المحتوى الثابتة.',
      `<button class="btn-white" onclick="renderContentPages()">🔄 تحديث</button>
       <button class="btn-primary" onclick="showAddContentModal()">+ إضافة محتوى</button>`) +
      `<div class="card">
        <div class="empty-state" style="padding:48px 24px">
          <div class="empty-icon">📄</div>
          <h3 style="margin-bottom:8px">لا توجد صفحات محتوى بعد</h3>
          <p style="color:#6B7280;max-width:400px;margin:0 auto 20px">يمكنك إضافة صفحات مثل سياسة الخصوصية، شروط الاستخدام، من نحن، وغيرها.</p>
          <button class="btn-primary" onclick="showAddContentModal()">+ إضافة صفحة محتوى</button>
        </div>
      </div>`;
  }
}
function showAddContentModal() {
  openModal('إضافة صفحة محتوى', `
    <div class="form-group"><label>العنوان</label><input type="text" id="nc-title" placeholder="مثال: سياسة الخصوصية"></div>
    <div class="form-group"><label>المفتاح (slug)</label><input type="text" id="nc-slug" placeholder="مثال: privacy-policy"></div>
    <div class="form-group"><label>المحتوى</label><textarea id="nc-content" rows="6" style="font-size:13px;direction:rtl;width:100%;padding:10px;border:1px solid #E5D5B8;border-radius:8px;font-family:inherit" placeholder="أدخل محتوى الصفحة هنا..."></textarea></div>`,
    async () => {
      const title = document.getElementById('nc-title').value.trim();
      const slug  = document.getElementById('nc-slug').value.trim();
      const content = document.getElementById('nc-content').value.trim();
      if (!title) { toast('أدخل عنوان الصفحة','error'); return; }
      try {
        await POST('/admin/content-pages', { title, slug: slug||title.toLowerCase().replace(/\s+/g,'-'), content, is_active: true });
        toast('تمت إضافة الصفحة ✅','success'); closeModal(); renderContentPages();
      } catch(e) { toast(e.message,'error'); }
    }
  );
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
    const data = await apiWithFallback(['/admin/app-updates','/admin/updates']);
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
        ${rows ? `<div class="table-container"><table class="data-table">
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
      <label style="display:flex;align-items:center;gap:10px;cursor:pointer;font-size:14px;font-weight:600;color:var(--text-mid)">
        <input type="checkbox" id="upd-forced" style="width:18px;height:18px;cursor:pointer;accent-color:var(--gold)">
        تحديث إجباري
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
   MODAL SYSTEM — standard + wide variants
══════════════════════════════════════════════════════ */
let _modalConfirm = null;

function _createModal(title, bodyHtml, onConfirm, extraClass) {
  _modalConfirm = onConfirm;
  const existing = document.getElementById('modal-overlay');
  if (existing) existing.remove();
  const el = document.createElement('div');
  el.id = 'modal-overlay';
  el.className = 'modal-overlay';
  const hasConfirm = typeof onConfirm === 'function';
  el.innerHTML = `
    <div class="modal ${extraClass||''}">
      <div class="modal-header">
        <span class="modal-title">${title}</span>
        <button class="modal-close" onclick="closeModal()">✕</button>
      </div>
      <div class="modal-body">${bodyHtml}</div>
      <div class="modal-footer">
        ${hasConfirm
          ? `<button class="btn-action btn-delete" onclick="closeModal()">إلغاء</button>
             <button class="btn-action btn-approve" onclick="confirmModal()" style="padding:10px 24px;font-size:15px">حفظ ✓</button>`
          : `<button class="btn-action btn-approve" onclick="closeModal()" style="padding:10px 24px">إغلاق</button>`}
      </div>
    </div>`;
  document.body.appendChild(el);
  el.addEventListener('click', e => { if (e.target === el) closeModal(); });
}

/** Standard modal — up to 560px */
function openModal(title, bodyHtml, onConfirm) {
  _createModal(title, bodyHtml, onConfirm, '');
}

/** Wide modal — up to 900px, used for supervisor add/edit */
function openWideModal(title, bodyHtml, onConfirm) {
  _createModal(title, bodyHtml, onConfirm, 'modal-wide');
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
      desc: 'إدارة المشرفين وتعيين 21 نوع من الصلاحيات',
      content: `
        <p class="guide-content">يمكنك تعيين أي مجموعة من الصلاحيات الـ 21 لكل مشرف:</p>
        <ul class="guide-content" style="display:grid;grid-template-columns:1fr 1fr;gap:4px">
          <li>🏠 إدارة العقارات</li><li>⭐ إدارة العقارات المميزة</li>
          <li>👤 إدارة الملاك</li><li>🏢 إدارة المكاتب</li>
          <li>🔍 إدارة الباحثين</li><li>👮 إدارة المشرفين</li>
          <li>🌟 إدارة الاشتراكات</li><li>💰 إدارة المدفوعات</li>
          <li>✅ إدارة التوثيق</li><li>👔 إدارة الموظفين</li>
          <li>💬 إدارة المحادثات</li><li>📄 إدارة المحتوى</li>
          <li>📣 إدارة الإعلانات</li><li>📍 إدارة المدن</li>
          <li>📈 إدارة التقارير</li><li>💾 إدارة النسخ الاحتياطي</li>
          <li>🔒 إدارة الأمان</li><li>⚙️ إعدادات التطبيق</li>
          <li>📱 إدارة التحديثات</li><li>📋 إدارة الطلبات</li>
          <li>👥 إدارة المستخدمين (عام)</li>
        </ul>
        <p class="guide-content" style="margin-top:8px">المشرفون يدخلون عبر OTP مثل الأدمن. القائمة الجانبية تظهر فقط الأقسام المسموح بها.</p>
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
