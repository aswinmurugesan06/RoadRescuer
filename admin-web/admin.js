import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getFirestore,
  limit,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
} from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js';

const firebaseConfig = {
  apiKey: 'AIzaSyCSRfo2zyFmWSH0iGyVx5H5A0UXEla_DQw',
  authDomain: 'road-rescuer.firebaseapp.com',
  projectId: 'road-rescuer',
  storageBucket: 'road-rescuer.firebasestorage.app',
  messagingSenderId: '366952442951',
  appId: '1:366952442951:web:e8cc5676042d1d7d2d9562',
  measurementId: 'G-75TYDPH3GY',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const state = {
  admin: null,
  users: [],
  requests: [],
  payments: [],
  ratings: [],
  bills: [],
  loaded: { users: false, requests: false, payments: false, ratings: false, bills: false },
  page: 'overview',
  selectedProvider: null,
  selectedRequest: null,
  selectedPayment: null,
  providerFilter: 'ALL',
  providerSearch: '',
  overviewFilter: 'all',
  requestFilter: 'ALL',
  requestSearch: '',
  paymentFilter: 'ALL',
  globalSearch: '',
  signingIn: false,
  unsubs: [],
  shellHandlersAttached: false,
};

const NAV = [
  { key: 'overview', label: 'Overview', icon: 'grid_view' },
  { key: 'providers', label: 'Providers & Fleet', icon: 'local_shipping' },
  { key: 'requests', label: 'Service Requests', icon: 'fmd_good' },
  { key: 'revenue', label: 'Revenue & Billing', icon: 'payments' },
  { key: 'ratings', label: 'Ratings & Moderation', icon: 'grade' },
  { key: 'settings', label: 'System Settings', icon: 'tune' },
];

const ACTIVE = new Set(['PENDING', 'SEARCHING', 'ACCEPTED', 'ARRIVING', 'IN_SERVICE']);
const EN_ROUTE = new Set(['ACCEPTED', 'ARRIVING']);
const IN_SERVICE = new Set(['IN_SERVICE']);

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

const esc = (v) => String(v ?? '')
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&#039;');

const icon = (name, cls = 'text-[20px]') =>
  `<span class="material-symbols-outlined ${cls}">${name}</span>`;

const money = (v) => `₹${Number(v || 0).toLocaleString('en-IN', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})}`;

function asDate(value) {
  if (!value) return null;
  if (typeof value?.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function fmtDate(value, time = false) {
  const d = asDate(value);
  if (!d) return '—';
  return d.toLocaleString('en-IN', time
    ? { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }
    : { day: '2-digit', month: 'short', year: 'numeric' });
}

const initials = (name) => String(name || 'RR')
  .split(/\s+/)
  .filter(Boolean)
  .slice(0, 2)
  .map((p) => p[0].toUpperCase())
  .join('');

function statusClass(status) {
  const s = String(status || '').toUpperCase();
  if (['APPROVED', 'AVAILABLE', 'COMPLETED', 'PAID', 'SETTLED'].includes(s)) {
    return 'bg-emerald-50 text-emerald-700 border-emerald-200';
  }
  if (['PENDING', 'SEARCHING', 'ACCEPTED', 'ARRIVING', 'IN_SERVICE', 'ESCROW'].includes(s)) {
    return 'bg-amber-50 text-amber-700 border-amber-200';
  }
  if (['REJECTED', 'SUSPENDED', 'CANCELLED', 'FAILED', 'OFFLINE', 'DISPUTED'].includes(s)) {
    return 'bg-rose-50 text-rose-700 border-rose-200';
  }
  return 'bg-slate-50 text-slate-600 border-slate-200';
}

const badge = (status) =>
  `<span class="inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-bold ${statusClass(status)}">${esc(status || '—')}</span>`;

function toast(message, tone = 'success') {
  const el = $('#toast');
  const label = $('#toast-message');
  if (!el || !label) return;
  label.textContent = message;
  el.classList.remove('hidden');
  el.classList.add('flex');
  const ic = el.querySelector('.material-symbols-outlined');
  if (ic) {
    ic.textContent = tone === 'error' ? 'error' : 'check_circle';
    ic.className = `material-symbols-outlined text-[18px] ${tone === 'error' ? 'text-rose-400' : 'text-primary-fixed'}`;
  }
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => {
    el.classList.add('hidden');
    el.classList.remove('flex');
  }, 3000);
}

// ── Auth ────────────────────────────────────────────────────────────────

function renderLogin(error = '') {
  $('#app').innerHTML = `
    <main class="flex min-h-screen items-center justify-center px-4 py-10">
      <div class="w-full max-w-md">
        <div class="mb-7 flex flex-col items-center text-center">
          <div class="mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-white shadow-[0_8px_20px_rgba(0,69,209,0.28)]">
            ${icon('minor_crash', 'text-[30px]')}
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight">RoadRescue</h1>
          <p class="mt-1 text-[10px] font-bold uppercase tracking-[0.24em] text-primary">Platform Admin</p>
        </div>
        <div class="glass rounded-2xl p-6">
          <h2 class="text-xl font-bold">Operations sign in</h2>
          <p class="mt-1 text-xs text-on-surface-variant">Use a Firebase account with the <b>ADMIN</b> role.</p>
          <form id="login-form" class="mt-5 space-y-4">
            <label class="block">
              <span class="mb-1.5 block text-[11px] font-bold text-on-surface-variant">Email address</span>
              <div class="flex items-center gap-2 rounded-xl border border-outline-variant bg-white/80 px-3 py-3 focus-within:border-primary">
                ${icon('mail', 'text-[19px] text-outline')}
                <input id="login-email" type="email" required autocomplete="email" placeholder="admin@roadrescue.in" class="w-full bg-transparent text-sm" />
              </div>
            </label>
            <label class="block">
              <span class="mb-1.5 block text-[11px] font-bold text-on-surface-variant">Password</span>
              <div class="flex items-center gap-2 rounded-xl border border-outline-variant bg-white/80 px-3 py-3 focus-within:border-primary">
                ${icon('lock', 'text-[19px] text-outline')}
                <input id="login-password" type="password" required autocomplete="current-password" placeholder="••••••••" class="w-full bg-transparent text-sm" />
              </div>
            </label>
            <div id="login-error" class="${error ? '' : 'hidden'} rounded-xl border border-rose-200 bg-rose-50 px-3 py-2.5 text-xs text-rose-700">${esc(error)}</div>
            <button id="login-submit" class="flex h-12 w-full items-center justify-center gap-2 rounded-xl bg-primary text-sm font-bold text-white shadow-[0_8px_20px_rgba(0,69,209,0.3)] transition hover:bg-primary-container active:scale-[0.99]">
              ${icon('login', 'text-[19px]')} Sign in to Admin Console
            </button>
          </form>
          <div class="mt-5 rounded-xl border border-primary-fixed bg-primary-fixed/30 p-3 text-[11px] leading-relaxed text-on-surface-variant">
            ${icon('info', 'text-[16px] text-primary align-middle mr-1')}
            Admin access is separate from the mobile app. Only profiles with <b>role: ADMIN</b> can open this console.
          </div>
        </div>
        <p class="mt-6 text-center text-[10px] text-outline">RoadRescue Operations • Firebase secured</p>
      </div>
    </main>
  `;

  $('#login-form')?.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (state.signingIn) return;
    const email = $('#login-email').value.trim();
    const password = $('#login-password').value;
    const button = $('#login-submit');
    const errorBox = $('#login-error');
    state.signingIn = true;
    button.disabled = true;
    button.innerHTML = '<span class="spinner"></span><span>Signing in…</span>';
    errorBox.classList.add('hidden');
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err) {
      const message = err.code === 'auth/invalid-credential' || err.code === 'auth/wrong-password'
        ? 'Invalid email or password.'
        : err.code === 'auth/too-many-requests'
          ? 'Too many attempts. Try again later.'
          : err.message || 'Sign in failed.';
      errorBox.textContent = message;
      errorBox.classList.remove('hidden');
      state.signingIn = false;
      button.disabled = false;
      button.innerHTML = `${icon('login', 'text-[19px]')} Sign in to Admin Console`;
    }
  });
}

async function handleAuth(user) {
  stopListeners();
  if (!user) {
    state.admin = null;
    renderLogin();
    return;
  }
  try {
    const profile = await getDoc(doc(db, 'users', user.uid));
    const data = profile.exists() ? profile.data() : null;
    if (!data || String(data.role || '').toUpperCase() !== 'ADMIN') {
      await signOut(auth);
      renderLogin('This account does not have platform admin access.');
      return;
    }
    state.admin = { id: user.uid, email: user.email, ...data };
    renderShell();
    startListeners();
  } catch (err) {
    console.error(err);
    await signOut(auth);
    renderLogin('Could not verify admin access. Check Firestore rules and connectivity.');
  }
}

onAuthStateChanged(auth, handleAuth);

// ── Live data ───────────────────────────────────────────────────────────

function startListeners() {
  stopListeners();
  const mapping = [
    ['users', 'users'],
    ['requests', 'serviceRequests'],
    ['payments', 'payments'],
    ['ratings', 'ratings'],
    ['bills', 'bills'],
  ];
  for (const [key, collectionName] of mapping) {
    const unsub = onSnapshot(
      query(collection(db, collectionName), limit(1000)),
      (snapshot) => {
        state[key] = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
        state.loaded[key] = true;
        if (state.admin) renderContent();
      },
      (err) => {
        console.error(`Could not load ${collectionName}`, err);
        toast(`Could not load ${collectionName}`, 'error');
      },
    );
    state.unsubs.push(unsub);
  }
}

function stopListeners() {
  for (const unsub of state.unsubs) {
    try { unsub(); } catch (_) {}
  }
  state.unsubs = [];
  state.users = [];
  state.requests = [];
  state.payments = [];
  state.ratings = [];
  state.bills = [];
  state.loaded = { users: false, requests: false, payments: false, ratings: false, bills: false };
}

// ── Derived data ────────────────────────────────────────────────────────

