const RES = GetParentResourceName();
const post = (n, d) => fetch(`https://${RES}/${n}`, { method: 'POST', body: JSON.stringify(d || {}) });
const $ = id => document.getElementById(id);
const money = n => '$' + (n || 0).toLocaleString('cs-CZ');

/* ---------- Notifikace ---------- */
function toast(msg, type, dur) {
  const el = document.createElement('div');
  el.className = 'toast ' + (type || 'info');
  el.textContent = msg;
  $('toasts').appendChild(el);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 350); }, dur || 5000);
}

/* ---------- Multicharacter ---------- */
let S = {}, gender = 'male', isNew = false, newSlot = 1, delArm = null;

function show(id) {
  document.querySelectorAll('.screen').forEach(e => e.classList.remove('active'));
  $(id).classList.add('active');
}

function renderList() {
  const L = $('list'); L.innerHTML = '';
  const used = {};
  S.characters.forEach(c => {
    used[c.slot] = true;
    const el = document.createElement('div'); el.className = 'card';
    el.innerHTML = '<div><div class="name"></div><div class="meta"></div></div>';
    el.querySelector('.name').textContent = `${c.firstname} ${c.lastname}`;
    el.querySelector('.meta').textContent = `${c.sex === 'f' ? 'Žena' : 'Muž'}${c.dob ? ' · ' + c.dob : ''}`;
    const del = document.createElement('button'); del.className = 'del'; del.textContent = 'Smazat';
    del.onclick = e => {
      e.stopPropagation();
      if (delArm !== c.slot) { delArm = c.slot; del.textContent = 'Opravdu?'; del.classList.add('confirm'); return; }
      delArm = null; post('mc_delete', { slot: c.slot });
    };
    el.onclick = () => { delArm = null; isNew = false; post('mc_select', { slot: c.slot }); openSpawn(true); };
    el.appendChild(del); L.appendChild(el);
  });
  for (let s = 1; s <= S.slots; s++) {
    if (used[s]) continue;
    const el = document.createElement('div'); el.className = 'card empty'; el.textContent = '+ Vytvořit postavu';
    el.onclick = () => { isNew = true; newSlot = s; openCreate(); };
    L.appendChild(el);
  }
}

function fillPeds() {
  $('ped').innerHTML = '';
  (S.peds[gender] || []).forEach(p => {
    const o = document.createElement('option'); o.value = p.model; o.textContent = p.label; $('ped').appendChild(o);
  });
}
function setGender(g) {
  gender = g;
  $('g-male').classList.toggle('on', g === 'male');
  $('g-female').classList.toggle('on', g === 'female');
  fillPeds();
}
$('g-male').onclick = () => setGender('male');
$('g-female').onclick = () => setGender('female');

