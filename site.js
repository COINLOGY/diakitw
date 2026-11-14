'use strict';
function downloadURL(m, p) {
  if (!m.published || !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(m.repository || '') || !/^[a-f0-9]{64}$/.test(p.sha256 || '') || !Number.isSafeInteger(p.size_bytes) || p.size_bytes <= 0 || !p.filename) return null;
  try {
    const u = new URL(p.url);
    const prefix = '/' + m.repository + '/releases/download/';
    const rest = u.pathname.slice(prefix.length).split('/');
    return u.protocol === 'https:' && u.hostname === 'github.com' && !u.port && !u.username && !u.password && !u.search && !u.hash && u.pathname.startsWith(prefix) && rest.length === 2 && rest[0] && decodeURIComponent(rest[1]) === p.filename ? u.href : null;
  } catch { return null; }
}
if (typeof module !== 'undefined') module.exports = {downloadURL};
if (typeof document !== 'undefined') {
  const el = (tag, text, cls) => { const e = document.createElement(tag); e.textContent = text; if(cls)e.className=cls; return e; };
  fetch('manifest.json', {cache:'no-store'}).then(r => {if(!r.ok)throw Error('manifest');return r.json();}).then(m => {
    const expected = ['mac-silicon','mac-intel','android','windows','linux'];
    if(m.schema_version !== 1 || m.platforms.length !== 5 || m.platforms.some((p,i)=>p.id!==expected[i])) throw Error('schema');
    const cards = document.getElementById('downloads');
    cards.replaceChildren();
    for(const [i,p] of m.platforms.entries()) {
      const c=el('article','', 'card'); c.id=p.id;
      const top=el('div','', 'card-top');top.append(el('span',String(i+1).padStart(2,'0'),'ordinal'),el('span',p.format,'tag'));c.append(top);
      c.append(el('h3',p.name),el('p',p.architecture,'arch'),el('p',p.requirements,'requirements'));
      const details=el('details','');details.append(el('summary','Установка и ограничения'),el('p',p.signing),el('p',p.runtime));c.append(details);
      const meta=el('div','', 'metadata');meta.append(el('span',p.filename || 'Файл ещё не закреплён'));
      meta.append(el('span',p.size_bytes ? new Intl.NumberFormat('ru-RU').format(p.size_bytes)+' байт' : 'Размер — после сборки'));
      const checksum=el('details','');checksum.append(el('summary','SHA-256'),el('code',p.sha256 || 'Будет рассчитан из финального файла'));meta.append(checksum);c.append(meta);
      const url=downloadURL(m,p);
      if(url) {const a=el('a','Скачать '+p.format,'download');a.href=url;c.append(a);} else {const b=el('button','Не опубликовано','download');b.disabled=true;c.append(b);}
      cards.append(c);
    }
    document.getElementById('state').textContent = m.published ? 'Предварительный релиз: '+(m.release || 'без метки') : 'Локальная подготовка · не опубликовано';
    document.getElementById('license').textContent=m.license;
  }).catch(()=>{document.getElementById('state').textContent='Манифест недоступен · загрузки отключены';document.getElementById('downloads').textContent='Откройте страницу через локальный HTTP-сервер. Для безопасности ссылки не созданы.';});
}