function stats() {
  const users = state.users;
  const providers = users.filter((u) => String(u.role || '').toUpperCase() === 'PROVIDER');
  const completed = state.requests.filter((r) => String(r.status || '').toUpperCase() === 'COMPLETED');
  const cancelled = state.requests.filter((r) => String(r.status || '').toUpperCase() === 'CANCELLED');
  const active = state.requests.filter((r) => ACTIVE.has(String(r.status || '').toUpperCase()));
  const revenue = state.payments
    .filter((p) => String(p.status || '').toUpperCase() === 'COMPLETED')
    .reduce((sum, p) => sum + Number(p.amount || 0), 0);
  const ratings = state.ratings;
  const avg = ratings.length
    ? ratings.reduce((sum, r) => sum + Number(r.score || 0), 0) / ratings.length
    : 0;
  const pendingPayments = state.payments.filter((p) => !['COMPLETED'].includes(String(p.status || '').toUpperCase()));
  const escrow = pendingPayments.reduce((sum, p) => sum + Number(p.amount || 0), 0);
  const online = providers.filter((p) => String(p.availability || '').toUpperCase() === 'AVAILABLE');

  return {
    customers: users.filter((u) => String(u.role || '').toUpperCase() === 'CUSTOMER').length,
    providers: providers.length,
    pendingVerifications: providers.filter((p) => String(p.verificationStatus || 'PENDING').toUpperCase() === 'PENDING').length,
    approvedProviders: providers.filter((p) => String(p.verificationStatus || '').toUpperCase() === 'APPROVED').length,
    active: active.length,
    completed: completed.length,
    cancelled: cancelled.length,
    revenue,
    platformTake: revenue * 0.15,
    providerPayout: revenue * 0.85,
    escrow,
    frozen: state.payments
      .filter((p) => ['FAILED', 'CANCELLED'].includes(String(p.status || '').toUpperCase()))
      .reduce((sum, p) => sum + Number(p.amount || 0), 0),
    averageRating: avg,
    totalRequests: state.requests.length,
    totalPayments: state.payments.length,
    totalRatings: ratings.length,
    online: online.length,
    onlineTow: online.filter((p) => String(p.providerCategory || p.category || '').includes('TOW')).length,
    onlineMechanic: online.filter((p) => String(p.providerCategory || p.category || '').includes('MECHANIC')).length,
    onlineEv: online.filter((p) => ['BATTERY', 'FUEL'].includes(String(p.providerCategory || p.category || '').toUpperCase())).length,
  };
}

const sortDate = (items, ...fields) => [...items].sort((a, b) => {
  for (const field of fields) {
    const da = asDate(a[field])?.getTime() || 0;
    const db = asDate(b[field])?.getTime() || 0;
    if (da !== db) return db - da;
  }
  return 0;
});

const providerUser = (id) => state.users.find((u) => u.id === id) || null;
const requestById = (id) => state.requests.find((r) => r.id === id) || null;
const paymentById = (id) => state.payments.find((p) => p.id === id) || null;
const billForRequest = (id) => state.bills.find((b) => b.requestId === id) || null;

function providerProfile(user) {
  return {
    category: user?.providerCategory || user?.category || 'MECHANIC',
    status: String(user?.verificationStatus || 'PENDING').toUpperCase(),
    availability: String(user?.availability || 'OFFLINE').toUpperCase(),
    garage: user?.garageName || 'Independent Specialist',
    rating: Number(user?.rating || 0),
    ratingCount: Number(user?.ratingCount || 0),
    totalJobs: Number(user?.totalJobs || 0),
    radius: Number(user?.serviceRadiusKm || 25),
    latitude: Number(user?.latitude || 0),
    longitude: Number(user?.longitude || 0),
  };
}

// ── Shell ───────────────────────────────────────────────────────────────

function renderShell() {
  const adminName = state.admin?.name || 'Platform Admin';
  const adminEmail = state.admin?.email || '';
  $('#app').innerHTML = `
    <div class="min-h-screen">
      <aside class="fixed left-0 top-0 z-50 hidden h-screen w-72 flex-col justify-between border-r border-white/70 bg-white/70 p-4 shadow-glass backdrop-blur-2xl lg:flex">
        <div class="flex flex-col gap-6">
          <div class="flex items-center gap-3 px-2 pt-1">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-white shadow-[0_8px_20px_rgba(0,69,209,0.28)]">
              ${icon('minor_crash', 'text-[22px]')}
            </div>
            <div>
              <p class="text-lg font-extrabold leading-none tracking-tight">RoadRescue</p>
              <p class="mt-1 text-[9px] font-bold uppercase tracking-[0.18em] text-on-surface-variant">Platform Admin</p>
            </div>
          </div>
          <nav class="flex flex-col gap-1" id="sidebar-nav">
            ${NAV.map((item) => `
              <button class="nav-item group flex items-center justify-between rounded-xl px-3 py-2.5 text-left text-sm font-semibold text-on-surface-variant transition hover:bg-surface-container-high hover:text-on-surface" data-page="${item.key}">
                <span class="flex items-center gap-2.5">
                  ${icon(item.icon, 'text-[20px] text-outline')}
                  <span class="text-[13px]">${item.label}</span>
                </span>
                <span class="hidden rounded-full bg-surface-container-highest px-1.5 py-0.5 text-[9px] font-bold text-primary" data-nav-badge="${item.key}"></span>
              </button>
            `).join('')}
          </nav>
        </div>
        <div class="rounded-xl bg-surface-container-low/80 p-3 shadow-inner backdrop-blur-md">
          <div class="flex items-center justify-between">
            <span class="text-[9px] font-bold uppercase tracking-wider text-on-surface-variant">Telemetry Live</span>
            <span class="h-1.5 w-1.5 animate-ping rounded-full bg-primary"></span>
          </div>
          <div class="mt-2 flex items-center justify-between text-[11px]">
            <span>Cluster latency</span>
            <span class="font-bold text-primary">24ms</span>
          </div>
          <div class="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-surface-container-highest">
            <div class="h-full w-4/5 rounded-full bg-primary"></div>
          </div>
          <div class="mt-3 flex items-center gap-2 border-t border-white/60 pt-3">
            <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-[10px] font-extrabold text-white">${esc(initials(adminName))}</div>
            <div class="min-w-0 flex-1">
              <p class="truncate text-[11px] font-bold">${esc(adminName)}</p>
              <p class="truncate text-[9px] text-on-surface-variant">${esc(adminEmail)}</p>
            </div>
            <button id="logout-btn" class="rounded-lg p-1.5 text-on-surface-variant hover:bg-surface-container-high hover:text-rose-600" title="Sign out">${icon('logout', 'text-[17px]')}</button>
          </div>
        </div>
      </aside>

      <div class="lg:pl-72">
        <header class="fixed left-0 right-0 top-0 z-40 h-16 border-b border-white/70 bg-white/70 px-4 backdrop-blur-xl lg:left-72 lg:px-6">
          <div class="flex h-full items-center justify-between gap-3">
            <div class="flex min-w-0 items-center gap-2 lg:hidden">
              <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary text-white">${icon('minor_crash', 'text-[20px]')}</div>
              <div>
                <p class="text-sm font-extrabold leading-none">RoadRescue</p>
                <p class="mt-0.5 text-[8px] font-bold uppercase tracking-[0.18em] text-primary">Admin</p>
              </div>
            </div>
            <div class="relative hidden w-full max-w-lg items-center lg:flex">
              ${icon('search', 'absolute left-3 text-[19px] text-outline')}
              <input id="global-search" value="${esc(state.globalSearch)}" placeholder="Search dispatches, providers, transactions…" class="w-full rounded-xl border border-white/80 bg-white/75 py-2.5 pl-10 pr-3 text-xs shadow-inner focus:border-primary" />
            </div>
            <div class="flex items-center gap-2">
              <span class="hidden items-center gap-1.5 rounded-full bg-surface-container-high/80 px-3 py-1.5 text-[9px] font-bold uppercase tracking-wider text-on-surface-variant sm:flex">
                <span class="h-1.5 w-1.5 rounded-full bg-primary"></span> Live production
              </span>
              <span class="hidden items-center gap-1 rounded-full bg-primary-fixed/60 px-3 py-1.5 text-[9px] font-bold text-primary md:flex">
                ${icon('verified', 'text-[14px]')} 99.98% health
              </span>
              <button id="header-logout" class="rounded-xl p-2 text-on-surface-variant hover:bg-surface-container-high lg:hidden" title="Sign out">${icon('logout', 'text-[19px]')}</button>
            </div>
          </div>
          <div class="mt-2 flex gap-1 overflow-x-auto pb-0.5 lg:hidden" id="mobile-nav">
            ${NAV.map((item) => `
              <button class="nav-item flex shrink-0 items-center gap-1 rounded-lg px-2.5 py-1.5 text-[10px] font-bold text-on-surface-variant" data-page="${item.key}">
                ${icon(item.icon, 'text-[16px]')} ${item.label.split(' ')[0]}
              </button>
            `).join('')}
          </div>
        </header>

        <main class="min-h-screen px-4 pb-10 pt-28 lg:px-6 lg:pt-24">
          <div id="page-content"></div>
        </main>
      </div>
    </div>
  `;

  attachShellHandlers();
  renderContent();
}

function attachShellHandlers() {
  if (state.shellHandlersAttached) return;
  state.shellHandlersAttached = true;
  $('#app').addEventListener('click', (event) => {
    const pageButton = event.target.closest('[data-page]');
    if (pageButton) {
      state.page = pageButton.dataset.page;
      renderContent();
      return;
    }
    const logout = event.target.closest('#logout-btn, #header-logout');
    if (logout) {
      signOut(auth);
      return;
    }
    const providerRow = event.target.closest('[data-provider-id]');
    if (providerRow) {
      state.selectedProvider = providerRow.dataset.providerId;
      renderContent();
      return;
    }
    const requestRow = event.target.closest('[data-request-id]');
    if (requestRow) {
      state.selectedRequest = requestRow.dataset.requestId;
      renderContent();
      return;
    }
    const paymentRow = event.target.closest('[data-payment-id]');
    if (paymentRow) {
      state.selectedPayment = paymentRow.dataset.paymentId;
      renderContent();
      return;
    }
    const actionButton = event.target.closest('[data-action]');
    if (actionButton) {
      handleAction(actionButton.dataset.action, actionButton.dataset, event);
    }
  });

  $('#app').addEventListener('input', (event) => {
    const target = event.target;
    if (target.id === 'global-search') {
      state.globalSearch = target.value;
      if (['providers', 'requests', 'revenue'].includes(state.page)) renderContent();
    }
    if (target.id === 'provider-search') {
      state.providerSearch = target.value;
      renderContent();
    }
    if (target.id === 'request-search') {
      state.requestSearch = target.value;
      renderContent();
    }
    if (target.id === 'revenue-search') {
      state.globalSearch = target.value;
      renderContent();
    }
  });

  $('#app').addEventListener('change', (event) => {
    const target = event.target;
    if (target.id === 'provider-filter') {
      state.providerFilter = target.value;
      renderContent();
    }
    if (target.id === 'request-filter') {
      state.requestFilter = target.value;
      renderContent();
    }
    if (target.id === 'payment-filter') {
      state.paymentFilter = target.value;
      renderContent();
    }
  });
}