function openCreate() {
  const now = new Date(), y = now.getFullYear(), p = n => String(n).padStart(2, '0');
  $('dob').min = `${y - S.maxAge}-01-01`;
  $('dob').max = `${y - S.minAge}-${p(now.getMonth() + 1)}-${p(now.getDate())}`;
  $('err').textContent = ''; setGender(gender); show('s-create');
}
$('create-back').onclick = () => show('s-list');
$('create-next').onclick = () => {
  const fn = $('fn').value.trim(), ln = $('ln').value.trim(), dob = $('dob').value, h = parseInt($('height').value, 10);
  const re = /^[\p{L}' -]{2,24}$/u;
  if (!re.test(fn) || !re.test(ln)) return $('err').textContent = 'Jméno a příjmení: 2–24 písmen, bez čísel.';
  if (!dob) return $('err').textContent = 'Zadej datum narození.';
  if (dob > $('dob').max || dob < $('dob').min) return $('err').textContent = `Postava musí mít ${S.minAge}–${S.maxAge} let.`;
  if (!h || h < S.minHeight || h > S.maxHeight) return $('err').textContent = `Výška musí být ${S.minHeight}–${S.maxHeight} cm.`;
  post('mc_create', { slot: newSlot, firstname: fn, lastname: ln, date: dob, sex: gender === 'female' ? 'f' : 'm', height: h, model: $('ped').value });
  openSpawn(false);
};

function openSpawn(hasLast) {
  const L = $('spawns'); L.innerHTML = '';
  if (hasLast) {
    const el = document.createElement('div'); el.className = 'card';
    el.innerHTML = '<div><div class="name">Poslední pozice</div><div class="meta">Tam, kde jsi naposledy skončil</div></div><span class="tag">Výchozí</span>';
    el.onclick = () => post('mc_spawn', { index: 0 });
    L.appendChild(el);
  }
  S.spawns.forEach((s, i) => {
    const el = document.createElement('div'); el.className = 'card';
    el.innerHTML = '<div><div class="name"></div><div class="meta"></div></div>';
    el.querySelector('.name').textContent = s.label; el.querySelector('.meta').textContent = s.desc;
    el.onmouseenter = () => post('mc_preview', { index: i + 1 });
    el.onclick = () => post('mc_spawn', { index: i + 1 });
    L.appendChild(el);
  });
  show('s-spawn');
}
$('spawn-back').onclick = () => { post('mc_back'); show(isNew ? 's-create' : 's-list'); };

/* ---------- Inventář ---------- */
let I = { items: {}, slots: 30, maxWeight: 30000, data: {}, accounts: {}, labels: {}, sel: null };

function invWeight() {
  let w = 0;
  Object.values(I.data).forEach(s => { const it = I.items[s.name]; if (it) w += it.weight * s.count; });
  return w;
}

function renderInv() {
  const g = $('grid'); g.innerHTML = '';
  for (let i = 1; i <= I.slots; i++) {
    const s = I.data[i], el = document.createElement('div');
    el.className = 'slot' + (s ? ' filled' : '') + (I.sel === i ? ' sel' : '');
    el.dataset.slot = i;
    if (s) {
      const it = I.items[s.name] || { label: s.name, icon: '📦' };
      el.draggable = true;
      el.innerHTML = `<span class="lbl"></span>${it.icon || '📦'}<span class="cnt">${s.count > 1 ? s.count + '×' : ''}</span>`;
      el.querySelector('.lbl').textContent = it.label;
      el.ondragstart = e => e.dataTransfer.setData('text/plain', String(i));
      el.onclick = () => { I.sel = i; renderInv(); };
      el.ondblclick = () => post('inv_use', { slot: i });
    }
    el.ondragover = e => { e.preventDefault(); el.classList.add('over'); };
    el.ondragleave = () => el.classList.remove('over');
    el.ondrop = e => {
      e.preventDefault(); el.classList.remove('over');
      const from = parseInt(e.dataTransfer.getData('text/plain'), 10);
      if (from && from !== i) post('inv_move', { from, to: i });
    };
    g.appendChild(el);
  }

  const w = invWeight();
  $('wtext').textContent = `${(w / 1000).toFixed(1)} / ${(I.maxWeight / 1000).toFixed(0)} kg`;
  $('wfill').style.width = Math.min(100, w / I.maxWeight * 100) + '%';

  $('money').innerHTML = Object.keys(I.labels).map(k => `<span>${I.labels[k]}<b>${money(I.accounts[k])}</b></span>`).join('');
  renderDetail();
}

function renderDetail() {
  const d = $('detail'), s = I.data[I.sel];
  if (!s) { d.innerHTML = '<div class="empty">Vyber předmět.</div>'; return; }
  const it = I.items[s.name] || { label: s.name, icon: '📦', weight: 0, description: '' };
  d.innerHTML = `<div class="ico">${it.icon || '📦'}</div><div class="dn"></div><div class="dd"></div>
    <div class="dm">Množství: ${s.count} · ${((it.weight * s.count) / 1000).toFixed(2)} kg</div>
    <input type="number" id="amt" min="1" max="${s.count}" value="1">
    <div class="acts"><button class="btn" id="b-use">Použít</button><button class="btn" id="b-give">Dát</button><button class="btn" id="b-drop">Zahodit</button></div>`;
  d.querySelector('.dn').textContent = it.label;
  d.querySelector('.dd').textContent = it.description || '';
  const amt = () => Math.max(1, Math.min(s.count, parseInt($('amt').value, 10) || 1));
  $('b-use').onclick = () => post('inv_use', { slot: I.sel });
  $('b-give').onclick = () => post('inv_give', { slot: I.sel, count: amt() });
  $('b-drop').onclick = () => post('inv_drop', { slot: I.sel, count: amt() });
}

function setInv(list, accounts) {
  I.data = {}; (list || []).forEach(s => I.data[s.slot] = s);
  I.accounts = accounts || {};
  if (!I.data[I.sel]) I.sel = null;
}

document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && !$('inv').classList.contains('hidden')) post('inv_close');
});

/* ---------- Zprávy z klienta ---------- */
window.addEventListener('message', e => {
  const d = e.data;
  switch (d.action) {
    case 'notify': toast(d.message, d.type, d.duration); break;
    case 'mc_open':
      S = d; $('mc-server').textContent = d.server; delArm = null;
      renderList(); show('s-list'); $('mc').classList.remove('hidden'); break;
    case 'mc_characters':
      S.characters = d.characters; delArm = null; renderList(); show('s-list'); break;
    case 'mc_close': $('mc').classList.add('hidden'); break;
    case 'inv_open':
      I.items = d.items; I.slots = d.slots; I.maxWeight = d.maxWeight; I.labels = d.accountLabels || {}; I.sel = null;
      $('inv-server').textContent = d.server;
      setInv(d.inventory, d.accounts); renderInv(); $('inv').classList.remove('hidden'); break;
    case 'inv_update': setInv(d.inventory, d.accounts); renderInv(); break;
    case 'inv_close': $('inv').classList.add('hidden'); break;
  }
});