async function handleAction(action, data, event) {
  if (action === 'provider-status') {
    await updateProviderStatus(data.uid, data.status);
  }
  if (action === 'delete-rating') {
    await deleteRating(data.id);
  }
  if (action === 'go-page') {
    state.page = data.page;
    renderContent();
  }
  if (action === 'select-request') {
    state.selectedRequest = data.id;
    state.page = 'requests';
    renderContent();
  }
  if (action === 'select-payment') {
    state.selectedPayment = data.id;
    state.page = 'revenue';
    renderContent();
  }
  if (action === 'broadcast') {
    await fakeAction('Emergency broadcast sent to 384 online crews.');
  }
  if (action === 'export-ledger') {
    exportLedger();
  }
  if (action === 'export-providers') {
    exportProviders();
  }
  if (action === 'refresh') {
    stopListeners();
    startListeners();
    toast('Refreshing live data…');
  }
  if (action === 'force-dispatch') {
    await updateRequestStatus(data.id, 'SEARCHING');
  }
  if (action === 'complete-request') {
    await updateRequestStatus(data.id, 'COMPLETED');
  }
  if (action === 'cancel-request') {
    await updateRequestStatus(data.id, 'CANCELLED');
  }
  if (action === 'notify') {
    await fakeAction('Notification sent to the selected participant.');
  }
  if (action === 'audit') {
    await fakeAction('Audit note queued for the operations team.');
  }
}

async function fakeAction(message) {
  toast(message);
}

function renderContent() {
  if (!state.admin) return;
  const content = $('#page-content');
  if (!content) return;

  $$('[data-page]').forEach((button) => {
    const active = button.dataset.page === state.page;
    if (active) button.setAttribute('aria-current', 'page');
    else button.removeAttribute('aria-current');
    const ic = button.querySelector('.material-symbols-outlined');
    if (ic) {
      ic.style.fontVariationSettings = active ? "'FILL' 1" : "'FILL' 0";
      ic.className = `material-symbols-outlined text-[20px] ${active ? 'text-primary' : 'text-outline'}`;
    }
  });

  const data = stats();
  const badges = {
    providers: data.pendingVerifications,
    requests: data.active,
    revenue: state.payments.filter((p) => String(p.status || '').toUpperCase() !== 'COMPLETED').length,
  };
  $$('[data-nav-badge]').forEach((el) => {
    const n = badges[el.dataset.navBadge] || 0;
    el.textContent = n ? String(n) : '';
    el.classList.toggle('hidden', n === 0);
  });

  if (!state.loaded.users || !state.loaded.requests || !state.loaded.payments || !state.loaded.ratings || !state.loaded.bills) {
    content.innerHTML = loadingView();
    return;
  }

  if (state.page === 'providers') content.innerHTML = providersView();
  else if (state.page === 'requests') content.innerHTML = requestsView();
  else if (state.page === 'revenue') content.innerHTML = revenueView();
  else if (state.page === 'ratings') content.innerHTML = ratingsView();
  else if (state.page === 'settings') content.innerHTML = settingsView();
  else content.innerHTML = overviewView();
}

function loadingView() {
  return `
    <div class="grid gap-4">
      <div class="glass flex items-center gap-3 rounded-2xl p-5">
        <span class="spinner border-outline-variant border-t-primary"></span>
        <div><p class="text-sm font-bold">Loading live Firestore data…</p><p class="text-xs text-on-surface-variant">Users, requests, payments, bills and ratings</p></div>
      </div>
      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        ${Array.from({ length: 10 }).map(() => '<div class="glass h-28 animate-pulse rounded-2xl"></div>').join('')}
      </div>
    </div>
  `;
}

// ── Shared UI ───────────────────────────────────────────────────────────

function pageHeader(eyebrow, title, subtitle, actions = '') {
  return `
    <div class="glass flex flex-col gap-4 rounded-2xl p-5 lg:flex-row lg:items-center lg:justify-between">
      <div class="min-w-0">
        <div class="flex flex-wrap items-center gap-2">
          <span class="inline-flex items-center gap-1.5 rounded-full bg-primary/10 px-2.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-primary">
            <span class="h-1.5 w-1.5 animate-pulse rounded-full bg-primary"></span>${esc(eyebrow)}
          </span>
          <span class="text-[9px] font-bold uppercase tracking-wider text-outline">Telemetry v4.19</span>
        </div>
        <h1 class="mt-2 text-2xl font-extrabold tracking-tight lg:text-3xl">${esc(title)}</h1>
        <p class="mt-1 max-w-2xl text-xs leading-relaxed text-on-surface-variant">${esc(subtitle)}</p>
      </div>
      <div class="flex flex-wrap items-center gap-2">${actions}</div>
    </div>
  `;
}

function kpi(label, value, detail, iconName, tone = 'primary') {
  const tones = {
    primary: 'bg-primary/10 text-primary',
    secondary: 'bg-secondary-container/15 text-secondary',
    tertiary: 'bg-tertiary-fixed text-tertiary',
    success: 'bg-emerald-50 text-emerald-700',
    neutral: 'bg-surface-container text-on-surface-variant',
  };
  return `
    <div class="glass group relative overflow-hidden rounded-2xl p-4 transition-transform hover:-translate-y-0.5">
      <div class="flex items-start justify-between">
        <span class="text-[9px] font-bold uppercase tracking-wider text-on-surface-variant">${esc(label)}</span>
        <span class="rounded-lg p-1 ${tones[tone]}">${icon(iconName, 'text-[17px]')}</span>
      </div>
      <div class="my-2 text-2xl font-extrabold leading-none tracking-tight">${esc(value)}</div>
      <p class="text-[10px] text-on-surface-variant">${esc(detail)}</p>
    </div>
  `;
}

function glassCard(body, className = '') {
  return `<div class="glass rounded-2xl ${className}">${body}</div>`;
}

function sectionTitle(title, subtitle = '', action = '') {
  return `
    <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2 class="text-base font-bold tracking-tight">${esc(title)}</h2>
        ${subtitle ? `<p class="text-[10px] text-on-surface-variant">${esc(subtitle)}</p>` : ''}
      </div>
      ${action}
    </div>
  `;
}

// ── Overview ────────────────────────────────────────────────────────────

function overviewView() {
  const data = stats();
  const active = sortDate(
    state.requests.filter((r) => ACTIVE.has(String(r.status || '').toUpperCase())),
    'createdAt',
  );
  const pendingProviders = state.users.filter(
    (u) => u.role === 'PROVIDER' && String(u.verificationStatus || 'PENDING').toUpperCase() === 'PENDING',
  );
  const recentPayments = sortDate(state.payments, 'paidAt', 'createdAt').slice(0, 4);
  const lowRatings = sortDate(state.ratings.filter((r) => Number(r.score) <= 3), 'createdAt').slice(0, 2);
  const filter = state.overviewFilter;

  const filteredActive = active.filter((request) => {
    const status = String(request.status || '').toUpperCase();
    if (filter === 'enroute') return EN_ROUTE.has(status);
    if (filter === 'service') return IN_SERVICE.has(status);
    if (filter === 'pending') return status === 'PENDING' || status === 'SEARCHING';
    return true;
  });

  const hourBuckets = [0, 3, 6, 9, 12, 15, 18, 21].map((hour) => {
    const count = state.requests.filter((request) => {
      const d = asDate(request.createdAt);
      return d && d.getHours() >= hour && d.getHours() < hour + 3;
    }).length;
    return { hour, count };
  });
  const maxBucket = Math.max(1, ...hourBuckets.map((b) => b.count));

  return `
    <div class="space-y-5 fade-in">
      ${pageHeader(
        'Live operations',
        'Platform Operations Overview',
        'Real-time telemetry, provider verifications, and dispatch analytics across all service hubs.',
        `
          <button class="flex items-center gap-2 rounded-xl bg-surface-container-low px-3 py-2 text-[10px] font-bold text-on-surface shadow-sm" data-action="refresh">${icon('schedule', 'text-[16px] text-primary')} Today · Live</button>
          <button class="flex items-center gap-2 rounded-xl bg-surface-container-low px-3 py-2 text-[10px] font-bold text-on-surface shadow-sm">${icon('hub', 'text-[16px] text-primary')} All hubs</button>
          <button class="flex items-center gap-2 rounded-xl bg-white px-3 py-2 text-[10px] font-bold text-on-surface shadow-sm">${icon('download', 'text-[16px] text-on-surface-variant')} Audit log</button>
          <button class="flex items-center gap-2 rounded-xl bg-secondary-container px-4 py-2 text-[10px] font-bold text-white shadow-[0_8px_20px_rgba(254,93,53,0.3)]" data-action="broadcast">${icon('campaign', 'text-[18px] animate-pulse')} Emergency broadcast</button>
        `,
      )}

      <section class="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        ${kpi('Active dispatches', String(data.active), 'Live requests in progress', 'near_me', 'primary')}
        ${kpi('Pending verify', String(data.pendingVerifications), 'Providers awaiting review', 'badge', 'secondary')}
        ${kpi('Total rescues', String(data.completed), 'Completed lifetime jobs', 'verified_user', 'neutral')}
        ${kpi('Platform take', money(data.platformTake), '15% of gross marketplace value', 'account_balance_wallet', 'success')}
        ${kpi('Online capacity', String(data.online), 'Crews currently available', 'local_shipping', 'tertiary')}
      </section>

      <div class="grid gap-5 xl:grid-cols-[1.55fr_1fr]">
        <section class="space-y-5">
          ${glassCard(`
            <div class="p-5">
              ${sectionTitle('Live Active Incident Matrix', 'Real-time status updates from vehicle GPS beacons', `
                <div class="flex rounded-xl bg-surface-container-low p-1 text-[9px] font-bold">
                  ${[
                    ['all', `All active (${active.length})`],
                    ['enroute', `En route (${active.filter((r) => EN_ROUTE.has(String(r.status || '').toUpperCase())).length})`],
                    ['service', `In service (${active.filter((r) => IN_SERVICE.has(String(r.status || '').toUpperCase())).length})`],
                    ['pending', `Pending (${active.filter((r) => ['PENDING', 'SEARCHING'].includes(String(r.status || '').toUpperCase())).length})`],
                  ].map(([key, label]) => `
                    <button class="rounded-lg px-2.5 py-1.5 ${state.overviewFilter === key ? 'bg-white text-primary shadow-sm' : 'text-on-surface-variant'}" data-action="none" onclick="window.__rrSetRequestFilter('${key}')">${label}</button>
                  `).join('')}
                </div>
              `)}
              <div class="mt-4 overflow-x-auto">
                <table class="w-full min-w-[860px] text-left text-[11px]">
                  <thead class="bg-surface-container-low/60 text-[9px] font-bold uppercase tracking-wider text-on-surface-variant">
                    <tr>
                      <th class="rounded-l-lg px-3 py-2.5">Request</th>
                      <th class="px-3 py-2.5">Customer & vehicle</th>
                      <th class="px-3 py-2.5">Service</th>
                      <th class="px-3 py-2.5">Assigned unit</th>
                      <th class="px-3 py-2.5">Sector</th>
                      <th class="px-3 py-2.5">Stage</th>
                      <th class="rounded-r-lg px-3 py-2.5 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-surface-container/60">
                    ${filteredActive.length ? filteredActive.slice(0, 8).map((request) => `
                      <tr class="group cursor-pointer transition hover:bg-surface-container-low/40" data-request-id="${esc(request.id)}">
                        <td class="px-3 py-3 font-mono text-[10px] font-bold text-primary">#${esc(request.id.slice(0, 8).toUpperCase())}</td>
                        <td class="px-3 py-3">
                          <p class="font-bold">${esc(request.customerName || 'Customer')}</p>
                          <p class="text-[9px] text-on-surface-variant">${esc(request.vehicleModel || 'Vehicle')} • ${esc(request.vehiclePlate || '')}</p>
                        </td>
                        <td class="px-3 py-3"><span class="inline-flex items-center gap-1 rounded-full bg-surface-container px-2 py-0.5 text-[9px]">${icon(serviceIcon(request.serviceType), 'text-[12px] text-primary')} ${esc(request.serviceType || 'Assistance')}</span></td>
                        <td class="px-3 py-3">
                          <p class="font-semibold">${esc(request.providerName || 'Unassigned')}</p>
                          <p class="text-[9px] text-on-surface-variant">${esc(request.providerMobile || '')}</p>
                        </td>
                        <td class="px-3 py-3 text-[9px] text-on-surface-variant">${esc(request.customerAddress || 'Location pending')}</td>
                        <td class="px-3 py-3">${badge(request.status)}</td>
                        <td class="px-3 py-3 text-right">
                          <button class="rounded-lg bg-surface-container-low px-2.5 py-1 text-[9px] font-bold text-on-surface transition hover:bg-surface-container-high" data-action="select-request" data-id="${esc(request.id)}">Track</button>
                        </td>
                      </tr>
                    `).join('') : '<tr><td colspan="7" class="px-3 py-10 text-center text-xs text-on-surface-variant">No active incidents in this filter.</td></tr>'}
                  </tbody>
                </table>
              </div>
            </div>
          `)}

          ${glassCard(`
            <div class="p-5">
              ${sectionTitle('Hourly Dispatch Velocity', 'Incident volume across the current day')}
              <div class="mt-4 flex h-40 items-end gap-2 border-b border-surface-container px-1 pb-2">
                ${hourBuckets.map((bucket) => `
                  <div class="flex flex-1 flex-col items-center justify-end gap-1">
                    <div class="w-full max-w-[30px] rounded-t bg-primary/20 transition-all hover:bg-primary" style="height:${Math.max(10, (bucket.count / maxBucket) * 100)}%"></div>
                    <span class="text-[8px] text-on-surface-variant">${String(bucket.hour).padStart(2, '0')}:00</span>
                  </div>
                `).join('')}
              </div>
              <div class="mt-4 grid gap-2 sm:grid-cols-3">
                <div class="glass-soft flex items-center justify-between p-3"><div><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Average ticket</p><p class="text-sm font-bold">${money(state.payments.length ? data.revenue / Math.max(1, state.payments.filter((p) => String(p.status || '').toUpperCase() === 'COMPLETED').length) : 0)}</p></div>${icon('payments', 'text-[18px] text-primary')}</div>
                <div class="glass-soft flex items-center justify-between p-3"><div><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Cancelled requests</p><p class="text-sm font-bold">${data.cancelled}</p></div>${icon('cancel', 'text-[18px] text-secondary')}</div>
                <div class="glass-soft flex items-center justify-between p-3"><div><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Online crews</p><p class="text-sm font-bold text-primary">${data.online}</p></div>${icon('bolt', 'text-[18px] text-primary')}</div>
              </div>
            </div>
          `)}
        </section>

        <section class="space-y-5">
          ${glassCard(`
            <div class="p-5">
              ${sectionTitle('Provider Verifications', `${pendingProviders.length} providers awaiting review`, `<button class="text-[10px] font-bold text-primary" data-page="providers">Open queue →</button>`)}
              <div class="mt-3 space-y-2">
                ${pendingProviders.length ? pendingProviders.slice(0, 4).map((u) => `
                  <div class="glass-soft flex items-center gap-2.5 p-3">
                    <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-[10px] font-extrabold text-primary">${esc(initials(u.name))}</div>
                    <div class="min-w-0 flex-1">
                      <p class="truncate text-[11px] font-bold">${esc(u.name || 'Provider')}</p>
                      <p class="truncate text-[9px] text-on-surface-variant">${esc(u.garageName || u.providerCategory || 'Provider')}</p>
                    </div>
                    <button class="rounded-lg bg-primary px-2 py-1 text-[8px] font-bold text-white" data-action="provider-status" data-uid="${esc(u.id)}" data-status="APPROVED">Approve</button>
                  </div>
                `).join('') : '<p class="py-8 text-center text-xs text-on-surface-variant">No pending verifications.</p>'}
              </div>
            </div>
          `)}

          ${glassCard(`
            <div class="p-5">
              ${sectionTitle('Safety & Moderation', 'Flagged reviews and operational alerts')}
              <div class="mt-3 space-y-2">
                ${lowRatings.length ? lowRatings.map((r) => `
                  <div class="glass-soft flex items-start gap-2 p-3">
                    ${icon('report_problem', 'text-[18px] text-secondary shrink-0')}
                    <div class="min-w-0"><p class="text-[10px] font-bold">${esc(r.score)}-star review flagged</p><p class="truncate text-[9px] text-on-surface-variant">${esc(r.review || 'No written review')}</p></div>
                  </div>
                `).join('') : `<div class="glass-soft flex items-start gap-2 p-3">${icon('verified', 'text-[18px] text-primary shrink-0')}<div><p class="text-[10px] font-bold">No safety flags</p><p class="text-[9px] text-on-surface-variant">All recent reviews are healthy.</p></div></div>`}
                <div class="glass-soft flex items-start gap-2 p-3">
                  ${icon('emergency', 'text-[18px] text-primary shrink-0')}
                  <div><p class="text-[10px] font-bold">Live dispatch monitoring</p><p class="text-[9px] text-on-surface-variant">${data.active} active requests currently tracked.</p></div>
                </div>
              </div>
            </div>
          `)}

          ${glassCard(`
            <div class="p-5">
              ${sectionTitle('Infra Status', 'Firebase and platform services')}
              <div class="mt-3 grid grid-cols-2 gap-2">
                ${[
                  ['Cloud Firestore', 'Live'],
                  ['Firebase Auth', 'Healthy'],
                  ['FCM Push', 'Connected'],
                  ['MapLibre GL', 'Rendering'],
                ].map(([label, value]) => `
                  <div class="glass-soft p-2.5">
                    <div class="flex items-center justify-between"><span class="text-[8px] uppercase tracking-wider text-on-surface-variant">${label}</span><span class="h-1.5 w-1.5 rounded-full bg-primary"></span></div>
                    <p class="mt-1 text-[10px] font-bold text-primary">${value}</p>
                  </div>
                `).join('')}
              </div>
            </div>
          `)}
        </section>
      </div>
    </div>
  `;
}

window.__rrSetRequestFilter = (filter) => {
  state.overviewFilter = filter;
  renderContent();
};

// ── Providers ───────────────────────────────────────────────────────────

function providersView() {
  const providers = state.users.filter((u) => String(u.role || '').toUpperCase() === 'PROVIDER');
  const filtered = providers.filter((u) => {
    const p = providerProfile(u);
    const statusOk = state.providerFilter === 'ALL' || p.status === state.providerFilter;
    const term = (state.providerSearch || state.globalSearch).trim().toLowerCase();
    const hay = `${u.name || ''} ${u.email || ''} ${u.mobile || ''} ${p.garage}`.toLowerCase();
    return statusOk && (!term || hay.includes(term));
  });
  const selected = providerUser(state.selectedProvider) || filtered[0] || providers[0] || null;
  if (selected && state.selectedProvider !== selected.id) state.selectedProvider = selected.id;
  const p = selected ? providerProfile(selected) : null;

  return `
    <div class="space-y-5 fade-in">
      ${pageHeader(
        'Providers & fleet',
        'Provider Credentials & Compliance',
        'Review safety clearances, service capabilities, and operational readiness before activating dispatch.',
        `
          <button class="flex items-center gap-2 rounded-xl bg-surface-container-low px-3 py-2 text-[10px] font-bold shadow-sm" data-action="export-providers">${icon('download', 'text-[16px] text-primary')} Export providers</button>
          <button class="flex items-center gap-2 rounded-xl bg-white px-3 py-2 text-[10px] font-bold shadow-sm">${icon('fact_check', 'text-[16px] text-on-surface-variant')} Audit backlog (${stats().pendingVerifications})</button>
        `,
      )}

      <div class="grid gap-5 xl:grid-cols-[0.9fr_1.5fr]">
        <section class="glass rounded-2xl p-4">
          <div class="flex items-center gap-2 rounded-xl border border-outline-variant bg-white/80 px-3 py-2.5">
            ${icon('search', 'text-[18px] text-outline')}
            <input id="provider-search" value="${esc(state.providerSearch)}" placeholder="Search providers, garages, email…" class="w-full bg-transparent text-xs" />
          </div>
          <div class="mt-2 flex items-center justify-between gap-2">
            <span class="text-[9px] font-bold uppercase tracking-wider text-on-surface-variant">${filtered.length} of ${providers.length} providers</span>
            <select id="provider-filter" class="rounded-lg border border-outline-variant bg-white/80 px-2 py-1.5 text-[9px] font-bold">
              ${['ALL', 'PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'].map((s) => `<option value="${s}" ${state.providerFilter === s ? 'selected' : ''}>${s === 'ALL' ? 'All statuses' : s}</option>`).join('')}
            </select>
          </div>
          <div class="mt-3 space-y-2">
            ${filtered.length ? filtered.map((u) => {
              const pp = providerProfile(u);
              const active = selected && selected.id === u.id;
              return `
                <button class="w-full rounded-xl border p-3 text-left transition ${active ? 'border-primary/30 bg-primary-fixed/30 shadow-sm' : 'border-white/70 bg-white/40 hover:bg-white/80'}" data-provider-id="${esc(u.id)}">
                  <div class="flex items-center gap-2.5">
                    <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${active ? 'bg-primary text-white' : 'bg-surface-container-high text-primary'} text-[10px] font-extrabold">${esc(initials(u.name))}</div>
                    <div class="min-w-0 flex-1">
                      <p class="truncate text-[11px] font-bold">${esc(u.name || 'Provider')}</p>
                      <p class="truncate text-[9px] text-on-surface-variant">${esc(pp.garage)} • ${esc(pp.category)}</p>
                    </div>
                    ${badge(pp.status)}
                  </div>
                  <div class="mt-2 flex items-center justify-between text-[9px] text-on-surface-variant">
                    <span>★ ${pp.rating.toFixed(1)} (${pp.ratingCount})</span>
                    <span>${pp.totalJobs} jobs</span>
                  </div>
                </button>
              `;
            }).join('') : '<p class="py-10 text-center text-xs text-on-surface-variant">No providers match this filter.</p>'}
          </div>
        </section>

        <section class="space-y-5">
          ${selected ? `
            ${glassCard(`
              <div class="p-5">
                <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                  <div class="flex items-center gap-3">
                    <div class="relative flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-lg font-extrabold text-white shadow-lg">${esc(initials(selected.name))}<span class="absolute -bottom-1 -right-1 h-3.5 w-3.5 rounded-full ${p.status === 'APPROVED' ? 'bg-emerald-500' : 'bg-amber-500'} ring-2 ring-white"></span></div>
                    <div>
                      <div class="flex items-center gap-1.5"><h2 class="text-lg font-bold">${esc(selected.name || 'Provider')}</h2>${icon('verified', 'text-[16px] text-primary')}</div>
                      <p class="text-[11px] text-on-surface-variant">${esc(p.garage)} • ${esc(p.category)}</p>
                      <p class="mt-0.5 text-[9px] font-bold uppercase tracking-wider text-primary">${esc(selected.email || '')}</p>
                    </div>
                  </div>
                  <div class="flex flex-wrap gap-1.5">${badge(p.status)}${badge(p.availability)}</div>
                </div>
                <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
                  <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Rating</p><p class="mt-1 text-sm font-extrabold text-amber-500">★ ${p.rating.toFixed(2)}</p></div>
                  <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Total jobs</p><p class="mt-1 text-sm font-extrabold">${p.totalJobs}</p></div>
                  <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Coverage</p><p class="mt-1 text-sm font-extrabold">${p.radius} km</p></div>
                  <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Base</p><p class="mt-1 truncate text-[10px] font-bold">${p.latitude.toFixed(2)}, ${p.longitude.toFixed(2)}</p></div>
                </div>
                <div class="mt-4 flex flex-wrap gap-2">
                  ${p.status !== 'APPROVED' ? `<button class="rounded-xl bg-primary px-4 py-2 text-[10px] font-bold text-white shadow-sm" data-action="provider-status" data-uid="${esc(selected.id)}" data-status="APPROVED">${icon('verified_user', 'text-[15px]')} Approve & activate</button>` : ''}
                  ${p.status === 'PENDING' ? `<button class="rounded-xl bg-secondary-fixed px-4 py-2 text-[10px] font-bold text-secondary" data-action="provider-status" data-uid="${esc(selected.id)}" data-status="REJECTED">Reject</button>` : ''}
                  ${p.status === 'APPROVED' ? `<button class="rounded-xl bg-surface-container-high px-4 py-2 text-[10px] font-bold" data-action="provider-status" data-uid="${esc(selected.id)}" data-status="SUSPENDED">Suspend provider</button>` : ''}
                  <button class="rounded-xl bg-white/80 px-4 py-2 text-[10px] font-bold shadow-sm" data-action="notify">Send notice</button>
                </div>
              </div>
            `)}
            ${glassCard(`
              <div class="p-5">
                ${sectionTitle('Compliance dossier', 'Firebase profile and operational readiness')}
                <div class="mt-3 space-y-2">
                  ${[
                    ['Identity and email', selected.isVerified ? 'Verified' : 'Pending', !!selected.isVerified],
                    ['Firebase account', selected.email ? 'Linked' : 'Missing email', !!selected.email],
                    ['Service category', p.category, !!p.category],
                    ['Depot location', p.latitude && p.longitude ? 'GPS configured' : 'Not configured', !!(p.latitude && p.longitude)],
                    ['Availability', p.availability, p.availability === 'AVAILABLE'],
                    ['Rating threshold', `${p.rating.toFixed(1)} / 5.0`, p.rating >= 4.0],
                  ].map(([label, value, ok]) => `
                    <div class="glass-soft flex items-center justify-between p-3">
                      <div class="flex items-center gap-2">${icon(ok ? 'check_circle' : 'error', `text-[17px] ${ok ? 'text-primary' : 'text-secondary'}`)}<span class="text-[10px] font-semibold">${label}</span></div>
                      <span class="text-[9px] font-bold ${ok ? 'text-primary' : 'text-secondary'}">${esc(value)}</span>
                    </div>
                  `).join('')}
                </div>
              </div>
            `)}
          ` : '<div class="glass rounded-2xl p-10 text-center text-sm text-on-surface-variant">No provider selected.</div>'}
        </section>
      </div>
    </div>
  `;
}

// ── Requests ────────────────────────────────────────────────────────────

function requestsView() {
  const filtered = sortDate(state.requests, 'createdAt').filter((r) => {
    const status = String(r.status || '').toUpperCase();
    const statusOk = state.requestFilter === 'ALL' || status === state.requestFilter;
    const term = (state.requestSearch || state.globalSearch).trim().toLowerCase();
    const hay = `${r.serviceType || ''} ${r.customerName || ''} ${r.providerName || ''} ${r.vehiclePlate || ''} ${r.problemDescription || ''}`.toLowerCase();
    return statusOk && (!term || hay.includes(term));
  });
  const selected = requestById(state.selectedRequest) || filtered[0] || state.requests[0] || null;
  if (selected && state.selectedRequest !== selected.id) state.selectedRequest = selected.id;
  const bill = selected ? billForRequest(selected.id) : null;
  const payment = selected ? state.payments.find((p) => p.requestId === selected.id) : null;
  const provider = selected ? providerUser(selected.providerId) : null;

  return `
    <div class="space-y-5 fade-in">
      ${pageHeader(
        'Service requests',
        'Live Incident Operations',
        'Monitor every roadside request, dispatch stage, provider assignment and billing state.',
        `<button class="flex items-center gap-2 rounded-xl bg-surface-container-low px-3 py-2 text-[10px] font-bold shadow-sm" data-action="refresh">${icon('refresh', 'text-[16px] text-primary')} Refresh</button>
         <button class="flex items-center gap-2 rounded-xl bg-secondary-fixed px-3 py-2 text-[10px] font-bold text-secondary shadow-sm" data-action="broadcast">${icon('campaign', 'text-[16px]')} Broadcast</button>`,
      )}

      <div class="grid gap-5 xl:grid-cols-[0.8fr_1.7fr]">
        <section class="glass rounded-2xl p-4">
          <div class="flex items-center gap-2 rounded-xl border border-outline-variant bg-white/80 px-3 py-2.5">
            ${icon('search', 'text-[18px] text-outline')}
            <input id="request-search" value="${esc(state.requestSearch)}" placeholder="Search requests, customers, plates…" class="w-full bg-transparent text-xs" />
          </div>
          <div class="mt-2 flex items-center justify-between">
            <span class="text-[9px] font-bold uppercase tracking-wider text-on-surface-variant">${filtered.length} requests</span>
            <select id="request-filter" class="rounded-lg border border-outline-variant bg-white/80 px-2 py-1.5 text-[9px] font-bold">
              ${['ALL', 'PENDING', 'SEARCHING', 'ACCEPTED', 'ARRIVING', 'IN_SERVICE', 'COMPLETED', 'CANCELLED'].map((s) => `<option value="${s}" ${state.requestFilter === s ? 'selected' : ''}>${s === 'ALL' ? 'All statuses' : s}</option>`).join('')}
            </select>
          </div>
          <div class="mt-3 max-h-[620px] space-y-2 overflow-y-auto pr-1">
            ${filtered.length ? filtered.map((r) => {
              const active = selected && selected.id === r.id;
              return `
                <button class="w-full rounded-xl border p-3 text-left transition ${active ? 'border-primary/30 bg-primary-fixed/30 shadow-sm' : 'border-white/70 bg-white/40 hover:bg-white/80'}" data-request-id="${esc(r.id)}">
                  <div class="flex items-start justify-between gap-2">
                    <div class="min-w-0">
                      <p class="truncate text-[11px] font-bold">${esc(r.serviceType || 'Assistance')}</p>
                      <p class="truncate text-[9px] text-on-surface-variant">${esc(r.customerName || 'Customer')} • ${esc(r.vehicleModel || 'Vehicle')}</p>
                    </div>
                    ${badge(r.status)}
                  </div>
                  <div class="mt-2 flex items-center justify-between text-[8px] text-on-surface-variant">
                    <span>${esc(r.vehiclePlate || 'No plate')}</span>
                    <span>${fmtDate(r.createdAt)}</span>
                  </div>
                </button>
              `;
            }).join('') : '<p class="py-10 text-center text-xs text-on-surface-variant">No requests match this filter.</p>'}
          </div>
        </section>

        <section class="space-y-5">
          ${selected ? `
            ${glassCard(`
              <div class="p-5">
                <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <div class="flex flex-wrap items-center gap-2">
                      ${badge(selected.status)}
                      <span class="font-mono text-[9px] font-bold text-primary">#${esc(selected.id.slice(0, 8).toUpperCase())}</span>
                      <span class="rounded-full bg-surface-container-high px-2 py-0.5 text-[8px] font-bold text-on-surface-variant">${esc(selected.category || 'SERVICE')}</span>
                    </div>
                    <h2 class="mt-2 text-xl font-extrabold tracking-tight">${esc(selected.vehicleModel || 'Roadside request')}</h2>
                    <p class="mt-1 text-[10px] text-on-surface-variant">${esc(selected.problemDescription || 'Roadside assistance request')}</p>
                  </div>
                  <div class="flex flex-wrap gap-2">
                    <button class="rounded-xl bg-surface-container-low px-3 py-2 text-[9px] font-bold" data-action="notify">${icon('headset_mic', 'text-[15px] text-primary')} Contact</button>
                    ${['PENDING', 'SEARCHING'].includes(String(selected.status || '').toUpperCase()) ? `<button class="rounded-xl bg-primary px-3 py-2 text-[9px] font-bold text-white" data-action="force-dispatch" data-id="${esc(selected.id)}">${icon('swap_horiz', 'text-[15px]')} Force dispatch</button>` : ''}
                    ${String(selected.status || '').toUpperCase() === 'IN_SERVICE' ? `<button class="rounded-xl bg-primary px-3 py-2 text-[9px] font-bold text-white" data-action="complete-request" data-id="${esc(selected.id)}">${icon('task_alt', 'text-[15px]')} Complete</button>` : ''}
                  </div>
                </div>
              </div>
            `)}

            ${glassCard(`
              <div class="p-5">
                ${sectionTitle('Live dispatch map', 'Provider and breakdown location')}
                ${mapPlaceholder(selected, provider)}
                <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
                  <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Distance</p><p class="mt-1 text-xs font-bold">${selected.customerLatitude ? 'GPS live' : '—'}</p></div>
                  <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Stage</p><p class="mt-1 text-xs font-bold">${esc(selected.status)}</p></div>
                  <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Estimate</p><p class="mt-1 text-xs font-bold">${money(selected.finalAmount ?? selected.estimatedAmount ?? 0)}</p></div>
                  <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Created</p><p class="mt-1 text-[10px] font-bold">${fmtDate(selected.createdAt, true)}</p></div>
                </div>
              </div>
            `)}

            ${glassCard(`
              <div class="p-5">
                ${sectionTitle('Lifecycle progression', 'Dispatch stages from request to completion')}
                <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-5">
                  ${['Requested', 'Accepted', 'En route', 'In service', 'Completed'].map((step, index) => {
                    const status = String(selected.status || '').toUpperCase();
                    const stepIndex = status === 'COMPLETED' ? 4 : status === 'IN_SERVICE' ? 3 : status === 'ARRIVING' ? 2 : status === 'ACCEPTED' ? 1 : 0;
                    const done = index < stepIndex;
                    const active = index === stepIndex;
                    return `<div class="rounded-xl p-2.5 ${active ? 'bg-primary text-white shadow-md' : 'glass-soft'}">
                      <div class="flex items-center justify-between">${icon(done ? 'check_circle' : active ? 'autorenew' : 'lock', `text-[16px] ${active ? 'text-white' : done ? 'text-primary' : 'text-outline'}`)}<span class="text-[8px] ${active ? 'text-white/75' : 'text-on-surface-variant'}">${index + 1}</span></div>
                      <p class="mt-1 text-[10px] font-bold ${active ? 'text-white' : ''}">${step}</p>
                    </div>`;
                  }).join('')}
                </div>
              </div>
            `)}

            <div class="grid gap-5 md:grid-cols-2">
              ${glassCard(`
                <div class="p-5">
                  ${sectionTitle('Customer dossier', 'Requester and vehicle')}
                  <div class="mt-3 flex items-center gap-3">
                    <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-surface-container-high text-sm font-extrabold text-primary">${esc(initials(selected.customerName))}</div>
                    <div><p class="text-sm font-bold">${esc(selected.customerName || 'Customer')}</p><p class="text-[10px] text-on-surface-variant">${esc(selected.customerMobile || 'No mobile')}</p></div>
                  </div>
                  <div class="mt-3 space-y-1.5 text-[10px]">
                    <div class="flex justify-between"><span class="text-on-surface-variant">Vehicle</span><span class="font-semibold">${esc(selected.vehicleModel || '—')}</span></div>
                    <div class="flex justify-between"><span class="text-on-surface-variant">Plate</span><span class="font-mono font-semibold">${esc(selected.vehiclePlate || '—')}</span></div>
                    <div class="flex justify-between"><span class="text-on-surface-variant">Address</span><span class="max-w-[180px] truncate text-right font-semibold">${esc(selected.customerAddress || '—')}</span></div>
                  </div>
                </div>
              `)}
              ${glassCard(`
                <div class="p-5">
                  ${sectionTitle('Assigned provider', 'Responder and rig')}
                  <div class="mt-3 flex items-center gap-3">
                    <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-primary text-sm font-extrabold text-white">${esc(initials(selected.providerName || 'NA'))}</div>
                    <div><p class="text-sm font-bold">${esc(selected.providerName || 'Unassigned')}</p><p class="text-[10px] text-on-surface-variant">${esc(selected.providerMobile || 'Matching in progress')}</p></div>
                  </div>
                  <div class="mt-3 space-y-1.5 text-[10px]">
                    <div class="flex justify-between"><span class="text-on-surface-variant">Category</span><span class="font-semibold">${esc(provider?.providerCategory || selected.category || '—')}</span></div>
                    <div class="flex justify-between"><span class="text-on-surface-variant">Rating</span><span class="font-semibold text-amber-500">★ ${Number(provider?.rating || 0).toFixed(2)}</span></div>
                    <div class="flex justify-between"><span class="text-on-surface-variant">Jobs</span><span class="font-semibold">${Number(provider?.totalJobs || 0)}</span></div>
                  </div>
                </div>
              `)}
            </div>

            ${glassCard(`
              <div class="p-5">
                ${sectionTitle('Billing preview', bill ? 'Invoice and payment state' : 'Estimated amount')}
                <div class="mt-3 space-y-2 text-[10px]">
                  ${bill ? (bill.items || []).map((item) => `<div class="flex justify-between"><span class="text-on-surface-variant">${esc(item.description)} × ${esc(item.quantity)}</span><span class="font-semibold">${money(item.total)}</span></div>`).join('') : `<div class="flex justify-between"><span class="text-on-surface-variant">Estimated service amount</span><span class="font-semibold">${money(selected.estimatedAmount || 0)}</span></div>`}
                  ${bill ? `<div class="mt-2 flex justify-between rounded-xl bg-surface-container-low p-3"><span class="font-bold">Invoice total</span><span class="text-base font-extrabold text-primary">${money(bill.grandTotal)}</span></div>` : ''}
                  ${payment ? `<div class="flex items-center justify-between">${badge(payment.status)}<span class="font-mono text-[9px] text-on-surface-variant">${esc(payment.transactionId || '')}</span></div>` : ''}
                </div>
              </div>
            `)}
          ` : '<div class="glass rounded-2xl p-10 text-center text-sm text-on-surface-variant">No request selected.</div>'}
        </section>
      </div>
    </div>
  `;
}

function mapPlaceholder(request, provider) {
  return `
    <div class="relative mt-3 h-64 overflow-hidden rounded-2xl bg-gradient-to-br from-[#e0ecff] via-[#d6e5fb] to-[#cddff8]">
      <svg class="absolute inset-0 h-full w-full opacity-50" fill="none" viewBox="0 0 700 260" preserveAspectRatio="none">
        <path d="M-20 40 Q 140 80, 260 150 T 460 210 T 720 230" stroke="white" stroke-linecap="round" stroke-width="22"></path>
        <path d="M-20 40 Q 140 80, 260 150 T 460 210 T 720 230" stroke="#0045d1" stroke-dasharray="9 7" stroke-linecap="round" stroke-width="3"></path>
        <path d="M120 -20 L 220 280" stroke="white" stroke-width="10" opacity=".6"></path>
      </svg>
      <div class="absolute left-[22%] top-[23%] rounded-xl bg-primary px-2.5 py-1 text-[9px] font-bold text-white shadow-lg">${icon('local_shipping', 'text-[13px] align-middle mr-0.5')} ${esc(provider?.name || request.providerName || 'Unit')}</div>
      <div class="absolute bottom-[22%] right-[20%] rounded-xl bg-secondary-container px-2.5 py-1 text-[9px] font-bold text-white shadow-lg">${icon('fmd_bad', 'text-[13px] align-middle mr-0.5')} ${esc(request.customerName || 'Customer')}</div>
      <div class="absolute inset-x-3 bottom-3 flex items-center justify-between rounded-xl bg-white/85 px-3 py-2 text-[9px] font-semibold backdrop-blur">
        <span>${icon('location_on', 'text-[14px] text-secondary align-middle mr-1')}${esc(request.customerAddress || 'Location pending')}</span>
        <span class="font-mono text-[8px] text-on-surface-variant">${request.customerLatitude ? Number(request.customerLatitude).toFixed(4) : '—'}, ${request.customerLongitude ? Number(request.customerLongitude).toFixed(4) : '—'}</span>
      </div>
    </div>
  `;
}

// ── Revenue ─────────────────────────────────────────────────────────────

function revenueView() {
  const data = stats();
  const payments = sortDate(state.payments, 'paidAt', 'createdAt');
  const filtered = payments.filter((p) => {
    const status = String(p.status || '').toUpperCase();
    if (state.paymentFilter === 'ALL') return true;
    if (state.paymentFilter === 'SETTLED') return status === 'COMPLETED';
    if (state.paymentFilter === 'ESCROW') return status === 'PENDING' || status === 'PROCESSING';
    if (state.paymentFilter === 'DISPUTED') return status === 'FAILED' || status === 'CANCELLED';
    return status === state.paymentFilter;
  });
  const selected = paymentById(state.selectedPayment) || filtered[0] || payments[0] || null;
  if (selected && state.selectedPayment !== selected.id) state.selectedPayment = selected.id;
  const bill = selected ? state.bills.find((b) => b.id === selected.billId || b.requestId === selected.requestId) : null;

  const buckets = [0, 3, 6, 9, 12, 15, 18, 21].map((hour) => {
    const amount = state.payments
      .filter((p) => {
        const d = asDate(p.paidAt || p.createdAt);
        return d && d.getHours() >= hour && d.getHours() < hour + 3;
      })
      .reduce((sum, p) => sum + Number(p.amount || 0), 0);
    return { hour, amount };
  });
  const maxAmount = Math.max(1, ...buckets.map((b) => b.amount));

  return `
    <div class="space-y-5 fade-in">
      ${pageHeader(
        'Revenue & billing',
        'Settlement & Escrow Ledger',
        'Audit gross marketplace value, platform take, provider payouts, and frozen capital.',
        `<button class="flex items-center gap-2 rounded-xl bg-surface-container-low px-3 py-2 text-[10px] font-bold shadow-sm" data-action="export-ledger">${icon('download', 'text-[16px] text-primary')} Export CSV</button>
         <button class="flex items-center gap-2 rounded-xl bg-secondary-fixed px-3 py-2 text-[10px] font-bold text-secondary shadow-sm">${icon('gavel', 'text-[16px]')} Disputes (${payments.filter((p) => ['FAILED', 'CANCELLED'].includes(String(p.status || '').toUpperCase())).length})</button>
         <button class="flex items-center gap-2 rounded-xl bg-primary px-3 py-2 text-[10px] font-bold text-white shadow-sm" data-action="audit">${icon('bolt', 'text-[16px]')} Run escrow sweep</button>`,
      )}

      <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        ${kpi('GMV', money(data.revenue), 'Completed payment volume', 'account_balance', 'primary')}
        ${kpi('Platform take', money(data.platformTake), '15% net take rate', 'pie_chart', 'success')}
        ${kpi('Provider payouts', money(data.providerPayout), '85% provider share', 'send_money', 'neutral')}
        ${kpi('Escrow holds', money(data.escrow), 'Pending / processing payments', 'lock_clock', 'secondary')}
        ${kpi('Frozen capital', money(data.frozen), 'Failed or cancelled payments', 'warning', 'secondary')}
      </div>

      <div class="grid gap-5 xl:grid-cols-[1.5fr_1fr]">
        <section class="space-y-5">
          ${glassCard(`
            <div class="p-5">
              ${sectionTitle('Live transaction ledger', `${filtered.length} payment records`, `
                <select id="payment-filter" class="rounded-lg border border-outline-variant bg-white/80 px-2 py-1.5 text-[9px] font-bold">
                  ${['ALL', 'COMPLETED', 'PENDING', 'PROCESSING', 'FAILED', 'CANCELLED'].map((s) => `<option value="${s}" ${state.paymentFilter === s ? 'selected' : ''}>${s === 'ALL' ? 'All statuses' : s}</option>`).join('')}
                </select>
              `)}
              <div class="mt-4 overflow-x-auto">
                <table class="w-full min-w-[760px] text-left text-[10px]">
                  <thead class="bg-surface-container-low/60 text-[8px] font-bold uppercase tracking-wider text-on-surface-variant">
                    <tr>
                      <th class="rounded-l-lg px-3 py-2.5">Transaction</th>
                      <th class="px-3 py-2.5">Customer</th>
                      <th class="px-3 py-2.5">Provider</th>
                      <th class="px-3 py-2.5">Method</th>
                      <th class="px-3 py-2.5">State</th>
                      <th class="px-3 py-2.5 text-right">Amount</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-surface-container/60">
                    ${filtered.length ? filtered.slice(0, 12).map((p) => `
                      <tr class="cursor-pointer transition hover:bg-surface-container-low/50 ${selected && selected.id === p.id ? 'bg-primary-fixed/20' : ''}" data-payment-id="${esc(p.id)}">
                        <td class="px-3 py-3"><p class="font-mono text-[9px] font-bold text-primary">${esc(p.transactionId || p.id.slice(0, 8))}</p><p class="text-[8px] text-on-surface-variant">${esc(p.receiptNumber || '')}</p></td>
                        <td class="px-3 py-3"><p class="font-semibold">${esc(p.customerName || 'Customer')}</p><p class="text-[8px] text-on-surface-variant">${fmtDate(p.paidAt || p.createdAt)}</p></td>
                        <td class="px-3 py-3 text-[9px]">${esc(p.providerName || 'Provider')}</td>
                        <td class="px-3 py-3 text-[9px]">${esc(p.method || '—')}</td>
                        <td class="px-3 py-3">${badge(p.status)}</td>
                        <td class="px-3 py-3 text-right font-bold text-primary">${money(p.amount)}</td>
                      </tr>
                    `).join('') : '<tr><td colspan="6" class="px-3 py-10 text-center text-xs text-on-surface-variant">No payments match this filter.</td></tr>'}
                  </tbody>
                </table>
              </div>
            </div>
          `)}

          ${glassCard(`
            <div class="p-5">
              ${sectionTitle('Settlement velocity', 'Payment ingestion by time of day')}
              <div class="mt-4 flex h-40 items-end gap-2 border-b border-surface-container px-1 pb-2">
                ${buckets.map((b) => `<div class="flex flex-1 flex-col items-center justify-end gap-1"><div class="w-full max-w-[30px] rounded-t bg-primary/25 transition-all hover:bg-primary" style="height:${Math.max(8, (b.amount / maxAmount) * 100)}%"></div><span class="text-[8px] text-on-surface-variant">${String(b.hour).padStart(2, '0')}:00</span></div>`).join('')}
              </div>
            </div>
          `)}
        </section>

        <section class="space-y-5">
          ${selected ? glassCard(`
            <div class="p-5">
              ${sectionTitle('Deep audit inspector', `Invoice ${esc(selected.transactionId || '')}`, `<span class="rounded-full bg-surface-container-high px-2 py-0.5 text-[8px] font-bold text-primary">${esc(selected.status)}</span>`)}
              <div class="mt-3 glass-soft flex items-center gap-2.5 p-3">
                <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary text-[10px] font-extrabold text-white">${esc(initials(selected.customerName))}</div>
                <div class="min-w-0 flex-1"><p class="text-[11px] font-bold">${esc(selected.customerName || 'Customer')}</p><p class="truncate text-[9px] text-on-surface-variant">${esc(selected.vehicleModel || '')} • ${esc(selected.vehiclePlate || '')}</p></div>
                <span class="text-[9px] font-bold text-primary">${money(selected.amount)}</span>
              </div>
              <div class="mt-3 space-y-1.5 text-[10px]">
                <div class="flex justify-between"><span class="text-on-surface-variant">Provider</span><span class="font-semibold">${esc(selected.providerName || '—')}</span></div>
                <div class="flex justify-between"><span class="text-on-surface-variant">Method</span><span class="font-semibold">${esc(selected.method || '—')}</span></div>
                <div class="flex justify-between"><span class="text-on-surface-variant">Paid</span><span class="font-semibold">${fmtDate(selected.paidAt || selected.createdAt, true)}</span></div>
                <div class="flex justify-between"><span class="text-on-surface-variant">Receipt</span><span class="font-mono text-[9px] font-semibold">${esc(selected.receiptNumber || '—')}</span></div>
              </div>
              ${bill ? `
                <div class="mt-3 space-y-1.5 rounded-xl bg-surface-container-low/70 p-3 text-[9px]">
                  ${(bill.items || []).map((item) => `<div class="flex justify-between"><span class="text-on-surface-variant">${esc(item.description)}</span><span class="font-semibold">${money(item.total)}</span></div>`).join('')}
                </div>
              ` : ''}
              <div class="mt-3 grid grid-cols-2 gap-2">
                <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Platform 15%</p><p class="mt-1 text-xs font-bold text-primary">${money(Number(selected.amount || 0) * 0.15)}</p></div>
                <div class="glass-soft p-2.5"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">Provider 85%</p><p class="mt-1 text-xs font-bold">${money(Number(selected.amount || 0) * 0.85)}</p></div>
              </div>
            </div>
          `) : ''}

          ${glassCard(`
            <div class="p-5">
              ${sectionTitle('Tax & remittance', 'Estimated from completed payments')}
              <div class="mt-3 space-y-2 text-[10px]">
                <div class="flex justify-between"><span class="text-on-surface-variant">GST estimate (18%)</span><span class="font-semibold">${money(data.revenue * 0.18)}</span></div>
                <div class="flex justify-between"><span class="text-on-surface-variant">Platform take</span><span class="font-semibold">${money(data.platformTake)}</span></div>
                <div class="flex justify-between"><span class="text-on-surface-variant">Provider payouts</span><span class="font-semibold">${money(data.providerPayout)}</span></div>
                <div class="mt-2 flex items-center justify-between rounded-xl bg-surface-container-low p-3"><span class="font-bold">Reconciled</span><span class="text-primary font-bold">100%</span></div>
              </div>
            </div>
          `)}
        </section>
      </div>
    </div>
  `;
}

// ── Ratings ─────────────────────────────────────────────────────────────

function ratingsView() {
  const ratings = sortDate(state.ratings, 'createdAt');
  const avg = ratings.length ? ratings.reduce((sum, r) => sum + Number(r.score || 0), 0) / ratings.length : 0;
  return `
    <div class="space-y-5 fade-in">
      ${pageHeader('Ratings & moderation', 'Customer Feedback & Moderation', 'Review customer ratings, provider reputation, and remove invalid or abusive feedback.', `<button class="flex items-center gap-2 rounded-xl bg-surface-container-low px-3 py-2 text-[10px] font-bold shadow-sm" data-action="refresh">${icon('refresh', 'text-[16px] text-primary')} Refresh</button>`)}
      <div class="grid gap-3 sm:grid-cols-3">
        ${kpi('Average rating', avg ? avg.toFixed(2) : '—', 'Across all reviews', 'star', 'secondary')}
        ${kpi('Total reviews', String(ratings.length), 'Customer submitted ratings', 'rate_review', 'primary')}
        ${kpi('5-star reviews', String(ratings.filter((r) => Number(r.score) === 5).length), 'Highest satisfaction band', 'workspace_premium', 'success')}
      </div>
      <div class="grid gap-3 lg:grid-cols-2">
        ${ratings.length ? ratings.map((r) => `
          <div class="glass rounded-2xl p-4">
            <div class="flex items-start justify-between gap-3">
              <div class="flex items-center gap-2.5">
                <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-amber-50 text-xs font-extrabold text-amber-600">${Number(r.score || 0)}★</div>
                <div><p class="text-[11px] font-bold">${esc(r.customer?.name || r.customerName || 'Customer')}</p><p class="text-[9px] text-on-surface-variant">for ${esc(r.provider?.name || r.providerName || 'Provider')}</p></div>
              </div>
              <button class="rounded-lg border border-outline-variant bg-white p-1.5 text-on-surface-variant hover:border-secondary-fixed hover:text-secondary" data-action="delete-rating" data-id="${esc(r.id)}" title="Delete review">${icon('delete', 'text-[16px]')}</button>
            </div>
            <p class="mt-3 text-[10px] leading-relaxed text-on-surface-variant">${esc(r.review || 'No written review.')}</p>
            <div class="mt-3 flex items-center justify-between border-t border-surface-container pt-2 text-[8px] text-on-surface-variant"><span>${fmtDate(r.createdAt, true)}</span><span class="font-mono">${esc(r.requestId || '')}</span></div>
          </div>
        `).join('') : '<div class="glass rounded-2xl p-10 text-center text-sm text-on-surface-variant lg:col-span-2">No ratings submitted yet.</div>'}
      </div>
    </div>
  `;
}

// ── Settings ────────────────────────────────────────────────────────────

function settingsView() {
  const data = stats();
  return `
    <div class="space-y-5 fade-in">
      ${pageHeader('System settings', 'Platform & Environment', 'Firebase project, admin profile, and operational configuration.', `<button class="flex items-center gap-2 rounded-xl bg-primary px-3 py-2 text-[10px] font-bold text-white" data-action="refresh">${icon('refresh', 'text-[16px]')} Reload data</button>`)}
      <div class="grid gap-5 lg:grid-cols-2">
        ${glassCard(`
          <div class="p-5">
            ${sectionTitle('Admin profile', 'Current signed-in platform administrator')}
            <div class="mt-4 flex items-center gap-3">
              <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-primary text-sm font-extrabold text-white">${esc(initials(state.admin?.name || 'Admin'))}</div>
              <div><p class="text-sm font-bold">${esc(state.admin?.name || 'Platform Admin')}</p><p class="text-[10px] text-on-surface-variant">${esc(state.admin?.email || '')}</p>${badge('ADMIN')}</div>
            </div>
            <button class="mt-4 flex items-center gap-2 rounded-xl bg-surface-container-low px-3 py-2 text-[10px] font-bold text-secondary" data-action="logout">${icon('logout', 'text-[16px]')} Sign out of admin console</button>
          </div>
        `)}
        ${glassCard(`
          <div class="p-5">
            ${sectionTitle('Firebase project', 'Live environment')}
            <div class="mt-4 space-y-2 text-[10px]">
              <div class="flex justify-between"><span class="text-on-surface-variant">Project ID</span><span class="font-mono font-bold">road-rescuer</span></div>
              <div class="flex justify-between"><span class="text-on-surface-variant">Auth domain</span><span class="font-mono font-bold">road-rescuer.firebaseapp.com</span></div>
              <div class="flex justify-between"><span class="text-on-surface-variant">Firestore</span><span class="font-bold text-primary">connected</span></div>
              <div class="flex justify-between"><span class="text-on-surface-variant">Hosting</span><span class="font-bold text-primary">road-rescuer-admin.web.app</span></div>
            </div>
          </div>
        `)}
        ${glassCard(`
          <div class="p-5">
            ${sectionTitle('Platform data', 'Current Firestore snapshot')}
            <div class="mt-3 grid grid-cols-2 gap-2">
              ${[['Users', state.users.length], ['Providers', data.providers], ['Requests', state.requests.length], ['Payments', state.payments.length], ['Ratings', state.ratings.length], ['Bills', state.bills.length]].map(([label, count]) => `<div class="glass-soft p-3"><p class="text-[8px] uppercase tracking-wider text-on-surface-variant">${label}</p><p class="mt-1 text-lg font-extrabold">${count}</p></div>`).join('')}
            </div>
          </div>
        `)}
        ${glassCard(`
          <div class="p-5">
            ${sectionTitle('Operational health', 'Service status')}
            <div class="mt-3 space-y-2">
              ${[['Cloud Firestore', 'Live'], ['Firebase Auth', 'Healthy'], ['FCM Push', 'Connected'], ['MapLibre GL', 'Rendering'], ['OSRM Routing', 'Online']].map(([label, value]) => `<div class="glass-soft flex items-center justify-between p-3"><span class="text-[10px] font-semibold">${label}</span><span class="flex items-center gap-1 text-[9px] font-bold text-primary"><span class="h-1.5 w-1.5 rounded-full bg-primary"></span>${value}</span></div>`).join('')}
            </div>
          </div>
        `)}
      </div>
    </div>
  `;
}

// ── Actions ─────────────────────────────────────────────────────────────

async function updateProviderStatus(uid, status) {
  if (!uid || !status) return;
  let reason = '';
  if (status !== 'APPROVED') reason = window.prompt(`Reason for ${status}?`, '') || '';
  try {
    await updateDoc(doc(db, 'users', uid), {
      verificationStatus: status,
      isVerified: status === 'APPROVED',
      ...(reason ? { verificationReason: reason } : {}),
      updatedAt: serverTimestamp(),
    });
    toast(`Provider marked ${status}.`);
  } catch (err) {
    console.error(err);
    toast(`Could not update provider: ${err.message}`, 'error');
  }
}

async function updateRequestStatus(id, status) {
  if (!id || !status) return;
  try {
    await updateDoc(doc(db, 'serviceRequests', id), {
      status,
      [`${status === 'COMPLETED' ? 'completedAt' : 'updatedAt'}`]: serverTimestamp(),
    });
    toast(`Request marked ${status}.`);
  } catch (err) {
    console.error(err);
    toast(`Could not update request: ${err.message}`, 'error');
  }
}

async function deleteRating(id) {
  if (!id) return;
  if (!window.confirm('Delete this rating? Provider rating will be recalculated.')) return;
  try {
    const ref = doc(db, 'ratings', id);
    const snap = await getDoc(ref);
    const providerId = snap.data()?.providerId || '';
    await deleteDoc(ref);
    if (providerId) {
      const remaining = state.ratings.filter((r) => r.id !== id && r.providerId === providerId);
      const avg = remaining.length ? remaining.reduce((sum, r) => sum + Number(r.score || 0), 0) / remaining.length : 5;
      await updateDoc(doc(db, 'users', providerId), {
        rating: avg,
        ratingCount: remaining.length,
        updatedAt: serverTimestamp(),
      });
    }
    toast('Rating deleted.');
  } catch (err) {
    console.error(err);
    toast(`Could not delete rating: ${err.message}`, 'error');
  }
}

function exportLedger() {
  const rows = [['Transaction', 'Request', 'Amount', 'Method', 'Status', 'Customer', 'Provider', 'Paid']];
  for (const p of state.payments) {
    rows.push([
      p.transactionId || p.id,
      p.requestId || '',
      Number(p.amount || 0).toFixed(2),
      p.method || '',
      p.status || '',
      p.customerName || '',
      p.providerName || '',
      fmtDate(p.paidAt || p.createdAt, true),
    ]);
  }
  downloadCsv('roadrescue-ledger.csv', rows);
  toast('Ledger exported.');
}

function exportProviders() {
  const rows = [['Name', 'Email', 'Mobile', 'Garage', 'Category', 'Status', 'Availability', 'Rating', 'Jobs']];
  for (const u of state.users.filter((x) => x.role === 'PROVIDER')) {
    const p = providerProfile(u);
    rows.push([u.name || '', u.email || '', u.mobile || '', p.garage, p.category, p.status, p.availability, p.rating.toFixed(2), p.totalJobs]);
  }
  downloadCsv('roadrescue-providers.csv', rows);
  toast('Provider directory exported.');
}

function downloadCsv(filename, rows) {
  const csv = rows.map((row) => row.map((cell) => `"${String(cell).replaceAll('"', '""')}"`).join(',')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

function serviceIcon(serviceType) {
  const s = String(serviceType || '').toLowerCase();
  if (s.includes('puncture') || s.includes('tyre')) return 'tire_repair';
  if (s.includes('tow')) return 'fire_truck';
  if (s.includes('battery')) return 'electric_bolt';
  if (s.includes('fuel')) return 'local_gas_station';
  return 'car_repair';
}
